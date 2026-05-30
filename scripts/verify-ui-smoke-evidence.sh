#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"
readonly SMOKE_DOC="$REPO_ROOT/docs/ui-smoke-pass-macos.md"
readonly RELEASE_DOC="$REPO_ROOT/docs/release.md"
readonly READINESS_SCRIPT="$REPO_ROOT/scripts/verify-readiness.sh"

allow_missing_evidence=0
evidence_path=""

usage() {
    cat <<'USAGE'
Usage: scripts/verify-ui-smoke-evidence.sh [--allow-missing-evidence] [--evidence path]

Verifies the release-candidate UI smoke evidence record.

Default evidence path:
  docs/release-evidence/ui-smoke-v<CFBundleShortVersionString>.json

Use --allow-missing-evidence in local readiness runs that can verify the
evidence schema and documentation wiring, but do not yet have a release-machine
manual smoke pass to validate.
USAGE
}

while (($#)); do
    case "$1" in
        --allow-missing-evidence)
            allow_missing_evidence=1
            ;;
        --evidence)
            shift
            if [[ $# -eq 0 ]]; then
                echo "--evidence requires a path" >&2
                exit 2
            fi
            evidence_path="$1"
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

failures=()
warnings=()

record_failure() {
    failures+=("$1")
}

record_warning() {
    warnings+=("$1")
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"

    if [[ ! -f "$file" ]]; then
        record_failure "Missing required file: $file"
    elif ! grep -F -- "$literal" "$file" >/dev/null; then
        record_failure "$message"
    fi
}

require_command plutil
require_command ruby
require_command grep

require_literal "$SMOKE_DOC" "## Evidence Record" \
    "UI smoke checklist must document the evidence record schema."
require_literal "$SMOKE_DOC" "scripts/verify-ui-smoke-evidence.sh" \
    "UI smoke checklist must reference the evidence verifier."
require_literal "$RELEASE_DOC" "scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json" \
    "Release docs must include the strict UI smoke evidence command."
require_literal "$READINESS_SCRIPT" "verify-ui-smoke-evidence.sh" \
    "Readiness gate must run scripts/verify-ui-smoke-evidence.sh."

if [[ -z "$evidence_path" ]]; then
    if [[ ! -f "$INFO_PLIST" ]]; then
        record_failure "Missing app Info.plist: $INFO_PLIST"
    else
        marketing_version="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" 2>/dev/null || true)"
        if [[ -z "$marketing_version" ]]; then
            record_failure "Info.plist must declare CFBundleShortVersionString."
        else
            evidence_path="$REPO_ROOT/docs/release-evidence/ui-smoke-v${marketing_version}.json"
        fi
    fi
elif [[ "$evidence_path" != /* ]]; then
    evidence_path="$REPO_ROOT/$evidence_path"
fi

if [[ ${#failures[@]} -eq 0 && ! -f "$evidence_path" ]]; then
    if ((allow_missing_evidence)); then
        record_warning "UI smoke evidence is not present yet: $evidence_path"
    else
        record_failure "Missing UI smoke evidence: $evidence_path"
    fi
fi

if [[ ${#failures[@]} -eq 0 && -f "$evidence_path" ]]; then
    if ! ruby -rjson - "$evidence_path" "$REPO_ROOT" <<'RUBY'
path = File.expand_path(ARGV.fetch(0))
repo_root = File.expand_path(ARGV.fetch(1))
evidence_dir = File.expand_path("docs/release-evidence", repo_root)
required_window_sizes = ["1200x720", "1440x900", "1720x1100"]
required_scenarios = ["firstRunAndShell", "ledger", "documents", "overviewAndMotion"]
required_motion_modes = ["default", "reduceMotion"]
required_exit_criteria = [
  "noClippedOrOverlappingChrome",
  "keyboardUsableLedgerDocuments",
  "inspectorVisibilityPersists",
  "defaultAndReduceMotionStable"
]

failures = []

begin
  data = JSON.parse(File.read(path))
rescue JSON::ParserError => error
  warn "Invalid JSON evidence: #{error.message}"
  exit 1
end

def non_empty_string?(value)
  value.is_a?(String) && !value.strip.empty?
end

def require_string(failures, data, key)
  value = data[key]
  failures << "#{key} must be a non-empty string." unless non_empty_string?(value)
  value
end

def validate_archived_refs(failures, refs, field, repo_root, evidence_dir, manifest_path)
  unless refs.is_a?(Array)
    failures << "#{field} must be an array of archived evidence paths."
    return
  end

  if refs.empty?
    failures << "#{field} must contain at least one archived evidence path."
    return
  end

  evidence_dir_real = File.realpath(evidence_dir)
  refs.each_with_index do |ref, index|
    ref_field = "#{field}[#{index}]"
    unless non_empty_string?(ref)
      failures << "#{ref_field} must be a non-empty string."
      next
    end

    if ref.include?("path/to") || ref.match?(/\b(?:TBD|TODO|FIXME)\b/i)
      failures << "#{ref_field} must not contain placeholder text."
    end
    if ref.start_with?("/")
      failures << "#{ref_field} must be repo-relative, not absolute."
    end
    if ref.match?(/\A[a-z][a-z0-9+.-]*:/i)
      failures << "#{ref_field} must be a repo-relative path, not a URL."
    end

    expanded = File.expand_path(ref, repo_root)
    unless expanded == evidence_dir || expanded.start_with?(evidence_dir + File::SEPARATOR)
      failures << "#{ref_field} must live under docs/release-evidence."
      next
    end

    unless File.exist?(expanded)
      failures << "#{ref_field} does not exist: #{ref}."
      next
    end

    real = File.realpath(expanded)
    unless real == evidence_dir_real || real.start_with?(evidence_dir_real + File::SEPARATOR)
      failures << "#{ref_field} must not escape docs/release-evidence."
    end
    if real == File.realpath(manifest_path)
      failures << "#{ref_field} must reference supporting evidence, not the UI smoke manifest itself."
    end
  end
end

failures << "schemaVersion must be 1." unless data["schemaVersion"] == 1
verified_at = require_string(failures, data, "verifiedAt")
if verified_at.is_a?(String) && verified_at !~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
  failures << "verifiedAt must be an ISO-8601 timestamp."
end
require_string(failures, data, "verifier")

app = data["app"]
if !app.is_a?(Hash)
  failures << "app must be an object."
else
  %w[version build gitRevision].each { |key| require_string(failures, app, key) }
end

automation = data["automation"]
if !automation.is_a?(Hash)
  failures << "automation must be an object."
else
  command = require_string(failures, automation, "command")
  failures << "automation.command must be RUN_UI_TESTS=full scripts/verify-readiness.sh." unless command == "RUN_UI_TESTS=full scripts/verify-readiness.sh"
  failures << "automation.status must be passed." unless automation["status"] == "passed"
  validate_archived_refs(failures, automation["artifactRefs"], "automation.artifactRefs", repo_root, evidence_dir, path)
end

manual_passes = data["manualPasses"]
if !manual_passes.is_a?(Array)
  failures << "manualPasses must be an array."
else
  modes = manual_passes.each_with_object([]) do |entry, result|
    result << entry["motionMode"] if entry.is_a?(Hash)
  end
  missing_modes = required_motion_modes - modes
  failures << "manualPasses missing motion modes: #{missing_modes.join(", ")}." unless missing_modes.empty?

  manual_passes.each_with_index do |entry, index|
    unless entry.is_a?(Hash)
      failures << "manualPasses[#{index}] must be an object."
      next
    end

    mode = entry["motionMode"]
    failures << "manualPasses[#{index}].motionMode must be default or reduceMotion." unless required_motion_modes.include?(mode)
    failures << "manualPasses[#{index}].status must be passed." unless entry["status"] == "passed"
    completed_at = entry["completedAt"]
    failures << "manualPasses[#{index}].completedAt must be an ISO-8601 timestamp." unless completed_at.is_a?(String) && completed_at.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

    window_sizes = entry["windowSizes"]
    missing_sizes = window_sizes.is_a?(Array) ? required_window_sizes - window_sizes : required_window_sizes
    failures << "manualPasses[#{index}] missing window sizes: #{missing_sizes.join(", ")}." unless missing_sizes.empty?

    scenarios = entry["scenarios"]
    missing_scenarios = scenarios.is_a?(Array) ? required_scenarios - scenarios : required_scenarios
    failures << "manualPasses[#{index}] missing scenarios: #{missing_scenarios.join(", ")}." unless missing_scenarios.empty?

    validate_archived_refs(failures, entry["artifactRefs"], "manualPasses[#{index}].artifactRefs", repo_root, evidence_dir, path)
  end
end

exit_criteria = data["exitCriteria"]
if !exit_criteria.is_a?(Hash)
  failures << "exitCriteria must be an object."
else
  required_exit_criteria.each do |key|
    failures << "exitCriteria.#{key} must be true." unless exit_criteria[key] == true
  end
end

blockers = data["blockers"]
failures << "blockers must be an empty array for release evidence." unless blockers.is_a?(Array) && blockers.empty?

if failures.any?
  warn "UI smoke evidence validation failed:"
  failures.each { |failure| warn "  - #{failure}" }
  exit 1
end
RUBY
    then
        record_failure "UI smoke evidence JSON failed schema validation: $evidence_path"
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "UI smoke evidence verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "UI smoke evidence warnings:"
    for warning in "${warnings[@]}"; do
        echo "  - $warning"
    done
fi

echo "UI smoke evidence verification passed."
echo "Evidence: $evidence_path"
