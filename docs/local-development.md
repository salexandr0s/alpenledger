# Local Development

This guide records the local setup that is currently verified for AlpenLedger.
It is bootstrap documentation, not proof that a clean machine has passed every
release gate.

## Toolchain

- macOS with Xcode selected at `/Applications/Xcode.app`.
- Xcode 26.3, build 17C529.
- Apple Swift 6.2.4.
- XcodeGen 2.45.2 when regenerating `AlpenLedgerApp.xcodeproj` from
  `project.yml`.

Check the active tools:

```sh
xcodebuild -version
swift --version
xcodegen --version
```

Install XcodeGen if needed:

```sh
brew install xcodegen
```

## Fresh Checkout Bootstrap

From the repository root:

```sh
git submodule update --init --recursive
```

Regenerate the Xcode project when `project.yml` changes or when validating a
fresh checkout:

```sh
xcodegen generate
```

Open the checked-in workspace:

```sh
open AlpenLedger.xcworkspace
```

To verify the bootstrap path without relying on local generated artifacts, run:

```sh
scripts/verify-fresh-checkout.sh
```

That command creates a disposable source copy from tracked and non-ignored
untracked files, requires the verified XcodeGen 2.45.2 baseline, regenerates
the Xcode project, and runs the readiness gate from the copy. The gate includes
project-structure validation that package tests declare the dependencies they
import directly with `@testable import AL...`, which catches cold SwiftPM
package-graph drift that a warm local checkout can mask. Pass `RUN_UI_TESTS=full`
to include the full app UI scheme in the disposable-copy verification.

## Verification

Run the deterministic local readiness gate:

```sh
scripts/verify-readiness.sh
```

The script currently runs:

- CI scheme XML validation.
- Project structure and local toolchain baseline verification.
- Source style verification through `.editorconfig` and
  `scripts/verify-source-style.sh`.
- Release-note structure verification for the current app version.
- Configuration-only release preflight for signing/notary settings,
  release metadata, and local packaging/notarization tools.
- Product governance verification for scope, risk register, ADRs, and
  documentation-maintenance anchors.
- Documentation alignment verification for canonical source-of-truth paths,
  cross-links, prompt reading order, and core scope/trust boundaries.
- Support documentation verification for private support intake, sanitized
  diagnostic artifacts, privacy boundaries, backup safety, and triage runbooks.
- Agent tool-safety verification for explicit approval, provenance,
  unrestricted file access, raw SQL, and shell execution.
- Offline local-only smoke verification.
- Dependency review policy verification.
- Vendored GRDB/SQLCipher snapshot verification in offline mode.
- Fixture catalog verification.
- Schema catalog verification and offline eCH-0217 XSD validation.
- Focused performance regression verification for import throughput and
  larger-workspace storage query budgets.
- Swift package tests for `Packages/AlpenLedgerKit`.
- App CI unit tests through `AlpenLedgerAppCI`.
- Optional representative UI automation when `RUN_UI_TESTS=1`.
- Optional full app-scheme UI automation when `RUN_UI_TESTS=full`.

Run the local-only source check directly with:

```sh
scripts/verify-local-only.sh
```

That verifier fails if app/package Swift sources introduce network or web
runtime APIs without first adding an explicit privacy-mode/provider boundary and
updating the allowlist.

Vendor verification is available separately:

```sh
scripts/verify-project-structure.sh
scripts/verify-source-style.sh
scripts/verify-release-notes.sh
scripts/verify-support-docs.sh
scripts/verify-copy-review.sh
scripts/verify-localization.sh
scripts/verify-product-governance.sh
scripts/verify-doc-alignment.sh
scripts/verify-agent-tool-safety.sh
scripts/verify-dependency-review.sh
scripts/verify-fixtures.sh
scripts/verify-schemas.sh
scripts/verify-performance.sh
scripts/verify-offline-smoke.sh
scripts/verify-grdb-vendor.sh
```

