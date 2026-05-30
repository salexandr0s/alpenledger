#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PRODUCT_SCOPE="$REPO_ROOT/docs/product-scope.md"
readonly RISK_REGISTER="$REPO_ROOT/docs/risk-register.md"
readonly GOVERNANCE="$REPO_ROOT/docs/governance.md"
readonly ADR_DIR="$REPO_ROOT/docs/adr"

failures=()

record_failure() {
    failures+=("$1")
}

require_file() {
    if [[ ! -f "$1" ]]; then
        record_failure "Missing required governance file: $1"
    fi
}

require_pattern() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    if [[ -f "$file" ]] && ! grep -Eq "$pattern" "$file"; then
        record_failure "$message"
    fi
}

require_file "$PRODUCT_SCOPE"
require_file "$RISK_REGISTER"
require_file "$GOVERNANCE"

if [[ ! -d "$ADR_DIR" ]]; then
    record_failure "Missing ADR directory: $ADR_DIR"
else
    adrs=()
    while IFS= read -r adr; do
        adrs+=("$adr")
    done < <(find "$ADR_DIR" -maxdepth 1 -type f -name 'ADR-*.md' | sort)
    if ((${#adrs[@]} < 3)); then
        record_failure "Expected at least 3 ADRs; found ${#adrs[@]}."
    fi
    for adr in "${adrs[@]}"; do
        require_pattern "$adr" '^## Status$' "$adr must include a Status section."
        require_pattern "$adr" '^(Accepted|Proposed|Superseded)$' \
            "$adr must declare an ADR status value."
        require_pattern "$adr" '^## Decision$' "$adr must include a Decision section."
        require_pattern "$adr" '^## Consequences$' "$adr must include a Consequences section."
    done
fi

for section in \
    "Locked V1 Thesis" \
    "Target Users" \
    "Pilot Canton" \
    "Pilot Business Profile" \
    "V1 Non-Goals" \
    "Scope Review Rules"
do
    require_pattern "$PRODUCT_SCOPE" "^## ${section}$" \
        "Product scope must include section: ${section}."
done

require_pattern "$PRODUCT_SCOPE" 'local-first' \
    "Product scope must preserve the local-first thesis."
require_pattern "$PRODUCT_SCOPE" 'Zurich' \
    "Product scope must lock the pilot canton."
require_pattern "$PRODUCT_SCOPE" '2026' \
    "Product scope must lock the pilot tax year."
require_pattern "$PRODUCT_SCOPE" 'sole proprietor|freelancer' \
    "Product scope must lock the pilot business profile."
require_pattern "$PRODUCT_SCOPE" 'automatic authority submission|Automatic filing submission' \
    "Product scope must state automatic submission is out of scope."

for section in "Review Cadence" "Register"; do
    require_pattern "$RISK_REGISTER" "^## ${section}$" \
        "Risk register must include section: ${section}."
done

for category in Legal Tax Security "Data Integrity" "AI Safety" Release Quality; do
    require_pattern "$RISK_REGISTER" "\\| [^|]* \\| ${category} \\|" \
        "Risk register must include category: ${category}."
done

for status in Open Mitigated; do
    require_pattern "$RISK_REGISTER" "\\| ${status} \\|" \
        "Risk register must include at least one ${status} risk."
done

for section in \
    "Source Of Truth" \
    "Maintenance Rules" \
    "Verification"
do
    require_pattern "$GOVERNANCE" "^## ${section}$" \
        "Governance docs must include section: ${section}."
done

for referenced in \
    'docs/product-scope.md' \
    'docs/risk-register.md' \
    'docs/adr/' \
    'docs/checklist.md' \
    'docs/readiness-audit-2026-05-29.md' \
    'docs/release.md'
do
    require_pattern "$GOVERNANCE" "$referenced" \
        "Governance docs must reference ${referenced}."
done

if [[ ${#failures[@]} -gt 0 ]]; then
    echo "Product governance verification failed:" >&2
    for failure in "${failures[@]}"; do
        echo "  - $failure" >&2
    done
    exit 1
fi

echo "Product governance verification passed."
