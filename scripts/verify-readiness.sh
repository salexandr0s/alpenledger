#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PACKAGE_DIR="$REPO_ROOT/Packages/AlpenLedgerKit"
readonly CI_SCHEME="$REPO_ROOT/AlpenLedgerApp.xcodeproj/xcshareddata/xcschemes/AlpenLedgerAppCI.xcscheme"

run() {
    echo
    echo "==> $*"
    "$@"
}

readonly UI_TEST_MODE="${RUN_UI_TESTS:-0}"

case "$UI_TEST_MODE" in
    1 | full | all)
        run "$REPO_ROOT/scripts/verify-ui-automation-preflight.sh"
        ;;
    0 | "")
        ;;
    *)
        echo "Unsupported RUN_UI_TESTS value: ${RUN_UI_TESTS}" >&2
        echo "Use RUN_UI_TESTS=1 for representative UI coverage or RUN_UI_TESTS=full for the full app scheme." >&2
        exit 2
        ;;
esac

run xmllint --noout "$CI_SCHEME"
run "$REPO_ROOT/scripts/verify-project-structure.sh"
run "$REPO_ROOT/scripts/verify-source-style.sh"
run "$REPO_ROOT/scripts/verify-release-notes.sh"
run "$REPO_ROOT/scripts/verify-release-packaging.sh"
run "$REPO_ROOT/scripts/verify-release-preflight.sh" --allow-missing-secrets
run "$REPO_ROOT/scripts/verify-ui-smoke-evidence.sh" --allow-missing-evidence
run "$REPO_ROOT/scripts/verify-release-evidence.sh" --allow-missing-evidence
run "$REPO_ROOT/scripts/verify-support-docs.sh"
run "$REPO_ROOT/scripts/verify-copy-review.sh"
run "$REPO_ROOT/scripts/verify-localization.sh"
run "$REPO_ROOT/scripts/verify-product-governance.sh"
run "$REPO_ROOT/scripts/verify-doc-alignment.sh"
run "$REPO_ROOT/scripts/verify-agent-tool-safety.sh"
run "$REPO_ROOT/scripts/verify-offline-smoke.sh"
run "$REPO_ROOT/scripts/verify-dependency-review.sh"
run "$REPO_ROOT/scripts/verify-grdb-vendor.sh" --offline
run "$REPO_ROOT/scripts/verify-fixtures.sh"
run "$REPO_ROOT/scripts/verify-rule-packs.sh"
run "$REPO_ROOT/scripts/verify-copilot-answers.sh"
run "$REPO_ROOT/scripts/verify-copilot-storage.sh"
run "$REPO_ROOT/scripts/verify-agent-evaluations.sh"
run "$REPO_ROOT/scripts/verify-schemas.sh"
run "$REPO_ROOT/scripts/verify-end-to-end-scenarios.sh"
run "$REPO_ROOT/scripts/verify-performance.sh"

(
    cd "$PACKAGE_DIR"
    run swift test
)

(
    cd "$REPO_ROOT"
    run xcodebuild test \
        -workspace AlpenLedger.xcworkspace \
        -scheme AlpenLedgerAppCI \
        -destination 'platform=macOS,arch=arm64' \
        CODE_SIGNING_ALLOWED=NO
)

case "$UI_TEST_MODE" in
    1)
        (
            cd "$REPO_ROOT"
            run xcodebuild test \
                -workspace AlpenLedger.xcworkspace \
                -scheme AlpenLedgerApp \
                -destination 'platform=macOS,arch=arm64' \
                -only-testing:AlpenLedgerAppUITests/AlpenLedgerAppUITests/testWelcomeUsesSheetBasedCreationAndRecentWorkspaceLauncher \
                -only-testing:AlpenLedgerAppUITests/AlpenLedgerAppUITests/testOverviewActionLinksIntoInboxAndDocumentLinkFlow \
                -only-testing:AlpenLedgerAppUITests/AlpenLedgerAppUITests/testCopilotAnswerCanCreateInboxTaskFromButton
        )
        ;;
    full | all)
        (
            cd "$REPO_ROOT"
            run xcodebuild test \
                -workspace AlpenLedger.xcworkspace \
                -scheme AlpenLedgerApp \
                -destination 'platform=macOS,arch=arm64'
        )
        ;;
    0 | "")
        echo
        echo "Skipping UI automation. Set RUN_UI_TESTS=1 for representative UI coverage or RUN_UI_TESTS=full after macOS automation permissions are available."
        ;;
esac
