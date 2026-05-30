# GRDB Vendor Snapshot

As of March 19, 2026, AlpenLedger vendors [GRDB.swift](https://github.com/groue/GRDB.swift) from upstream tag `v7.10.0` at commit `36e30a6f1ef10e4194f6af0cff90888526f0c115`.

## Why We Vendor It

- AlpenLedger is a local-core macOS app and needs a deterministic database layer that does not depend on remote package drift during bootstrap.
- The app requires a pinned SQLCipher-enabled GRDB build behind the local package graph.
- Vendoring keeps the SQLCipher integration explicit, reviewable, and testable inside this repository.

## Local Modifications

- `Package.swift` is patched to depend on `SQLCipher.swift` `4.13.0` exactly.
- `Package.swift` enables `SQLITE_HAS_CODEC` and `SQLCipher` Swift/C settings.
- `Package.swift` removes the `GRDBSQLite` system-library wiring and adds a `GRDBSQLCipher` target.
- `GRDB` links against `SQLCipher` and `GRDBSQLCipher`.
- Upstream `v7.10.0` already includes the `Sources/GRDBSQLCipher/` shim files; the local patch only activates that path in `Package.swift`.
- Nested metadata is intentionally stripped from the vendored snapshot:
  - `.git`
  - `.gitmodules`
- Local SwiftPM may recreate `.swiftpm` during development; it must remain untracked and is ignored by the verifier.

## Update Process

1. Run `scripts/update-grdb-vendor.sh`.
2. Run `scripts/verify-grdb-vendor.sh`.
3. Run `swift test --package-path Packages/AlpenLedgerKit`.
4. Run `xcodebuild -project AlpenLedgerApp.xcodeproj -scheme AlpenLedgerAppCI -destination 'platform=macOS' -derivedDataPath /tmp/alpenledger-grdb-vendor test`.

## Guardrail

Do not edit `Packages/Vendor/GRDB.swift` by hand without also updating `scripts/grdb-v7.10.0-sqlcipher.patch` and re-running `scripts/verify-grdb-vendor.sh`.

`scripts/verify-readiness.sh` runs `scripts/verify-grdb-vendor.sh --offline`
so local readiness checks catch missing vendor files, forbidden nested
metadata, and SQLCipher-critical package wiring without cloning upstream on
every run. Use the default verifier mode before changing or releasing the
vendor snapshot because it compares against upstream `v7.10.0` plus the
checked-in patch.
