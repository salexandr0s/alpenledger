#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FRESH_PARENT="${FRESH_PARENT:-$(mktemp -d "${TMPDIR:-/tmp}/alpenledger-fresh.XXXXXX")}"
readonly FRESH_REPO="$FRESH_PARENT/alpenledger"
readonly REQUIRED_XCODEGEN_VERSION="2.45.2"
readonly REQUIRED_XCODEGEN_OUTPUT="Version: $REQUIRED_XCODEGEN_VERSION"

run() {
    echo
    echo "==> $*"
    "$@"
}

cleanup_note() {
    echo
    echo "Fresh-checkout copy kept at: $FRESH_REPO"
}
trap cleanup_note EXIT

require_xcodegen() {
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "Fresh checkout verification requires XcodeGen $REQUIRED_XCODEGEN_VERSION." >&2
        echo "Install XcodeGen before running this production bootstrap gate." >&2
        exit 1
    fi

    local version_output
    version_output="$(xcodegen --version 2>&1)"
    if [[ "$version_output" != "$REQUIRED_XCODEGEN_OUTPUT" ]]; then
        echo "Fresh checkout verification requires XcodeGen $REQUIRED_XCODEGEN_VERSION." >&2
        echo "Found: $version_output" >&2
        exit 1
    fi
}

copy_manifest() {
    (
        cd "$REPO_ROOT"
        git ls-files --cached --others --exclude-standard -z
    )
}

echo "Creating disposable checkout copy at $FRESH_REPO"
require_xcodegen
mkdir -p "$FRESH_REPO"

while IFS= read -r -d '' path; do
    mkdir -p "$FRESH_REPO/$(dirname "$path")"
    if [[ -d "$REPO_ROOT/$path" && ! -L "$REPO_ROOT/$path" ]]; then
        cp -RpP "$REPO_ROOT/$path" "$FRESH_REPO/$path"
    else
        cp -pP "$REPO_ROOT/$path" "$FRESH_REPO/$path"
    fi
done < <(copy_manifest)

(
    cd "$FRESH_REPO"

    run xcodegen generate
    run env RUN_UI_TESTS="${RUN_UI_TESTS:-0}" scripts/verify-readiness.sh
)
