#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT"

readonly SEARCH_ROOTS=(
    "App/AlpenLedgerApp"
    "Packages/AlpenLedgerKit/Sources"
)

readonly FORBIDDEN_PATTERNS=(
    'import[[:space:]]+Network'
    'import[[:space:]]+WebKit'
    'URLSession'
    'NSURLConnection'
    'URLRequest'
    'NWConnection'
    'NWListener'
    'NWBrowser'
    'WKWebView'
    'SFSafari'
    'ASWebAuthenticationSession'
    'dataTask[[:space:]]*\('
    'uploadTask[[:space:]]*\('
    'downloadTask[[:space:]]*\('
    'https?://'
)

status=0

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    matches="$(rg --glob '*.swift' --line-number --color never "$pattern" "${SEARCH_ROOTS[@]}" || true)"
    if [[ "$pattern" == 'https?://' && -n "$matches" ]]; then
        matches="$(
            printf '%s\n' "$matches" |
                rg --invert-match 'http://www\.ech\.ch/xmlns|http://www\.w3\.org/2001/XMLSchema-instance' || true
        )"
    fi
    if [[ -n "$matches" ]]; then
        printf '%s\n' "$matches"
        echo "Forbidden local-only runtime pattern found: $pattern" >&2
        status=1
    fi
done

if [[ "$status" -ne 0 ]]; then
    cat >&2 <<'EOF'
Local-only verification failed.

If AlpenLedger intentionally adds network or web runtime behavior, route it
through an explicit privacy-mode/provider boundary and update this verifier with
a narrow allowlist plus user-visible controls.
EOF
    exit "$status"
fi

echo "Local-only runtime source check passed: no networking or web runtime APIs found in app/package Swift sources."