The source style verifier is local-only and checks owned app/package, docs,
script, config, and workflow text files for LF line endings, final newlines,
trailing whitespace, unresolved merge-conflict markers, leading tabs in
hand-edited source/docs, executable shell scripts, shell syntax, and Bash 3.2
compatibility for release scripts. It uses
`git ls-files` in a working tree and falls back to a repository-shaped
filesystem scan in disposable source copies that do not include `.git`, while
omitting generated package build outputs. The
project-structure verifier checks the workspace, checked-in Xcode project,
shared CI scheme, `project.yml`, local package graph, bundle version metadata,
package-test dependency declarations, and selected local Xcode/Swift/XcodeGen
baselines. The release-note verifier
checks that the current `Info.plist` marketing version has a matching
`docs/release-notes/v<version>.md` draft with the required release sections and
evidence commands; use `scripts/verify-release-notes.sh --strict` for release
candidates after final evidence is captured. The support documentation verifier
checks `docs/support.md`, release notes, release docs, and local-development
docs for the sanitized diagnostics workflow, private intake boundaries, backup
safety, and triage runbook anchors. The copy-review verifier checks
`docs/copy-review.md`, release notes, checklist evidence, and focused
domain-error copy tests for specific titles, localized descriptions, and
actionable recovery suggestions. The localization verifier checks the
English-first app/package baseline, `config/localization-catalog.json`,
`docs/localization.md`, release-note language boundaries, and focused
`LocalizationPolicy` tests. The product governance verifier checks that
product scope, risk register, ADR, and documentation maintenance artifacts
contain the required release anchors. The agent tool-safety verifier
checks production tool declarations, agent-facing source access patterns, and
focused `AgentToolPolicy` tests so unrestricted file access, raw SQL, shell
execution, missing provenance, and unapproved confirmed-write tools cannot enter
the readiness gate. The dependency review verifier is local-only and checks
`config/dependency-review.json`, `Package.resolved`, and vendored dependency
metadata. The fixture verifier is local-only and checks
`config/fixture-catalog.json`, fixture hashes, app resource registration, basic
CSV/CAMT.052/CAMT.053/CAMT.054/QR-bill/PDF/text/VAT JSON and expected-tax JSON
format sanity, eCH tax-certificate XML markers, personal/business draft export
readiness JSON shape, customer-scale bank-statement row/counterparty/currency
expectations, and high-risk personal-data patterns in text-like fixtures. The
schema verifier is local-only and checks `config/schema-catalog.json`, vendored
eCH XSD hashes, and the eCH-0217 VAT export fixture with `xmllint --nonet`. The
performance verifier sets
`ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1` and runs focused Swift package
regressions for the full CSV import job path, global search over a larger
workspace, and reporting/lookup storage budgets over a larger workspace. Normal
full-package test runs keep those scenarios as functional coverage without
wall-clock assertions under parallel test load. The offline smoke verifier runs the
runtime local-only source check and a focused
hosted app test against isolated local workspace, secret-store, and defaults
roots. The readiness gate runs `scripts/verify-grdb-vendor.sh --offline` to
check local SQLCipher-critical vendor invariants without network access; run
`scripts/verify-grdb-vendor.sh` without `--offline` before dependency updates
or release candidates because full mode clones the upstream GRDB tag.

## CI

`.github/workflows/macos-ci.yml` is the pull-request and push gate. It selects
Xcode 26.3, installs XcodeGen, checks patch whitespace, verifies the dependency
review policy, verifies the fixture and schema catalogs, verifies the vendored
GRDB snapshot, regenerates the Xcode project and fails if the checked-in project
is stale, runs release preflight in configuration-only mode, and executes
`scripts/verify-readiness.sh`.

## UI Automation

UI tests are not part of the default readiness script because local macOS
automation permissions can block the runner before app assertions execute.
When UI automation is requested, `scripts/verify-readiness.sh` first runs
`scripts/verify-ui-automation-preflight.sh` to fail fast if Accessibility UI
scripting is unavailable on the runner.

