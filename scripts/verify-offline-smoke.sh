#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly OFFLINE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/alpenledger-offline-smoke.XXXXXX")"

cleanup() {
    rm -rf "$OFFLINE_ROOT"
}
trap cleanup EXIT

run() {
    echo
    echo "==> $*"
    "$@"
}

run "$REPO_ROOT/scripts/verify-local-only.sh"

(
    cd "$REPO_ROOT"
    env \
        ALPENLEDGER_WORKSPACES_ROOT="$OFFLINE_ROOT/workspaces" \
        ALPENLEDGER_SECRET_STORE_ROOT="$OFFLINE_ROOT/secrets" \
        ALPENLEDGER_DEFAULTS_SUITE="AlpenLedgerOfflineSmoke.$(uuidgen)" \
        ALPENLEDGER_FIXED_NOW="2026-03-19T12:00:00Z" \
        ALPENLEDGER_PRIVACY_MODE="cloud" \
        xcodebuild test \
            -workspace AlpenLedger.xcworkspace \
            -scheme AlpenLedgerAppCI \
            -destination 'platform=macOS,arch=arm64' \
            -only-testing:AlpenLedgerAppTests/AlpenLedgerAppTests/testLocalOnlyOfflineSmokeCoversCoreWorkspaceWorkflow \
            CODE_SIGNING_ALLOWED=NO
)
