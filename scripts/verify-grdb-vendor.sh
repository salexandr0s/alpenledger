#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UPSTREAM_REPO="https://github.com/groue/GRDB.swift"
readonly UPSTREAM_TAG="v7.10.0"
readonly VENDOR_DIR="$REPO_ROOT/Packages/Vendor/GRDB.swift"
readonly PATCH_FILE="$REPO_ROOT/scripts/grdb-v7.10.0-sqlcipher.patch"
offline=0

usage() {
    cat <<'USAGE'
Usage: scripts/verify-grdb-vendor.sh [--offline]

Verifies the vendored GRDB.swift snapshot and SQLCipher patch.

Default mode clones the pinned upstream tag and compares it with the local
vendor directory after applying the checked-in SQLCipher patch.

Use --offline for readiness runs that must avoid network access. Offline mode
still verifies the vendored directory exists, forbidden nested metadata is
absent, the patch file exists, and the SQLCipher-critical Package.swift wiring
is present.
USAGE
}

while (($# > 0)); do
    case "$1" in
        --offline)
            offline=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$VENDOR_DIR" ]]; then
    echo "Vendored GRDB.swift snapshot is missing: $VENDOR_DIR" >&2
    exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "Vendored GRDB.swift SQLCipher patch is missing: $PATCH_FILE" >&2
    exit 1
fi

for forbidden in .git .gitmodules; do
    if [[ -e "$VENDOR_DIR/$forbidden" ]]; then
        echo "Forbidden vendored metadata is present: $VENDOR_DIR/$forbidden" >&2
        exit 1
    fi
done

grep -q 'https://github.com/sqlcipher/SQLCipher.swift.git' "$VENDOR_DIR/Package.swift" || {
    echo "Vendored Package.swift is missing SQLCipher.swift dependency." >&2
    exit 1
}

grep -q 'exact: "4.13.0"' "$VENDOR_DIR/Package.swift" || {
    echo "Vendored Package.swift is not pinned to SQLCipher.swift 4.13.0." >&2
    exit 1
}

grep -q 'SQLITE_HAS_CODEC' "$VENDOR_DIR/Package.swift" || {
    echo "Vendored Package.swift is missing SQLITE_HAS_CODEC flags." >&2
    exit 1
}

if ((offline)); then
    echo "Vendored GRDB.swift offline invariants passed for $UPSTREAM_TAG plus the checked-in SQLCipher patch."
    exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$tmpdir/GRDB.swift"
find "$tmpdir/GRDB.swift" -maxdepth 1 \( -name .git -o -name .gitmodules -o -name .swiftpm \) -exec rm -r {} +

(
    cd "$tmpdir/GRDB.swift"
    git apply "$PATCH_FILE"
)

normalizedVendor="$tmpdir/current-vendor"
cp -R "$VENDOR_DIR" "$normalizedVendor"
find "$normalizedVendor" -maxdepth 1 \( \
    -name .build -o \
    -name build -o \
    -name .swiftpm -o \
    -name .DS_Store \
\) -exec rm -r {} + 2>/dev/null || true

if ! git diff --no-index --exit-code -- "$tmpdir/GRDB.swift" "$normalizedVendor"; then
    echo "Vendored GRDB.swift drift detected. Run scripts/update-grdb-vendor.sh." >&2
    exit 1
fi

echo "Vendored GRDB.swift matches upstream $UPSTREAM_TAG plus the checked-in SQLCipher patch."