After granting the terminal or Xcode permission to control the computer, run:

```sh
RUN_UI_TESTS=1 scripts/verify-readiness.sh
```

Representative mode runs the workspace create/reopen flow, an Overview-to-Inbox
document-link flow, and the Copilot `Turn Into Task` flow. It is intended as a
faster native UI check before the full app scheme.

For the full app scheme, run:

```sh
RUN_UI_TESTS=full scripts/verify-readiness.sh
```

`docs/ui-smoke-pass-macos.md` remains the manual smoke check for window-size,
motion, and visual review coverage beyond the automated UI suite. Release
candidates must archive and verify the manual evidence record with:

```sh
scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json
```

## Runtime Environment

The app supports these local test/runtime overrides:

- `ALPENLEDGER_WORKSPACES_ROOT`: directory for test workspaces.
- `ALPENLEDGER_SECRET_STORE_ROOT`: directory-backed secret store for tests.
- `ALPENLEDGER_DEFAULTS_SUITE`: isolated `UserDefaults` suite.
- `ALPENLEDGER_FIXED_NOW`: ISO-8601 timestamp for deterministic runs.
- `ALPENLEDGER_PRIVACY_MODE`: privacy mode override. Currently only
  `local-only`/`offline` are accepted; unsupported values such as `cloud`
  resolve back to local-only mode and do not enable network or cloud inference.
- `ALPENLEDGER_FEATURE_FLAGS`: comma-separated feature flags. Currently
  supports `qa-validation-fixtures` in Debug builds.
- `ALPENLEDGER_ENABLE_QA_VALIDATION_FIXTURES`: explicit boolean override for
  the Debug-only QA fixture import command.
- `ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS`: enables wall-clock assertions for
  focused performance tests. `scripts/verify-performance.sh` sets this
  automatically; leave it unset for normal full package runs.

Production use should omit these unless a controlled local test environment
needs them.

## Release Preflight

Run the configuration-only release preflight locally with:

```sh
scripts/verify-release-preflight.sh --allow-missing-secrets
```

Strict release preflight requires Developer ID and notary credentials:

```sh
scripts/verify-release-preflight.sh
```

To verify the release ZIP packaging command without private credentials:

```sh
scripts/verify-release-packaging.sh
```

After signing, notarizing, and stapling a release app bundle, create the final
ZIP and checksum with:

```sh
scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases
```

The packaging script stages the ZIP and checksum sidecar first, then publishes
them to `dist/releases` only after final artifact verification passes. Use
`--skip-final-verification` only for local rehearsals.

Once a signed, notarized, stapled release ZIP exists, verify the final artifact
and generated checksum sidecar with:

```sh
scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip
```

The final release candidate must also archive and validate the release evidence
manifest:

```sh
scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v0.1.0.json
```

See `docs/release.md` for the required environment variables and the remaining
evidence needed before the signed/notarized release gate can be marked complete.

## Backup Handling

Local backup bundles contain `workspace.key`, the workspace master key. Treat
backup bundles like live workspace data and store them only in a protected local
location.

## Support Diagnostics

The operational support runbook is [support.md](support.md). Keep it aligned
with the Settings and File-menu support export surfaces before each release
candidate:

```sh
scripts/verify-support-docs.sh
```

Use `File > Export Diagnostics...` or Settings to write a local sanitized JSON
diagnostics report. The report includes database health, schema table counts,
and filesystem counts, but excludes source documents, document names,
transaction text, workspace names, absolute paths, amounts, and encryption keys.

Use `File > Export Support Bundle...` or Settings when support also needs audit
log shape. The support bundle includes the diagnostics report plus audit event
counts, actor/event/object-kind summaries, and bounded recent event metadata.
It fingerprints raw event IDs, actor IDs, and object IDs, and excludes raw audit
payloads, source documents, document names, transaction text, workspace names,
absolute paths, amounts, and encryption keys.
