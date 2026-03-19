#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UPSTREAM_REPO="https://github.com/groue/GRDB.swift"
readonly UPSTREAM_TAG="v7.10.0"
readonly VENDOR_DIR="$REPO_ROOT/Packages/Vendor/GRDB.swift"
readonly PATCH_FILE="$REPO_ROOT/scripts/grdb-v7.10.0-sqlcipher.patch"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

git clone --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" "$tmpdir/GRDB.swift"
find "$tmpdir/GRDB.swift" -maxdepth 1 \( -name .git -o -name .gitmodules -o -name .swiftpm \) -exec rm -r {} +

find "$VENDOR_DIR" -maxdepth 1 \( -name .git -o -name .gitmodules -o -name .swiftpm \) -exec rm -r {} + 2>/dev/null || true
mkdir -p "$(dirname "$VENDOR_DIR")"
find "$(dirname "$VENDOR_DIR")" -maxdepth 1 -name "$(basename "$VENDOR_DIR")" -exec rm -r {} +
cp -R "$tmpdir/GRDB.swift" "$VENDOR_DIR"

(
    cd "$VENDOR_DIR"
    git apply "$PATCH_FILE"
)

echo "Updated vendored GRDB.swift to $UPSTREAM_TAG with SQLCipher patch."
