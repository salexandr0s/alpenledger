#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"
readonly RELEASE_DOC="$REPO_ROOT/docs/release.md"
readonly RELEASE_NOTES_DIR="$REPO_ROOT/docs/release-notes"
readonly RELEASE_EVIDENCE_README="$REPO_ROOT/docs/release-evidence/README.md"
readonly READINESS_SCRIPT="$REPO_ROOT/scripts/verify-readiness.sh"

allow_missing_evidence=0
evidence_path=""

usage() {
    cat <<'USAGE'
Usage: scripts/verify-release-evidence.sh [--allow-missing-evidence] [--evidence path]

Verifies the final release evidence manifest.

Default evidence path:
  docs/release-evidence/release-v<CFBundleShortVersionString>.json

Use --allow-missing-evidence in local readiness runs that can verify evidence
schema and documentation wiring, but do not yet have signed/notarized release
artifacts and release-machine command logs.
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

require_command grep
require_command plutil
require_command ruby

if [[ ! -f "$INFO_PLIST" ]]; then
    record_failure "Missing app Info.plist: $INFO_PLIST"
else
    marketing_version="$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" 2>/dev/null || true)"
    build_version="$(plutil -extract CFBundleVersion raw "$INFO_PLIST" 2>/dev/null || true)"
    if [[ -z "$marketing_version" ]]; then
        record_failure "Info.plist must declare CFBundleShortVersionString."
    fi
    if [[ -z "$build_version" ]]; then
        record_failure "Info.plist must declare CFBundleVersion."
    fi
fi

