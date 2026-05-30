#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly COPY_REVIEW_DOC="$REPO_ROOT/docs/copy-review.md"
readonly CHECKLIST_DOC="$REPO_ROOT/docs/checklist.md"
readonly RELEASE_NOTES_DOC="$REPO_ROOT/docs/release-notes/v0.1.0.md"

fail() {
    echo "Copy review verification failed: $*" >&2
    exit 1
}

require_file() {
    local path="$1"
    [[ -f "$path" ]] || fail "missing required file: ${path#$REPO_ROOT/}"
}

require_contains() {
    local path="$1"
    local needle="$2"
    grep -Fq -- "$needle" "$path" || fail "${path#$REPO_ROOT/} missing required text: $needle"
}

require_file "$COPY_REVIEW_DOC"
require_file "$CHECKLIST_DOC"
require_file "$RELEASE_NOTES_DOC"

for section in \
    "## Principles" \
    "## Reviewed Surfaces" \
    "## Domain Error Copy Rules" \
    "## Help Copy Rules" \
    "## Localization Strategy Boundary" \
    "## Release Gate"
do
    require_contains "$COPY_REVIEW_DOC" "$section"
done

for anchor in \
    "domainErrorCopyIsSpecificAndActionableForReleaseReview" \
    "testDomainErrorsProduceActionableAlertPresentation" \
    "testHelpCenterAndFirstRunOnboardingAreAvailableWithoutWorkspace" \
    "scripts/verify-copy-review.sh" \
    "It is not a claim that the app is fully" \
    "The v0.1 pilot UI is English-first" \
    "Do not ask users to send raw workspace databases"
do
    require_contains "$COPY_REVIEW_DOC" "$anchor"
done

require_contains "$CHECKLIST_DOC" "- [x] Error/help copy review"
require_contains "$CHECKLIST_DOC" "docs/copy-review.md"
require_contains "$CHECKLIST_DOC" "scripts/verify-copy-review.sh"
require_contains "$CHECKLIST_DOC" "domainErrorCopyIsSpecificAndActionableForReleaseReview"
require_contains "$CHECKLIST_DOC" "- [x] Localization framework"
require_contains "$CHECKLIST_DOC" "- [ ] German/French/English readiness strategy"

require_contains "$RELEASE_NOTES_DOC" "Known Limitations"
require_contains "$RELEASE_NOTES_DOC" "English-first"
require_contains "$RELEASE_NOTES_DOC" "do not yet include German or"
require_contains "$RELEASE_NOTES_DOC" "French localization"

(
    cd "$REPO_ROOT/Packages/AlpenLedgerKit"
    swift test --filter DomainErrorCopy
)

echo "Copy review verification passed."
