# Dependency Review Policy

AlpenLedger is a local-first finance application. Dependency changes therefore
need an explicit review record before they can enter the readiness gate.

## Policy

- Runtime dependencies must be pinned to an exact version or vendored snapshot.
- The app package must not add remote SwiftPM packages directly without updating
  `config/dependency-review.json`.
- Vendored dependencies must document upstream tag, commit, local patch, update
  process, and verification commands.
- Dependency updates must run the deterministic readiness gate before review.
- Security-sensitive dependencies, including storage, crypto, parsing, and export
  libraries, require targeted tests for the affected workflow.

## Required Checks

Run these commands from the repository root:

```sh
scripts/verify-dependency-review.sh
scripts/verify-grdb-vendor.sh
scripts/verify-readiness.sh
```

`scripts/verify-readiness.sh` runs `scripts/verify-grdb-vendor.sh --offline`
for routine local checks. Run the full GRDB verifier shown above before
dependency updates or release candidates because it compares the vendored tree
against upstream plus the checked-in SQLCipher patch.

Use `RUN_UI_TESTS=full scripts/verify-readiness.sh` before release candidates
or when dependency changes affect app launch, file import, storage, document
preview, or navigation.

## Adding Or Updating A Dependency

1. Update the package or vendored source.
2. Record the dependency in `config/dependency-review.json`.
3. Add or update the human review notes in this document or a dedicated vendor
   document.
4. Run `scripts/verify-dependency-review.sh`.
5. Run the dependency-specific verifier, such as
   `scripts/verify-grdb-vendor.sh` for GRDB.
6. Run `scripts/verify-readiness.sh`.

## Current Reviewed Dependencies

### SQLCipher.swift

- Source: `https://github.com/sqlcipher/SQLCipher.swift.git`
- Version: `4.13.0`
- Revision: `7da3c29da67ef5f6dac915647087d966451f00d3`
- Consumer: vendored GRDB SQLCipher build.
- Risk: encrypted database availability and compatibility.
- Required evidence: package tests, app CI tests, database health checks, and
  backup/restore tests.

### GRDB.swift

- Source: `https://github.com/groue/GRDB.swift`
- Vendored path: `Packages/Vendor/GRDB.swift`
- Upstream tag: `v7.10.0`
- Upstream commit: `36e30a6f1ef10e4194f6af0cff90888526f0c115`
- Local patch: `scripts/grdb-v7.10.0-sqlcipher.patch`
- Detailed vendor notes: `docs/grdb-vendor.md`
- Risk: database persistence, migrations, query behavior, and SQLCipher
  integration.
- Required evidence: `scripts/verify-grdb-vendor.sh`, package tests, app CI
  tests, database health checks, migration tests, and backup/restore tests.
