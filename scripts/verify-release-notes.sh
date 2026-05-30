#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly INFO_PLIST="$REPO_ROOT/App/AlpenLedgerApp/Info.plist"

strict=0

usage() {
    cat <<'USAGE'
Usage: scripts/verify-release-notes.sh [--strict]

Verifies the release notes draft for the current app marketing version.

Default mode checks that the draft exists and contains the required release
sections and evidence commands. Strict mode is for release candidates and also
requires no TBD placeholders and no unchecked verification evidence.
USAGE
}

while (($#)); do
    case "$1" in
        --strict)
            strict=1
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

record_failure() {
    failures+=("$1")
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        record_failure "Missing required command: $1"
    fi
}

require_line() {
    local pattern="$1"
    local message="$2"
    if ! grep -Eq "$pattern" "$release_notes"; then
        record_failure "$message"
    fi
}

require_command plutil
require_command grep

if [[ ! -f "$INFO_PLIST" ]]; then
    record_failure "Missing app Info.plist: $INFO_PLIST"
fi

if [[ ${#failures[@]} -eq 0 ]]; then
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
    release_notes="$REPO_ROOT/docs/release-notes/v${marketing_version}.md"

    if [[ ! -f "$release_notes" ]]; then
        record_failure "Missing release notes draft for v${marketing_version}: $release_notes"
    else
        require_line "^# AlpenLedger ${marketing_version} [(]Build ${build_version}[)]$" \
            "Release notes heading must match Info.plist version/build."
        require_line "^Status: " "Release notes must declare Status."
        require_line "^Release date: " "Release notes must declare Release date."

        for section in \
            "Audience" \
            "Highlights" \
            "Local-First And Privacy Notes" \
            "Data Integrity And Safety Notes" \
            "Verification Evidence" \
            "Known Limitations" \
            "Upgrade And Compatibility Notes" \
            "Support Notes"
        do
            require_line "^## ${section}$" "Release notes must include section: ${section}."
        done

        for command in \
            'scripts/verify-readiness.sh' \
            'RUN_UI_TESTS=full scripts/verify-readiness.sh' \
            "scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v${marketing_version}.json" \
            "scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v${marketing_version}.json" \
            'scripts/verify-release-preflight.sh' \
            'scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases' \
            'scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip'
        do
            if ! grep -F -- "$command" "$release_notes" >/dev/null; then
                record_failure "Release notes must include verification evidence command: $command"
            fi
        done

        if ((strict)); then
            if grep -Eq '\bTBD\b|TODO|FIXME' "$release_notes"; then
                record_failure "Strict release notes must not contain TBD/TODO/FIXME placeholders."
            fi
            if grep -Eq '^- \[ \]' "$release_notes"; then
                record_failure "Strict release notes must not contain unchecked verification evidence."
            fi
        fi
    fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Release notes verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Release notes verification passed."
echo "Version: $marketing_version ($build_version)"
echo "Draft: $release_notes"
