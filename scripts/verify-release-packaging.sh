#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGE_SCRIPT="$REPO_ROOT/scripts/package-release.sh"
readonly ARTIFACT_VERIFY_SCRIPT="$REPO_ROOT/scripts/verify-release-artifact.sh"
readonly RELEASE_DOC="$REPO_ROOT/docs/release.md"
readonly RELEASE_NOTES="$REPO_ROOT/docs/release-notes/v0.1.0.md"

failures=()

record_failure() {
    failures+=("$1")
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

require_line() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    if [[ ! -f "$file" ]]; then
        record_failure "Missing required file: $file"
    elif ! grep -F -- "$pattern" "$file" >/dev/null; then
        record_failure "$message"
    fi
}

require_command bash
require_command grep
require_command plutil

if [[ ! -f "$PACKAGE_SCRIPT" ]]; then
    record_failure "Missing release packaging script: $PACKAGE_SCRIPT"
elif [[ ! -x "$PACKAGE_SCRIPT" ]]; then
    record_failure "Release packaging script must be executable: $PACKAGE_SCRIPT"
elif ! bash -n "$PACKAGE_SCRIPT"; then
    record_failure "Release packaging script failed bash syntax validation."
fi

if [[ ! -f "$ARTIFACT_VERIFY_SCRIPT" ]]; then
    record_failure "Missing release artifact verifier: $ARTIFACT_VERIFY_SCRIPT"
elif [[ ! -x "$ARTIFACT_VERIFY_SCRIPT" ]]; then
    record_failure "Release artifact verifier must be executable: $ARTIFACT_VERIFY_SCRIPT"
elif ! bash -n "$ARTIFACT_VERIFY_SCRIPT"; then
    record_failure "Release artifact verifier failed bash syntax validation."
fi

if [[ -f "$PACKAGE_SCRIPT" ]]; then
    require_line "$PACKAGE_SCRIPT" "verify-release-artifact.sh" \
        "Release packaging script must call verify-release-artifact.sh by default."
    require_line "$PACKAGE_SCRIPT" 'tmp_checksum="$tmp_artifact.sha256"' \
        "Release packaging script must stage the checksum next to the temporary ZIP."
    require_line "$PACKAGE_SCRIPT" '"$REPO_ROOT/scripts/verify-release-artifact.sh" "$tmp_artifact"' \
        "Release packaging script must verify the staged ZIP before publishing it."
    require_line "$PACKAGE_SCRIPT" 'mv "$tmp_artifact" "$artifact_path"' \
        "Release packaging script must publish the staged ZIP only after verification."
    require_line "$PACKAGE_SCRIPT" 'mv "$tmp_checksum" "$checksum_path"' \
        "Release packaging script must publish the staged checksum only after verification."
    require_line "$PACKAGE_SCRIPT" "--skip-final-verification" \
        "Release packaging script must make unverified packaging rehearsals explicit."
fi

if [[ -f "$ARTIFACT_VERIFY_SCRIPT" ]]; then
    require_line "$ARTIFACT_VERIFY_SCRIPT" "Release checksum sidecar does not exist" \
        "Release artifact verifier must require the generated checksum sidecar."
    require_line "$ARTIFACT_VERIFY_SCRIPT" "Checksum sidecar digest must match the release ZIP." \
        "Release artifact verifier must compare the sidecar digest to the ZIP."
fi

if [[ ${#failures[@]} -eq 0 ]]; then
    dry_run_output="$(
        "$PACKAGE_SCRIPT" \
            --dry-run \
            --output-dir "$REPO_ROOT/dist/releases" \
            2>&1
    )"
    if ! grep -F "Release packaging dry run passed." <<<"$dry_run_output" >/dev/null; then
        record_failure "Release packaging dry run did not report success."
    fi
    if ! grep -F "AlpenLedgerApp-v" <<<"$dry_run_output" >/dev/null; then
        record_failure "Release packaging dry run did not report versioned artifact name."
    fi
fi

require_line "$RELEASE_DOC" "scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases" \
    "Release documentation must include the packaging command."
require_line "$RELEASE_DOC" 'adjacent `.sha256` sidecar' \
    "Release documentation must describe final checksum sidecar verification."
require_line "$RELEASE_NOTES" "scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases" \
    "Release notes must include the packaging evidence command."

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Release packaging verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Release packaging verification passed."
