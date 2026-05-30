#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
    echo
    echo "==> $*"
    "$@"
}

(
    cd "$REPO_ROOT/Packages/AlpenLedgerKit"
    run env ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1 swift test --filter csvImportJobHandlesCustomerScaleFixtureWithinRegressionBudget
    run env ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1 swift test --filter workspaceGlobalSearchStaysBoundedOnLargerWorkspace
    run env ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1 swift test --filter workspaceReportingViewsScopedLookupsAndRestoreStayBoundedOnLargerWorkspace
)

echo
echo "Performance regression verification passed."