if [[ ${#failures[@]} -eq 0 ]]; then
    release_notes="$RELEASE_NOTES_DIR/v${marketing_version}.md"
    default_evidence="docs/release-evidence/release-v${marketing_version}.json"
    strict_command="scripts/verify-release-evidence.sh --evidence ${default_evidence}"

    require_literal "$RELEASE_DOC" "$strict_command" \
        "Release docs must include the strict release evidence command."
    require_literal "$release_notes" "$strict_command" \
        "Release notes must include the strict release evidence command."
    require_literal "$RELEASE_EVIDENCE_README" "$strict_command" \
        "Release evidence README must include the strict release evidence command."
    require_literal "$READINESS_SCRIPT" "verify-release-evidence.sh" \
        "Readiness gate must run scripts/verify-release-evidence.sh."

    if [[ -z "$evidence_path" ]]; then
        evidence_path="$REPO_ROOT/$default_evidence"
    elif [[ "$evidence_path" != /* ]]; then
        evidence_path="$REPO_ROOT/$evidence_path"
    fi
fi

if [[ ${#failures[@]} -eq 0 && ! -f "$evidence_path" ]]; then
    if ((allow_missing_evidence)); then
        record_warning "Release evidence manifest is not present yet: $evidence_path"
    else
        record_failure "Missing release evidence manifest: $evidence_path"
    fi
fi

if [[ ${#failures[@]} -eq 0 && -f "$evidence_path" ]]; then
    if ! ruby -rjson -rdigest - "$evidence_path" "$marketing_version" "$build_version" "$REPO_ROOT" <<'RUBY'
path = File.expand_path(ARGV.fetch(0))
expected_version = ARGV.fetch(1)
expected_build = ARGV.fetch(2)
repo_root = File.expand_path(ARGV.fetch(3))
evidence_dir = File.expand_path("docs/release-evidence", repo_root)

required_entries = {
  "defaultReadiness" => { exact: "scripts/verify-readiness.sh" },
  "freshCheckout" => { exact: "scripts/verify-fresh-checkout.sh" },
  "fullUIReadiness" => { exact: "RUN_UI_TESTS=full scripts/verify-readiness.sh" },
  "uiSmokeEvidence" => { exact: "scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v#{expected_version}.json" },
  "strictReleaseNotes" => { exact: "scripts/verify-release-notes.sh --strict" },
  "supportDocs" => { exact: "scripts/verify-support-docs.sh" },
  "copyReview" => { exact: "scripts/verify-copy-review.sh" },
  "localization" => { exact: "scripts/verify-localization.sh" },
  "strictReleasePreflight" => { exact: "scripts/verify-release-preflight.sh" },
  "packageRelease" => {
    pattern: /\Ascripts\/package-release\.sh --app (?!path\/to\/).+AlpenLedgerApp\.app --output-dir dist\/releases\z/,
    message: "scripts/package-release.sh --app <actual>/AlpenLedgerApp.app --output-dir dist/releases"
  }
}

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

def placeholder?(value)
  non_empty_string?(value) && (value.include?("path/to") || value.match?(/\b(?:TBD|TODO|FIXME)\b/i))
end

def repo_or_absolute_path(value, repo_root)
  return nil unless non_empty_string?(value)
  return nil if value.match?(/\A[a-z][a-z0-9+.-]*:/i)
  value.start_with?("/") ? File.expand_path(value) : File.expand_path(value, repo_root)
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

    failures << "#{ref_field} must not contain placeholder text." if placeholder?(ref)
    failures << "#{ref_field} must be repo-relative, not absolute." if ref.start_with?("/")
    failures << "#{ref_field} must be a repo-relative path, not a URL." if ref.match?(/\A[a-z][a-z0-9+.-]*:/i)

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
      failures << "#{ref_field} must reference supporting evidence, not the release manifest itself."
    end
  end
end

failures << "schemaVersion must be 1." unless data["schemaVersion"] == 1
created_at = require_string(failures, data, "createdAt")
if non_empty_string?(created_at) && created_at !~ /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
  failures << "createdAt must be an ISO-8601 timestamp."
end
require_string(failures, data, "verifier")

release = data["release"]
if !release.is_a?(Hash)
  failures << "release must be an object."
else
  failures << "release.version must be #{expected_version}." unless release["version"] == expected_version
  failures << "release.build must be #{expected_build}." unless release["build"] == expected_build
  require_string(failures, release, "gitRevision")
end

artifact = data["artifact"]
artifact_zip_path = artifact.is_a?(Hash) ? artifact["zipPath"] : nil
artifact_checksum_path = artifact.is_a?(Hash) ? artifact["checksumPath"] : nil
artifact_verify_command = non_empty_string?(artifact_zip_path) ? "scripts/verify-release-artifact.sh #{artifact_zip_path}" : nil
required_entries["verifyReleaseArtifact"] = {
  exact: artifact_verify_command,
  message: "scripts/verify-release-artifact.sh <artifact.zipPath>"
}

entries = data["evidence"]
if !entries.is_a?(Array)
  failures << "evidence must be an array."
else
  by_id = {}
  entries.each_with_index do |entry, index|
    unless entry.is_a?(Hash)
      failures << "evidence[#{index}] must be an object."
      next
    end

    id = entry["id"]
    if !non_empty_string?(id)
      failures << "evidence[#{index}].id must be a non-empty string."
      next
    end

    command = entry["command"]
    failures << "evidence[#{index}].command must be a non-empty string." unless non_empty_string?(command)
    failures << "evidence[#{index}].command must not contain placeholder text." if placeholder?(command)

    if by_id.key?(id)
      failures << "evidence id appears more than once: #{id}."
    end
    by_id[id] = entry

    failures << "evidence[#{index}].status must be passed." unless entry["status"] == "passed"
    completed_at = entry["completedAt"]
    failures << "evidence[#{index}].completedAt must be an ISO-8601 timestamp." unless non_empty_string?(completed_at) && completed_at.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    validate_archived_refs(failures, entry["artifactRefs"], "evidence[#{index}].artifactRefs", repo_root, evidence_dir, path)
  end

  required_entries.each do |id, expectation|
    entry = by_id[id]
    if entry.nil?
      failures << "Missing release evidence entry: #{id}."
      next
    end

    command = entry["command"]
    if expectation[:exact]
      failures << "Evidence entry #{id} command must be #{expectation[:exact]}." unless command == expectation[:exact]
    elsif expectation[:pattern]
      failures << "Evidence entry #{id} command must be #{expectation[:message]}." unless non_empty_string?(command) && command.match?(expectation[:pattern])
    end
  end
end

if !artifact.is_a?(Hash)
  failures << "artifact must be an object."
else
  zip_path = require_string(failures, artifact, "zipPath")
  checksum_path = require_string(failures, artifact, "checksumPath")
  sha256 = require_string(failures, artifact, "sha256")
  failures << "artifact.zipPath must not contain placeholder text." if placeholder?(zip_path)
  failures << "artifact.checksumPath must not contain placeholder text." if placeholder?(checksum_path)
  failures << "artifact.zipPath must not be a URL." if non_empty_string?(zip_path) && zip_path.match?(/\A[a-z][a-z0-9+.-]*:/i)
  failures << "artifact.checksumPath must not be a URL." if non_empty_string?(checksum_path) && checksum_path.match?(/\A[a-z][a-z0-9+.-]*:/i)
  failures << "artifact.sha256 must be a 64-character hexadecimal digest." unless non_empty_string?(sha256) && sha256.match?(/\A[[:xdigit:]]{64}\z/)
  if artifact_verify_command
    failures << "artifact.verifiedBy must be #{artifact_verify_command}." unless artifact["verifiedBy"] == artifact_verify_command
  end
  failures << "artifact.notarized must be true." unless artifact["notarized"] == true
  failures << "artifact.stapled must be true." unless artifact["stapled"] == true

  zip_expanded = repo_or_absolute_path(zip_path, repo_root)
  checksum_expanded = repo_or_absolute_path(checksum_path, repo_root)

  if zip_expanded && !File.file?(zip_expanded)
    failures << "artifact.zipPath must exist on the release machine: #{zip_path}."
  end
  if checksum_expanded && !File.file?(checksum_expanded)
    failures << "artifact.checksumPath must exist on the release machine: #{checksum_path}."
  end
  if zip_expanded && File.file?(zip_expanded) && non_empty_string?(sha256)
    actual_sha256 = Digest::SHA256.file(zip_expanded).hexdigest
    failures << "artifact.sha256 must match artifact.zipPath." unless actual_sha256.casecmp?(sha256)
  end
  if zip_expanded && checksum_expanded && File.file?(zip_expanded) && File.file?(checksum_expanded)
    checksum_lines = File.readlines(checksum_expanded, chomp: true)
    expected_basename = File.basename(zip_expanded)
    if checksum_lines.length != 1
      failures << "artifact.checksumPath must contain exactly one checksum line."
    else
      checksum_parts = checksum_lines.first.split(/[[:space:]]+/)
      if checksum_parts.length != 2
        failures << "artifact.checksumPath must contain '<sha256>  <filename>'."
      else
        sidecar_sha256, sidecar_name = checksum_parts
        failures << "artifact.checksumPath digest must match artifact.sha256." unless non_empty_string?(sha256) && sidecar_sha256.casecmp?(sha256)
        failures << "artifact.checksumPath filename must be #{expected_basename}." unless sidecar_name == expected_basename
      end
    end
  end
end

blockers = data["blockers"]
failures << "blockers must be an empty array for final release evidence." unless blockers.is_a?(Array) && blockers.empty?

if failures.any?
  warn "Release evidence validation failed:"
  failures.each { |failure| warn "  - #{failure}" }
  exit 1
end
RUBY
    then
        record_failure "Release evidence JSON failed schema validation: $evidence_path"
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Release evidence verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
    echo "Release evidence warnings:"
    for warning in "${warnings[@]}"; do
        echo "  - $warning"
    done
fi

echo "Release evidence verification passed."
echo "Evidence: $evidence_path"
