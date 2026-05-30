#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SUPPORT_DOC="$REPO_ROOT/docs/support.md"
readonly LOCAL_DEVELOPMENT="$REPO_ROOT/docs/local-development.md"
readonly RELEASE_DOC="$REPO_ROOT/docs/release.md"
readonly RELEASE_NOTES="$REPO_ROOT/docs/release-notes/v0.1.0.md"
readonly READINESS_SCRIPT="$REPO_ROOT/scripts/verify-readiness.sh"

failures=()

record_failure() {
    failures+=("$1")
}

require_file() {
    if [[ ! -f "$1" ]]; then
        record_failure "Missing required support-readiness file: $1"
    fi
}

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"

    if [[ -f "$file" ]] && ! grep -F -- "$literal" "$file" >/dev/null; then
        record_failure "$message"
    fi
}

require_section() {
    local file="$1"
    local section="$2"
    require_literal "$file" "## $section" \
        "Support documentation must include section: $section."
}

require_file "$SUPPORT_DOC"
require_file "$LOCAL_DEVELOPMENT"
require_file "$RELEASE_DOC"
require_file "$RELEASE_NOTES"
require_file "$READINESS_SCRIPT"

for section in \
    "Support Principles" \
    "Intake Severity" \
    "Customer-Safe Intake Checklist" \
    "Diagnostic Artifacts" \
    "Privacy Boundaries" \
    "Backup Safety" \
    "Triage Runbooks" \
    "Escalation And Issue Hand-off" \
    "Release Support Gate"
do
    require_section "$SUPPORT_DOC" "$section"
done

for literal in \
    "File > Export Diagnostics..." \
    "File > Export Support Bundle..." \
    "Settings > Support Diagnostics" \
    "source documents" \
    "document contents" \
    "document filenames" \
    "transaction descriptions" \
    "transaction amounts" \
    "workspace names" \
    "absolute paths" \
    "encryption keys" \
    "workspace.key" \
    "raw audit payloads" \
    "Do not request raw source documents" \
    "Do not accept an agent suggestion as confirmed ledger or tax state" \
    "scripts/verify-support-docs.sh"
do
    require_literal "$SUPPORT_DOC" "$literal" \
        "Support documentation missing required support/privacy anchor: $literal"
done

for literal in \
    "scripts/verify-support-docs.sh" \
    "docs/support.md"
do
    require_literal "$LOCAL_DEVELOPMENT" "$literal" \
        "Local development docs must reference support readiness anchor: $literal"
    require_literal "$RELEASE_DOC" "$literal" \
        "Release docs must reference support readiness anchor: $literal"
done

require_literal "$RELEASE_NOTES" "docs/support.md" \
    "Release notes must point support staff to docs/support.md."
require_literal "$RELEASE_NOTES" "sanitized diagnostics and support bundles" \
    "Release notes must mention sanitized diagnostics and support bundles."
require_literal "$READINESS_SCRIPT" "verify-support-docs.sh" \
    "Readiness gate must run scripts/verify-support-docs.sh."

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Support documentation verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Support documentation verification passed."
