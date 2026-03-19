#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UPSTREAM_REPO="https://github.com/groue/GRDB.swift"
readonly UPSTREAM_TAG="v7.10.0"
readonly VENDOR_DIR="$REPO_ROOT/Packages/Vendor/GRDB.swift"
readonly PATCH_FILE="$REPO_ROOT/scripts/grdb-v7.10.0-sqlcipher.patch"

if [[ ! -d "$VENDOR_DIR" ]]; then
    echo "Vendored GRDB.swift snapshot is missing: $VENDOR_DIR" >&2
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
find "$normalizedVendor" -maxdepth 1 \( -name .swiftpm -o -name .DS_Store \) -exec rm -r {} + 2>/dev/null || true

if ! git diff --no-index --exit-code -- "$tmpdir/GRDB.swift" "$normalizedVendor"; then
    echo "Vendored GRDB.swift drift detected. Run scripts/update-grdb-vendor.sh." >&2
    exit 1
fi

echo "Vendored GRDB.swift matches upstream $UPSTREAM_TAG plus the checked-in SQLCipher patch."
