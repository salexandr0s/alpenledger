#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PRODUCT_SCOPE="$REPO_ROOT/docs/product-scope.md"
readonly VISION="$REPO_ROOT/docs/vision.md"
readonly ARCHITECTURE="$REPO_ROOT/docs/architecture.md"
readonly ARCHITECTURE_PASS="$REPO_ROOT/docs/architecture-pass-v1.md"
readonly AGENTS="$REPO_ROOT/agents.md"
readonly BUILDPLAN="$REPO_ROOT/docs/buildplan.md"
readonly PROMPT="$REPO_ROOT/docs/internal/prompt.md"
readonly CHECKLIST="$REPO_ROOT/docs/checklist.md"
readonly GOVERNANCE="$REPO_ROOT/docs/governance.md"

failures=()

record_failure() {
    failures+=("$1")
}

require_file() {
    if [[ ! -f "$1" ]]; then
        record_failure "Missing required alignment file: $1"
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    if [[ -f "$file" ]] && ! grep -Eq -- "$pattern" "$file"; then
        record_failure "$message"
    fi
}

reject_pattern() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    if [[ -f "$file" ]] && grep -Eq -- "$pattern" "$file"; then
        record_failure "$message"
    fi
}

for file in \
    "$PRODUCT_SCOPE" \
    "$VISION" \
    "$ARCHITECTURE" \
    "$ARCHITECTURE_PASS" \
    "$AGENTS" \
    "$BUILDPLAN" \
    "$PROMPT" \
    "$CHECKLIST" \
    "$GOVERNANCE"
do
    require_file "$file"
done

for path in \
    'docs/vision.md' \
    'docs/architecture.md' \
    'docs/architecture-pass-v1.md' \
    'agents.md' \
    'docs/buildplan.md' \
    'docs/internal/prompt.md' \
    'docs/checklist.md' \
    'docs/product-scope.md'
do
    require_pattern "$GOVERNANCE" "$path" \
        "Governance source-of-truth map must reference ${path}."
done

for path in \
    'docs/vision\.md' \
    'docs/architecture\.md' \
    'agents\.md' \
    'docs/buildplan\.md' \
    'docs/checklist\.md'
do
    require_pattern "$PROMPT" "\`${path}\`" \
        "Build prompt required-reading order must use canonical ${path} path."
done

reject_pattern "$PROMPT" '`vision\.md`' \
    "Build prompt still references root-level vision.md."
reject_pattern "$PROMPT" '`architecture\.md`' \
    "Build prompt still references root-level architecture.md."
reject_pattern "$PROMPT" '`buildplan\.md`' \
    "Build prompt still references root-level buildplan.md."
reject_pattern "$PROMPT" '`checklist\.md`' \
    "Build prompt still references root-level checklist.md."

require_pattern "$AGENTS" '\]\(docs/vision\.md\)' \
    "Agent cross-links must point to docs/vision.md."
require_pattern "$AGENTS" '\]\(docs/architecture\.md\)' \
    "Agent cross-links must point to docs/architecture.md."
require_pattern "$AGENTS" '\]\(docs/buildplan\.md\)' \
    "Agent cross-links must point to docs/buildplan.md."
reject_pattern "$AGENTS" '\]\(vision\.md\)|\]\(architecture\.md\)|\]\(buildplan\.md\)' \
    "Agent cross-links still point at stale root-level document paths."

require_pattern "$PRODUCT_SCOPE" 'local-first macOS finance workspace' \
    "Product scope must preserve the locked local-first macOS thesis."
require_pattern "$PRODUCT_SCOPE" 'Zurich for tax year 2026' \
    "Product scope must preserve the Zurich 2026 pilot tax scope."
require_pattern "$PRODUCT_SCOPE" 'Swiss sole proprietor / freelancer' \
    "Product scope must preserve the pilot business profile."
require_pattern "$PRODUCT_SCOPE" 'Automatic filing submission' \
    "Product scope must keep automatic filing submission out of scope."

require_pattern "$VISION" 'Everything lives locally by default' \
    "Vision must preserve the local-first product promise."
require_pattern "$VISION" 'AI is a copilot, not the source of truth' \
    "Vision must preserve the AI trust boundary."
require_pattern "$ARCHITECTURE" 'ledger, evidence graph, and tax engine are the system of record' \
    "Architecture must preserve the deterministic system-of-record boundary."
require_pattern "$ARCHITECTURE" 'SQLite/SQLCipher' \
    "Architecture must preserve the local persistence stance."
require_pattern "$BUILDPLAN" 'pilot canton' \
    "Build plan must preserve the pilot-canton delivery strategy."
require_pattern "$BUILDPLAN" 'export/submission first|export-first' \
    "Build plan must preserve export-first release posture."
require_pattern "$AGENTS" 'typed tools' \
    "Agent design must preserve the typed-tool bus boundary."
require_pattern "$AGENTS" 'silently send data off-device in local-only mode' \
    "Agent design must preserve the local-only data boundary."
require_pattern "$PROMPT" 'typed internal tool bus' \
    "Build prompt must preserve the typed internal tool-bus boundary."
require_pattern "$PROMPT" 'not.*demo, mockup, landing page, or generic finance toy' \
    "Build prompt must preserve the production-grade implementation bar."
require_pattern "$CHECKLIST" '- \[x\] Keep `docs/vision\.md`, `docs/architecture\.md`, `docs/architecture-pass-v1\.md`, `agents\.md`, `docs/buildplan\.md`, `docs/internal/prompt\.md`, and `docs/checklist\.md` aligned\.' \
    "Checklist must mark canonical document alignment complete with canonical paths."

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Documentation alignment verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Documentation alignment verification passed."
