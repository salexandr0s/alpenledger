# AlpenLedger Readiness Audit - 2026-05-29

This audit records the current production-readiness evidence from the local
worktree. It is not a declaration that AlpenLedger is production-ready.

## Scope

- Repository: `/Users/nationalbank/GitHub/alpenledger`
- App: native macOS SwiftUI app
- Package: `Packages/AlpenLedgerKit`
- Xcode workspace: `AlpenLedger.xcworkspace`
- Date: 2026-05-29
- Last updated: 2026-05-30

## Gates Run

### Swift package tests

Command:

```sh
swift test
```

Working directory:

```text
Packages/AlpenLedgerKit
```

Result:

- Passed.
- 247 tests executed in the latest package gate.
- 0 failures.

Notes:

- Initial run failed in `MoneyFormatterTests.moneyFormatterBasic` because
  Foundation returned ASCII `'` as the Swiss grouping separator while the test
  expected `\u{2019}`.
- `MoneyFormatter` now explicitly sets `groupingSeparator` and
  `decimalSeparator`, making currency rendering deterministic across local
  environments.
- `WorkspaceBackupRestore` coverage now verifies a service-level backup and
  restore round trip for workspace metadata, SQLCipher-backed database data,
  encrypted blobs, workspace master key export/import, temp-file exclusion,
  audit events, recent-workspace registration, manifest file hashes, and
  rejection of tampered hashed backup files.
- Workspace storage foundations are now recorded as release-ready for the
  current local-first surface: production defaults use `KeychainSecretStore`,
  workspace SQLite opens through SQLCipher, imported/generated files are stored
  through encrypted blobs, `WorkspaceCrypto` derives separate database/blob keys
  from a per-workspace master key and salt, and `WorkspacePaths` fixes the
  `workspace.json`, `workspace.sqlite`, `blobs/`, `exports/`, and `temp/`
  layout. The optional workspace lock/auth gate now requires macOS
  device-owner authentication before reopening locked workspaces and returns
  locked sessions to the workspace chooser.
- Realistic backup/restore coverage now verifies a multi-entity workspace graph
  with statement imports, transactions, documents, evidence links, issues,
  tax facts, invoice metadata, agent proposal decisions, filing-package state,
  raw statement blobs, and default entity-workspace state.
- Customer-scale backup/restore coverage now imports the cataloged 2,500-row
  CSV fixture through the import job pipeline, validates the backup bundle,
  restores it into a new workspace root, and verifies the restored source blob,
  statement, 2,500 transactions, 80 counterparties, restore audit event, and
  recent-workspace registration.
- Raw-import immutability coverage now verifies that imported bank statement
  CSVs and documents remain readable from their encrypted source blobs after
  the original source files are changed on disk.
- Document-intake failure coverage now verifies that failed imports mark the
  import job failed, record a `document.import_failed` diagnostic, remove the
  materialized temp source, and delete a newly-created encrypted blob only when
  no persisted document references it.
- Balanced journal-entry coverage verifies that balanced entries are accepted,
  unbalanced or empty entries are rejected, and journal lines preserve tax-code
  mappings for VAT/posting workflows.
- Locked-period coverage verifies that statement imports and tax fact refreshes
  are rejected when they would mutate a locked tax year, and that statement
  imports are rejected when they would mutate a locked VAT period.
- Tax-year lock/reopen coverage verifies audited open/locked transitions,
  idempotent persistence, and rejection of filed-year reopening.
- Tax-fact provenance coverage verifies JSON round trip and supersession
  preservation: retired facts keep their original provenance refs, replacements
  carry their own refs, and current facts point back to the superseded value.
- Manual-override coverage verifies that tax fact overrides require a reason,
  write an audit event, are rejected in locked tax years, and survive
  deterministic recomputation without being silently replaced.
- Tax-fact explanation coverage verifies that supporting document refs resolve
  into source summaries and missing provenance refs are reported explicitly.
- Agent tool-safety coverage verifies the typed tool registry policy: production
  defaults pass, confirmed-write tools require explicit user confirmation, and
  unsafe tool definitions are rejected for missing scopes/provenance, raw SQL,
  shell execution, duplicate names, or missing confirmation. Executor coverage
  verifies that registered tool handlers cannot run without required scopes,
  confirmed-write approval, a matching reviewed-input hash, a safe registry,
  and result provenance.
- Agent tool-workflow coverage verifies concrete workspace handlers routed
  through `AgentToolExecutor`: missing scopes reject before mutation,
  `finance.list_accounts` returns entity-scoped account summaries,
  `finance.account_summary` returns scoped balance/transaction/statement
  summaries,
  `finance.search_transactions` returns scoped transaction summaries while
  rejecting cross-entity account IDs, `docs.search` returns filtered document
  summaries without raw document text, `docs.get_summary` returns a bounded
  document snippet, `issues.list_open` returns open issue summaries,
  `reconcile.statement_coverage` returns scoped missing-statement coverage,
  `tax.list_requirements` returns scoped requirement summaries,
  `tax.preview_status` returns current tax facts, pending requirements, open
  issues, and deterministic readiness counts when the app injects
  `TaxValidationService`, `tax.explain_fact` resolves source refs while
  reporting missing refs explicitly,
  `issues.open_or_update` creates an issue with bounded fingerprint/summary
  text, scoped object/related refs, provenance, and audit trail, and
  `docs.propose_match` creates a review proposal without creating a confirmed
  evidence link while rejecting assigned document/transaction matches that
  cross legal-entity boundaries.
- Proposal approval coverage verifies that a reviewer-approved document-match
  proposal creates exactly one confirmed evidence link, resolves the proposal,
  preserves decision metadata, and writes proposal/evidence audit events.
- Proposal revocation coverage verifies that a reviewer can reverse an approved
  document-match proposal without deleting evidence: the evidence link is marked
  revoked, confirmed-link lookups ignore it, decision metadata is updated, and
  proposal/evidence audit events are written.
- Business expense evidence coverage verifies that imported expenses for a real
  sole-proprietor/business entity create missing-evidence issues and pending
  requirements, then resolve to satisfied requirements after a receipt is linked
  through the confirmed document-to-transaction evidence service.
- Database health coverage verifies that fresh workspaces pass SQLite
  `quick_check`, have foreign-key enforcement enabled, have no foreign-key
  violations, match the expected migration ledger, and include required schema
  tables and read-only reporting views. It also verifies that a missing
  migration ledger row or missing required reporting view is reported as a
  blocker.
- Migration coverage verifies empty-database schema creation, full migration
  idempotency, required table/view/index/FTS creation, latest migration
  columns, transaction VAT tax-code mapping, VAT period table/index creation,
  reporting view creation through migration `v13_reporting_views`, a legacy
  v12-to-current reporting-view upgrade that proves existing statement
  coverage, cashflow, spending, missing-evidence, tax-fact,
  unmatched-transaction, and VAT-period state is exposed through the new
  read-only views after migration, global-search FTS creation through migration
  `v14_global_search`, a legacy v13-to-current global-search upgrade that backfills existing documents,
  transactions, counterparties, and issues into the new search index and proves
  those records remain searchable after migration, a legacy v9-to-current
  filing-package upgrade that preserves generated package state
  and locked VAT-period evidence while adding finalization metadata, and a
  legacy v4-to-current backfill for entity-scoped documents, entity
  workspaces, agent proposal metadata, agent uncertainty metadata, and
  transaction counterparty identity links. It now also manually installs a
  legacy v5 database with an existing pending proposal and verifies v6/v7/v15
  add decision, related-ref, and uncertainty metadata while keeping the row
  readable and writable through the production proposal repository. It also
  manually installs a legacy v10 accounting database with existing ledger
  accounts, a transaction, VAT-period state, a generated filing package, and a
  computed tax fact, then
  verifies `v11_journal_entries` adds usable journal-entry/journal-line tables
  without losing that state. It also manually installs a
  legacy v14 database with an existing pending agent proposal and verifies
  `v15_agent_proposal_uncertainty_metadata` adds default uncertainty metadata
  without losing proposal evidence, related refs, confidence, status, or
  decision fields. A separate legacy v15 database with an existing failed
  import job verifies `v16_import_diagnostics` adds diagnostic storage and
  indexes, accepts diagnostics through the production repository, preserves
  foreign-key integrity, and cascades diagnostic cleanup with deleted import
  jobs. Another legacy v17 database with existing import jobs, agent
  conversations, messages, and pending approvals verifies the current migrator
  applies `v18_import_job_source_tracking` and `v19_agent_run_trace` without
  losing those rows. A legacy v19 archive-state fixture verifies
  `v20_document_archive_state` preserves active documents while adding archive
  status, review metadata, and restored search indexing.
- Migration recovery coverage verifies that workspace open creates a hidden
  database-file snapshot before pending migrations, restores the original
  `workspace.sqlite` files when an injected migrator fails after touching the
  database, and removes stale recovery snapshots after a later successful open.
- Reporting-view coverage verifies `vw_spend_by_month`,
  `vw_cashflow_by_entity`, `vw_missing_evidence`, `vw_statement_coverage`,
  `vw_tax_fact_status`, `vw_unmatched_transactions`, and
  `vw_vat_reconciliation` against real workspace data. The same test verifies
  the views reject writes, preserving the read-only contract for AI/UI query
  consumers. Larger-workspace coverage seeds statements, transactions, evidence
  links, issues, tax facts, and a VAT period, then verifies reporting views,
  tax-status rows, import/reconciliation lookups, scoped repository fetches, and
  backup/restore counts with bounded storage query budgets. The customer-scale
  fixture restore drill also proves the full imported statement payload and
  encrypted source blob survive backup and restore.
- Global-search coverage verifies `SQLiteSearchIndex.search` returns typed,
  workspace-scoped hits backed by external-content `global_search` FTS for
  documents, transactions, counterparties, and issues inserted through the
  normal repositories. Larger-workspace coverage seeds more than 5,000
  persisted searchable records and verifies bounded document, transaction,
  counterparty, and issue hits within a one-second FTS query budget. Evidence
  refresh coverage verifies database health after issue indexing and
  re-indexing.
- App global-search coverage verifies the top-level workspace toolbar search
  entry point, storage-backed search results, and navigation from document,
  transaction, counterparty, and issue hits into the existing Documents, Ledger,
  and Inbox surfaces.
- Fixture coverage verifies the current synthetic CSV bank statement,
  customer-scale CSV bank statement, CAMT.052 account reports, CAMT.053 bank
  statements, CAMT.054 debit/credit notifications, QR-bill text payload,
  receipt PDF, eCH-0196/eCH-0248/eCH-0275 tax-certificate import detection,
  Swiss VAT quarter reconciliation, Zurich 2026 personal-tax certificate and
  draft export readiness, and Zurich 2026 sole-proprietor business-tax draft
  export readiness through importer, import-pipeline, reconciliation, document
  extraction, tax fact derivation, explanation, and UI tests. The fixture
  catalog verifier records stable hashes and coverage references for every file
  under `Fixtures/`.
- CAMT.052/CAMT.053/CAMT.054 import coverage verifies fixture recognition,
  opening/closing balance extraction where present, signed credit/debit amounts,
  booking/value dates, structured references, counterparties, multi-report and
  multi-statement coverage windows, CAMT.054 batched transaction details,
  default import-pipeline routing, and `bankStatementCAMT` import-job
  persistence.
- The importer test harness now runs every bank-statement importer fixture
  through the same contract: recognizer behavior, parser identity, import-job
  kind, source metadata, fingerprint presence, coverage ordering, balances, row
  counts, diagnostics, transaction account and statement links, CHF
  normalization, references, source-line refs, and format-specific recognizer
  specificity.
- Import parse diagnostics now persist as structured `ImportDiagnostic` rows
  tied to import jobs. CSV/CAMT parser warnings carry severity, stable code,
  source location, message, and import-job provenance; failed statement imports
  write an error diagnostic. Inbox import rows and inspectors surface diagnostic
  summaries and first findings for reviewer triage.
- Inbox import inspectors now show parser identity, status, timing, stored-source
  availability, source fingerprint, warnings/errors, and diagnostics. Failed or
  cancelled bank-statement imports with a stored source blob expose a
  reviewer-facing `Retry Import` action that reprocesses from the encrypted blob
  and selects the replacement completed import when available.
- Failed statement imports now classify diagnostics as corrupt file,
  unsupported format, duplicate, locked period, or generic failure. Corrupt CSV
  and malformed CAMT.053 regression tests verify failed import jobs get stable
  error diagnostics and do not persist statement imports or transactions.
- CSV statement import cancellation now records a `cancelled` import job,
  persists an `import.cancelled` warning diagnostic, audits
  `importJobCancelled`, writes no statement imports or transactions, and allows
  the same source file to be imported successfully later.
- Cancelled bank-statement imports can now be retried from the stored encrypted
  raw source blob even after the original source file is gone. The retry path
  preserves the original source filename on the replacement import job and keeps
  completed raw-source duplicate protection intact.
- Successful statement imports now persist the statement, transactions,
  diagnostics, completed import job, and success audit events in one database
  transaction. This prevents post-commit audit failures from rewriting a
  persisted statement import as failed.
- Backup creation now writes into a hidden sibling staging directory and moves
  the complete bundle into the final selected path only after the workspace
  copy, key, hashes, and manifest are complete.
- Failed backup restores now remove the temporary restored workspace directory
  and delete the restored workspace master key when that key was inserted by the
  failed restore attempt. `workspaceBackupRestoreRemovesInsertedKeyWhenOpenFails`
  injects the open failure and verifies both cleanup paths.
- Import-throughput coverage now verifies the full CSV import job path with a
  cataloged 2,500-row customer-scale bank statement fixture. The test checks
  persisted transactions, statement metadata, counterparties, audit events, zero
  diagnostics, and a 12-second local regression budget when
  `scripts/verify-performance.sh` sets
  `ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1`. The normal full package suite
  still verifies the same data shape without wall-clock assertions under
  parallel test load. The performance verifier runs this with larger-workspace
  global-search and reporting/lookup budget tests under the readiness gate.
- Crash-safe import recovery now marks interrupted import jobs as failed during
  workspace opening. `ImportJobService.recoverInterruptedImports` writes an
  `import.interrupted` diagnostic and an `importJobRecovered` audit event for
  still-started jobs, while leaving completed jobs unchanged. `WorkspaceAppModel`
  invokes the recovery step before refreshing workspace data, so recovered
  import jobs and diagnostics are visible in the import review state.
- Rule-pack validation is now an explicit local gate: the catalog in
  `config/rule-pack-catalog.json` declares the Zurich 2026 personal-tax adapter,
  supported entity kinds, expected concepts, fixture pack, and golden facts;
  `RulePackValidationService` checks registered packs against natural-person and
  sole-proprietor fixture samples; and `scripts/verify-rule-packs.sh` combines
  catalog integrity checks with focused Swift tests under the readiness script.
- A realistic end-to-end package scenario now exercises the service pipeline
  rather than a hand-seeded graph: encrypted workspace creation, personal tax
  document import, deterministic tax fact/readiness refresh, sole-proprietor CSV
  bank import, evidence refresh, fixture-backed VAT reconciliation and lock,
  sanitized support bundle export, and backup integrity validation. The focused
  `scripts/verify-end-to-end-scenarios.sh` gate is included in readiness.
- QR-bill extraction coverage verifies Swiss QR-code text payload detection,
  QRR reference extraction, creditor/debtor names, structured address fields,
  CHF amount parsing, and fixture catalog governance. Native QR image decoding
  and OCR fallback are not claimed by this evidence.
- VAT period coverage verifies Swiss VAT code modeling for 2026 standard,
  reduced, accommodation, exempt, and outside-scope treatments, persisted
  transaction tax-code mapping, persisted VAT period reconciliation from the
  entity ledger, fixture-backed period totals, line-level taxable bases,
  output/input/net payable tax, blocker/warning diagnostics for missing,
  unknown, or directionally suspicious VAT mappings, audited VAT period
  lock/reopen transitions, lock rejection when blockers remain, overlap
  rejection, statement-import rejection for locked VAT periods, and
  deterministic eCH-0217 v2.0.0 effective-reporting XML export with local
  metadata, structure, payable-tax validation, and offline official eCH XSD
  validation for the golden export fixture. Tax Studio now surfaces persisted
  VAT period summaries and reconciliation blockers/warnings for the selected
  entity/year with source refs in the inspector.
- Support diagnostics coverage verifies that a local JSON diagnostics export
  includes database health, schema table counts, and filesystem counts while
  omitting workspace names, absolute paths, encryption keys, document contents,
  document filenames, transaction descriptions, and transaction amounts.
- Support bundle coverage verifies that a local JSON support bundle combines
  diagnostics with sanitized audit-log counts and recent event metadata while
  omitting raw audit payloads, raw actor IDs, raw object IDs, workspace names,
  absolute paths, encryption keys, source document contents, document
  filenames, transaction descriptions, and transaction amounts.

### App CI unit tests

Command:

```sh
xcodebuild test \
  -workspace AlpenLedger.xcworkspace \
  -scheme AlpenLedgerAppCI \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

Result:

- Passed.
- 37 app unit tests executed.
- 0 failures.

Notes:

- Initial run failed to compile app tests because two transactions still passed
  `"CHF"` where the domain model now expects `CurrencyCode`.
- App tests now use `.chf` and expect two-decimal formatted balances.
- The checked-in `AlpenLedgerAppCI.xcscheme` incorrectly included UI tests even
  though `project.yml` defines CI as app unit tests only. The scheme now matches
  the declared CI scope.
- App tests now include the app-model backup/restore action path used by the
  File menu and Settings controls, plus app-model rejection of a tampered backup
  bundle and Settings integrity-summary state.
- App tests now include proposal decision metadata rendering in the inbox
  inspector.
- App tests now include the Tax Studio lock/reopen action path through
  `WorkspaceAppModel`, including selected-period status updates and locked-year
  reselection without a false recomputation error.
- App tests now include the recent-workspace reopen path through
  `WorkspaceAppModel`, covering persistence across app-model relaunch.
- App tests now include the Settings data-health summary backed by the workspace
  database health report.
- App tests now include the Settings/File-menu support diagnostics export path
  through `WorkspaceAppModel`.
- App tests now include the Settings/File-menu support bundle export path
  through `WorkspaceAppModel`.
- App tests now include feature-flag parsing, explicit override handling, and
  Debug-only QA fixture command gating.
- App tests now include actionable domain-error presentation through
  `WorkspaceAppModel`: the invalid-workspace path exposes a specific title,
  localized message, recovery suggestion, alert body, and dismissal cleanup.
- App tests now include a focused offline smoke path through `WorkspaceAppModel`
  using isolated local workspace, secret-store, and defaults roots. The test
  verifies local-only privacy fallback, sample imports, local search,
  diagnostics/support export, backup validation, backup restore, and Settings
  local-only state.
- App tests now include workspace-open recovery for interrupted import jobs,
  verifying a still-started import job is marked failed with an
  `import.interrupted` diagnostic and `importJobRecovered` audit event before
  the refreshed UI state is copied.

### XML validation

Command:

```sh
xmllint --noout AlpenLedgerApp.xcodeproj/xcshareddata/xcschemes/AlpenLedgerAppCI.xcscheme
```

Result:

- Passed.

### Local-only runtime source check

Command:

```sh
scripts/verify-local-only.sh
```

Result:

- Passed.
- No networking or web runtime APIs were found in app/package Swift sources.

Notes:

- The check scans `App/AlpenLedgerApp` and
  `Packages/AlpenLedgerKit/Sources`.
- Build/vendor scripts may still use network access for dependency verification
  or vendor refresh. This check is about runtime app/package source behavior.
- This supports the "authoritative data remains local by default" gate. It does
  not by itself prove a full offline user smoke pass.
- The app now has an explicit `AppPrivacyMode.localOnly` runtime mode.
  Unsupported values such as `ALPENLEDGER_PRIVACY_MODE=cloud` resolve back to
  local-only and do not enable network runtime or cloud inference; Settings
  surfaces the local-only/cloud-disabled state.

### Offline smoke verifier

Command:

```sh
scripts/verify-offline-smoke.sh
```

Result:

- Passed.
- Ran `scripts/verify-local-only.sh`.
- Ran the focused hosted app test
  `testLocalOnlyOfflineSmokeCoversCoreWorkspaceWorkflow`.
- Verified an isolated local workspace, file secret store, and defaults suite
  can create a workspace, create/switch to a sole-proprietor entity, import
  bundled sample ledger/document fixtures, search local data, export sanitized
  diagnostics and support bundles, create/check/restore a local backup, and
  keep Settings in explicit local-only/cloud-disabled mode.
- Verified unsupported `ALPENLEDGER_PRIVACY_MODE=cloud` falls back to
  local-only during the smoke run.

### Dependency review policy verifier

Command:

```sh
scripts/verify-dependency-review.sh
```

Result:

- Passed.
- Verified `config/dependency-review.json` against
  `Packages/AlpenLedgerKit/Package.resolved`.
- Verified the only reviewed SwiftPM remote pin is `SQLCipher.swift` `4.13.0`
  at revision `7da3c29da67ef5f6dac915647087d966451f00d3`.
- Verified the main app package only uses the reviewed vendored GRDB package
  path and does not declare remote SwiftPM packages directly.
- Verified vendored dependency review notes, patch metadata, and forbidden
  vendored metadata checks.

### Fixture catalog verifier

Command:

```sh
scripts/verify-fixtures.sh
```

Result:

- Passed.
- Verified `config/fixture-catalog.json` against every file under `Fixtures/`.
- Verified fixture SHA-256 hashes, required packs, coverage-test references,
  synthetic-data declarations, app-resource registration for bundled fixtures,
  CSV/CAMT.052/CAMT.053/CAMT.054/QR-bill/PDF/text/eCH tax-certificate XML/
  expected-tax-fact format sanity, personal/business draft export-readiness JSON
  shape, customer-scale row/counterparty/currency expectations, and high-risk
  personal-data patterns for text-like fixtures.

### GRDB vendor snapshot verifier

Command:

```sh
scripts/verify-grdb-vendor.sh
```

Result:

- Passed.
- Verified the vendored GRDB snapshot matches upstream `v7.10.0` plus the
  checked-in SQLCipher patch.

Notes:

- Initial local run failed because ignored local build output under
  `Packages/Vendor/GRDB.swift/build` was included in the normalized vendor
  comparison.
- The verifier now excludes generated `.build`, `build`, `.swiftpm`, and
  `.DS_Store` entries before comparing source snapshots.

### Aggregated readiness script

Command:

```sh
RUN_UI_TESTS=full scripts/verify-readiness.sh
```

Historical full-UI result from 2026-05-29:

- Passed for deterministic local gates and full app UI automation.
- Ran CI scheme XML validation.
- Ran local-only runtime source verification.
- Ran fixture catalog verification.
- Ran schema catalog verification and offline eCH-0217 XSD validation.
- Ran 136 package tests.
- Ran 23 app CI unit tests.
- Ran the full `AlpenLedgerApp` scheme: 23 app unit tests and 7 macOS UI
  tests.

Without `RUN_UI_TESTS`, the script skips UI automation by default.
`RUN_UI_TESTS=1` keeps a faster representative native UI check covering
workspace create/reopen, Overview-to-Inbox document-link navigation, and the
Copilot `Turn Into Task` button flow.

```sh
scripts/verify-readiness.sh
```

Latest default result on 2026-05-30:

- Passed.
- Ran project structure verification for the checked-in workspace, Xcode
  project, shared CI scheme, local Swift package graph, bundle metadata,
  Xcode/XcodeGen/Swift baselines, and direct package-source policy through
  `scripts/verify-project-structure.sh`.
- Ran source style verification through `.editorconfig` and
  `scripts/verify-source-style.sh`.
- Ran release-note structure verification for
  `docs/release-notes/v0.1.0.md` through `scripts/verify-release-notes.sh`.
- Ran configuration-only release preflight through
  `scripts/verify-release-preflight.sh --allow-missing-secrets`, verifying
  release signing/notary settings, release metadata, and local release tools
  while reporting expected credential warnings.
- Ran product governance verification for locked scope, pilot canton/business
  profile, risk register, ADR metadata, and documentation-maintenance anchors
  through `scripts/verify-product-governance.sh`.
- Ran documentation alignment verification for canonical source-of-truth paths,
  required-reading order, cross-links, and core scope/trust boundaries through
  `scripts/verify-doc-alignment.sh`.
- Ran agent tool-safety verification for unrestricted file access, raw SQL,
  shell execution, provenance, and explicit confirmed-write approvals through
  `scripts/verify-agent-tool-safety.sh`.
- Ran dependency review policy verification through
  `scripts/verify-dependency-review.sh`.
- Ran vendored GRDB/SQLCipher offline-invariant verification through
  `scripts/verify-grdb-vendor.sh --offline`.
- Ran focused performance regression verification through
  `scripts/verify-performance.sh`.
- Ran 247 package tests.
- Ran offline smoke verification.
- Ran 53 app CI unit tests.
- Skipped UI automation by default.

Current UI-target build check on 2026-05-30:

- Added `testGlobalSearchFindsDocumentAndOpensPreview` for toolbar global
  search, document-result selection, and preview navigation.
- Added `testCopilotAnswerCanCreateInboxTaskFromButton` for the visible
  Copilot `Turn Into Task` button and Inbox task handoff.
- `xcodebuild build-for-testing -workspace AlpenLedger.xcworkspace -scheme
  AlpenLedgerApp -destination 'platform=macOS,arch=arm64'` passed, so the
  expanded app and UI test targets compile.
- Two focused execution attempts for the new UI test failed before test bodies
  ran because the XCTest runner could not initialize UI testing while macOS
  LocalAuthentication reported `System authentication is running`.
- The focused Copilot-task UI execution attempt later built and launched the UI
  runner, then failed before test-body execution with
  `Timed out while enabling automation mode`; result bundle:
  `/Users/nationalbank/Library/Developer/Xcode/DerivedData/AlpenLedger-eahhuzfxncrxjadynmdrhzvaekkq/Logs/Test/Test-AlpenLedgerApp-2026.05.30_10-17-39-+0200.xcresult`.

### Fresh checkout bootstrap verifier

Command:

```sh
scripts/verify-fresh-checkout.sh
```

Result:

- Passed.
- Created a disposable source copy from tracked and non-ignored untracked files.
- Requires the verified XcodeGen 2.45.2 baseline before copying or running the
  bootstrap gate, so project regeneration cannot be silently skipped.
- Regenerated `AlpenLedgerApp.xcodeproj` with `xcodegen generate`.
- Ran `scripts/verify-readiness.sh` in the disposable copy with
  `RUN_UI_TESTS=0`.
- Verified CI scheme XML validation, project structure verification, offline
  smoke verification, fixture and schema verification, performance
  verification, 247 package tests, and 53 app CI unit tests.

Notes:

- The fresh-copy verifier keeps the disposable copy path in its output for
  inspection.
- The first cold package-test run exposed missing `Package.swift` test-target
  dependencies for `ALDocumentsTests` (`ALEvidence`, `ALImports`),
  `ALStorageTests` (`ALAudit`), and `ALImportsTests` (`ALDomain`). Those
  declarations are now fixed.
- `scripts/verify-project-structure.sh` now statically compares direct
  package-test `@testable import AL...` usage with declared test-target
  dependencies, so this class of cold-build drift fails before SwiftPM
  compilation.
- UI automation remains opt-in for this verifier. Use
  `RUN_UI_TESTS=full scripts/verify-fresh-checkout.sh` when macOS automation
  permissions are available and the full UI suite should be included.

### CI workflow gate

Artifact:

```text
.github/workflows/macos-ci.yml
```

Current coverage:

- Runs on push to `main` and `codex/**`, and on pull requests.
- Selects Xcode 26.3.
- Installs XcodeGen.
- Runs `git diff --check`.
- Verifies the dependency review policy.
- Verifies the fixture catalog.
- Verifies the GRDB vendor snapshot.
- Regenerates the Xcode project and fails if the checked-in project is stale.
- Runs release preflight in configuration-only mode.
- Runs `scripts/verify-readiness.sh`, which also includes configuration-only
  release preflight for local parity.

### Release preflight

Command:

```sh
scripts/verify-release-preflight.sh --allow-missing-secrets
```

Result:

- Passed in configuration-only mode.
- Verified release build settings include hardened runtime, manual signing,
  `.app` output, archive installability, and deployment target metadata.
- Verified bundle identifier and Info.plist version/build metadata are present,
  formatted, and aligned with release build settings.
- Verified `notarytool` and `stapler` are available through `xcrun`.
- Verified local packaging/signature validation commands are available.
- Reported expected warnings for missing local Apple Developer signing and
  notary credentials.

Notes:

- Strict mode intentionally fails until `ALPENLEDGER_DEVELOPER_ID_APPLICATION`,
  `ALPENLEDGER_RELEASE_TEAM_ID`, and notary credentials are configured in a
  protected release environment.
- This is release-path hardening, not proof of a signed/notarized artifact.

### Full app UI scheme

Command:

```sh
xcodebuild test \
  -workspace AlpenLedger.xcworkspace \
  -scheme AlpenLedgerApp \
  -destination 'platform=macOS,arch=arm64'
```

Result:

- Passed.
- 23 app unit tests executed.
- 7 macOS UI tests executed.
- 0 failures.

Observed behavior:

- Document search scope and filtered empty-state controls work.
- Entity switching scopes ledger accounts and document lists, then restores the
  personal document set when switching back.
- Inspector visibility persists across app relaunch.
- Ledger and document panes keep secondary content hidden until a selection is
  made, and document-link sheet cancellation restores the prior ledger
  selection.
- Overview action deep-links to Inbox, then documents can be selected and
  previewed.
- Settings can rename a workspace and add/remove a sole proprietor entity.
- Recent-workspace relaunch flow opens the created workspace and reaches the
  workspace toolbar.

Interpretation:

- Earlier broader app-scheme runs exposed stale detail-pane navigation, entity
  switching state ambiguity under a fixed clock, document preview accessibility
  gaps, and offscreen sidebar hit-testing in some split-view states.
- Sidebar navigation now drives `WorkspaceAppModel.navigate(to:)` directly,
  entity-workspace switching persists a single active default, document preview
  has a stable accessibility marker, and UI tests can use app keyboard commands
  when sidebar rows are not hittable.
- This proves the automated app UI suite, not the complete manual smoke script
  in `docs/ui-smoke-pass-macos.md`.

## Changes Made In This Pass

- Made `MoneyFormatter` deterministic for Swiss-style money display.
- Updated app tests to use `CurrencyCode.chf`.
- Aligned `AlpenLedgerAppCI.xcscheme` with `project.yml` so CI runs app unit
  tests without accidentally launching UI tests.
- Added a local backup/restore service path:
  - `WorkspaceStorageManager.createBackup(for:at:)`
  - `WorkspaceStorageManager.restoreBackup(from:)`
  - `WorkspaceService.createBackup(for:at:)`
  - `WorkspaceService.restoreBackup(from:)`
- Added app-level backup and restore controls in the File menu and Settings
  screen. The Settings screen includes a warning that backup bundles contain the
  workspace encryption key.
- Added a user-facing backup integrity check action in the File menu and
  Settings screen. The Settings backup section shows the latest restorable,
  warning, or blocked status with issue paths.
- Added audit event types for workspace backup creation and restore.
- Added backup/restore tests covering database, blob, key, temp-directory, audit,
  recent-workspace behavior, manifest file hashes, and tampered-backup
  rejection.
- Added a realistic backup/restore drill that round-trips a multi-entity
  workspace graph including statements, transactions, documents, evidence links,
  tax facts, issues, invoice metadata, proposal decisions, filing-package state,
  raw statement blobs, and default entity-workspace state.
- Added an app CI test covering create/restore actions through
  `WorkspaceAppModel`.
- Added an app CI test covering app-model restore rejection for tampered backup
  bundles.
- Added an app CI test covering recent-workspace reopen through
  `WorkspaceAppModel` across app-model relaunch.
- Made recent-workspace rows full-row clickable in the workspace chooser.
- Updated the representative UI automation flow to activate the app after
  relaunch and after opening a recent workspace.
- Verified the representative workspace creation/recent reopen UI flow directly
  and through `RUN_UI_TESTS=1 scripts/verify-readiness.sh`.
- Replaced sidebar `NavigationLink` rows with explicit navigation buttons so
  visual selection and `WorkspaceAppModel` state stay aligned.
- Made entity-workspace switching persist exactly one active default workspace,
  even when the test/runtime clock is fixed.
- Backfilled migrated entity workspaces with a single default entity per
  workspace, preferring the natural person.
- Added stable document preview and empty-drop-zone accessibility identifiers
  used by the UI suite.
- Added a full UI mode to `scripts/verify-readiness.sh` with
  `RUN_UI_TESTS=full`.
- Verified the full `AlpenLedgerApp` scheme directly and through
  `RUN_UI_TESTS=full scripts/verify-readiness.sh`.
- Added raw-import immutability tests for bank statement CSV and document intake
  source blobs.
- Added coverage for rejecting empty journal entries in the existing balanced
  journal-entry test set.
- Added locked-period guards for statement imports and tax fact refreshes, with
  package tests covering both rejection paths.
- Added audited tax-year lock/reopen transitions in `TaxYearService`, including
  rejection of invalid filed-year reopening.
- Added Tax Studio selected-period status, lock, and reopen controls wired
  through `WorkspaceAppModel`.
- Adjusted Tax Studio refresh behavior so selecting a locked year does not
  trigger tax fact recomputation and report a false locked-period error.
- Strengthened tax-fact supersession coverage so provenance refs are preserved
  on retired facts and replacements are linked to the superseded value.
- Added a typed manual override path for tax facts with reason validation,
  locked-period protection, audit logging, and recomputation preservation.
- Added `TaxFactExplanationService` to explain tax facts through typed
  provenance refs and explicit missing-source reporting.
- Added proposal decision metadata (`decidedAt`, `decidedBy`,
  `decisionReason`) with migration support, service preservation on resync, and
  inbox inspector rendering.
- Added `AgentToolRegistry` and safety-policy tests for planned AI/tool-bus
  permissions, including read-only/proposal/draft/confirmed-write separation,
  mandatory confirmation for confirmed writes, provenance requirements, and
  unrestricted file access/raw SQL/shell exclusion.
- Added `AgentToolExecutor`, which consumes the registry before invoking tool
  handlers and rejects missing scopes, unsafe registries, missing confirmed-write
  approval, invalid approval records, stale/replayed approval input hashes, and
  tool results without provenance.
- Added `WorkspaceAgentToolService`, available from `ActiveWorkspaceSession`, to
  route concrete workspace tools through `AgentToolExecutor`:
  `finance.list_accounts`, `finance.search_transactions`,
  `finance.account_summary`, `docs.search`, `docs.get_summary`,
  `reconcile.statement_coverage`, `issues.list_open`,
  `tax.list_requirements`, `tax.preview_status`, `tax.explain_fact`,
  `tax.propose_override_reason`, `rules.accept_override`,
  `ledger.propose_mapping`, `ledger.propose_split`, `closing.propose_accrual`,
  `ledger.apply_draft_entry`, `entities.merge_counterparties`,
  `exports.generate_package`,
  `exports.finalize_package`, `exports.validate`, `issues.open_or_update`, and
  `docs.propose_match`.
- Added agent tool-workflow tests proving scope enforcement before mutation,
  scoped read-only outputs with provenance, issue creation with
  provenance/audit trail, cross-entity issue object-ref rejection,
  document-match proposal creation without confirmed
  evidence mutation, tax override-reason proposal creation without tax-fact
  mutation, missing-tax-fact rejection, confirmed tax override acceptance with
  explicit approval, confirmation rejection before mutation, ledger mapping
  proposal creation without transaction mutation, foreign-category rejection,
  ledger split proposal creation without transaction mutation, unbalanced split
  rejection, export finalization with explicit approval, export finalization
  rejection without confirmation or matching artifact hash, closing
  accrual proposal creation without posted journal entries, unbalanced accrual
  rejection, draft journal-entry posting with explicit approval, draft
  journal-entry rejection without confirmation or for locked periods, draft
  counterparty merge with explicit approval, counterparty merge rejection
  without confirmation, imported transaction counterparty persistence,
  export package generation without finalization or submission,
  missing-VAT-period package rejection, export validation with provenance and
  missing-VAT-period rejection, and sanitized success/rejection audit events for
  concrete agent tool calls.
- Added proposal related refs and approved document-match proposal flow:
  reviewer approval creates a confirmed evidence link, resolves the proposal with
  decision metadata, and writes proposal/evidence audit events. Added
  non-destructive proposal revocation so a reviewer can reverse an approved match
  by marking the evidence link revoked while preserving audit history.
- Added direct migration smoke/idempotency coverage through
  `makeAlpenLedgerDatabaseMigrator()`: empty databases create the expected
  schema, reapplying the full migrator leaves the schema unchanged, and a legacy
  v4 workspace document backfills into the current entity-scoped schema.
- Added `docs/schema-evolution.md` with append-only migration rules, required
  evidence for schema changes, data-backfill constraints, and recovery
  expectations.
- Added `WorkspaceStorage.databaseHealthReport()` and a Settings Data Health
  section. The report checks SQLite `quick_check`, foreign-key enforcement and
  violations, the expected GRDB migration ledger, required schema tables and
  reporting views, and page/freelist counts.
- Added migration `v14_global_search` with a `globalSearchRecords` metadata
  table, external-content `global_search` FTS5 table, trigger maintenance and
  backfill for documents, transactions, counterparties, and issues, plus the
  typed `GlobalSearchHit` storage API.
- Added migration `v15_agent_proposal_uncertainty_metadata` with persisted
  missing-field, reviewer-question, and manual-review metadata for agent
  proposals.
- Added `WorkspaceStorage.exportSupportDiagnostics(to:)` plus File menu and
  Settings controls for a sanitized support diagnostics JSON export. The report
  includes database health, schema table counts, and filesystem counts while
  declaring that it excludes source documents, document names, transaction text,
  workspace names, absolute paths, amounts, and encryption keys.
- Added `scripts/verify-local-only.sh` to fail the readiness gate if app/package
  Swift sources introduce network or web runtime APIs without an explicit
  privacy/provider boundary.
- Added `scripts/verify-project-structure.sh` to fail the readiness gate if the
  checked-in workspace, Xcode project, shared CI scheme, app metadata, local
  package products/test targets, direct package-source policy, or selected
  Xcode/Swift/XcodeGen baselines drift from the documented scaffold.
- Added `scripts/verify-agent-tool-safety.sh` to fail the readiness gate if
  production tool declarations allow unrestricted file access, raw SQL, or shell
  execution, or if agent-facing sources directly use filesystem, shell, or
  native file-picker APIs.
- Added `scripts/verify-readiness.sh` as a repeatable local readiness gate for
  XML validation, project structure verification, local-only source
  verification, agent tool-safety verification, dependency review policy
  verification, vendored GRDB/SQLCipher offline-invariant verification, fixture
  catalog verification, schema validation, package tests, app CI tests, and
  optional UI automation.
- Added `scripts/verify-fresh-checkout.sh` to create a disposable source copy,
  regenerate the Xcode project, and run the readiness gate from that copy.
- Hardened the macOS CI workflow so pull requests and pushes run patch hygiene,
  dependency review policy verification, fixture catalog verification, GRDB
  vendor verification, generated-project drift detection, release preflight
  configuration checks, and `scripts/verify-readiness.sh`.
- Hardened `scripts/verify-grdb-vendor.sh` so ignored local build outputs under
  the vendored GRDB tree do not create false drift failures.
- Added an offline verifier mode for `scripts/verify-grdb-vendor.sh` and wired
  it into `scripts/verify-readiness.sh`, while keeping full upstream drift
  comparison as the default vendor-release check.
- Enabled hardened runtime for the app target in `project.yml` and the
  regenerated Xcode project.
- Added `scripts/verify-release-preflight.sh` and `docs/release.md` to codify
  the Developer ID/notarization prerequisites without claiming that a signed
  artifact exists yet.
- Added `scripts/verify-release-artifact.sh` to validate the final release ZIP
  and matching checksum sidecar once a signed app has been notarized and
  stapled.
- Added `docs/product-scope.md`, `docs/risk-register.md`,
  `docs/governance.md`, and `scripts/verify-product-governance.sh` to lock
  v0.1 pilot scope, target users, Zurich 2026 personal-tax scope, the
  sole-proprietor/freelancer business profile, risk ownership, ADR hygiene, and
  documentation-maintenance expectations.
- Added typed app feature flags through `AppFeatureFlags`, runtime environment
  parsing, and `DependencyContainer` propagation. The Debug-only QA validation
  fixture command is now hidden unless `qa-validation-fixtures` is explicitly
  enabled.
- Added typed local-only privacy mode parsing through `AppPrivacyMode`, carried
  by `DependencyContainer` and surfaced in Settings as an explicit
  cloud/network-disabled runtime state.
- Added `scripts/verify-offline-smoke.sh` and
  `testLocalOnlyOfflineSmokeCoversCoreWorkspaceWorkflow` to prove core local
  workspace, import, search, diagnostics, support bundle, backup, and restore
  workflows run with isolated local-only runtime configuration.
- Added `docs/local-development.md` with local toolchain, bootstrap,
  verification, UI automation, runtime override, and backup-handling notes.
- Added ignore rules for generated Xcode build output:
  - `build/`
  - `Packages/*/build/`

## Backup/Restore Notes

- Backup packages are directory bundles with:
  - `backup.json`
  - `workspace.key`
  - `workspace/`
- Backup creation stages new bundles in a hidden sibling directory, then moves
  the complete bundle into place only after the workspace copy, key, file
  hashes, and `backup.json` are complete. Failed creation removes the staged
  artifact and leaves the final selected path absent.
- Backup manifests use format version 2 for newly created backups and include
  SHA-256 hashes and byte counts for the workspace copy and `workspace.key`.
- `workspace.key` contains the workspace master key. A backup is therefore
  sensitive material and must be protected like the live workspace.
- Users can create and restore backup bundles from the File menu and from
  Settings. They can also check backup integrity before restoring.
- `WorkspaceStorageManager.validateBackup(at:)` returns a structured integrity
  report and restore rejects blocking issues such as missing required files,
  workspace ID mismatches, unsupported manifest versions, or hash mismatches.
- Settings renders that structured integrity report as a concise user-facing
  status with blocker/warning rows and affected paths.
- Restores copy the workspace into a new local workspace root, rewrite
  `workspace.json` to that new root path, recreate `temp/`, store the restored
  master key, log a restore audit event, and update recent workspaces.
- The deterministic tests prove the storage/service path, app-model action path,
  a realistic multi-entity workspace graph restore drill, and a customer-scale
  fixture import restore drill. Dedicated native file-picker UI automation is
  still pending.

## Current Evidence Summary

Proven:

- Core package tests pass.
- App target builds through the CI unit-test scheme.
- App unit tests pass.
- CI scheme XML is valid.
- A disposable fresh source copy can regenerate the Xcode project and pass the
  default readiness gate.
- Runtime app/package Swift sources pass the local-only verifier.
- App runtime configuration defaults to explicit local-only privacy mode and
  treats unsupported cloud privacy-mode values as local-only.
- Offline smoke verification passes through a hosted app-model workflow using
  isolated local workspace, secret-store, defaults, import, search, diagnostics,
  support bundle, backup, and restore paths.
- Full app-scheme UI automation passes for workspace creation/reopen, settings,
  entity switching, document search, document preview, inspector persistence,
  and ledger/inbox/document selection flows.
- Local development and bootstrap commands are documented.
- The push/pull-request CI workflow runs the local readiness gate plus patch
  hygiene, dependency review policy verification, fixture catalog verification,
  GRDB vendor verification, generated-project drift detection, and
  release-preflight configuration checks.
- The GRDB vendor verifier passes and ignores local generated build output
  before comparing the vendored source snapshot against upstream plus patch.
- Release preflight is machine-checkable in configuration-only mode and proves
  hardened runtime, version metadata, bundle identifier, packaging prerequisites,
  archive installability, and local Apple notarization/signature tooling
  availability.
- The release artifact verifier can machine-check the signed ZIP's bundle
  metadata, Developer ID signature, hardened runtime, timestamp, Gatekeeper
  assessment, stapled ticket validation, adjacent `.sha256` sidecar, and
  checksum once a real artifact is produced.
- Feature-flag support defaults production-safe and is app-tested for
  environment parsing, explicit overrides, and QA fixture command gating.
- Raw bank statement and document imports preserve the original source bytes in
  encrypted blobs even when the source files later change.
- Failed document intake marks the import job failed, writes a
  `document.import_failed` diagnostic, removes the materialized temp source, and
  deletes the encrypted blob only when that failed import created it and no
  persisted document references it.
- Successful statement import rows and success audit events are committed
  atomically with the completed import job, so a persisted statement import is
  not later rewritten as failed by a post-commit audit error.
- Cancelled bank-statement imports can be retried by materializing the stored
  encrypted source blob, so retry/resume does not depend on the original file
  still existing outside the workspace.
- The Inbox import inspector exposes that retry path to reviewers only when the
  job failed or was cancelled, the stored source blob is available, and a
  statement account context exists.
- CAMT.052 account-report, CAMT.053 bank-statement, and CAMT.054 debit/credit
  notification imports parse synthetic Swiss ISO 20022 fixtures through the
  default import pipeline, including structured references, counterparties,
  booking/value dates, optional opening/closing balances, signed credit/debit
  amounts, multi-container coverage windows, CAMT.054 batch details, and
  `bankStatementCAMT` import-job persistence.
- VAT period reconciliation computes output tax, recoverable input tax, and net
  payable tax from mapped transactions using the synthetic Swiss VAT quarter
  fixture. Persisted VAT periods can now reconcile directly from an entity
  ledger, lock only when blocker-free, audit lock/reopen transitions, and block
  statement imports that would change a locked VAT period. VAT export now
  generates deterministic eCH-0217 v2.0.0 effective-reporting XML from the same
  reconciliation report and validates required metadata, XML structure, and
  payable tax against the report. `scripts/verify-schemas.sh` now validates
  the golden eCH-0217 fixture offline against vendored official eCH XSDs and
  proves malformed payloads are rejected. Tax Studio shows VAT period totals and
  reconciliation blockers/warnings, but full VAT period/export review workflows
  remain open.
- QR-bill document extraction detects Swiss QR-code text payloads and extracts
  structured creditor/debtor address, amount/currency, and QRR reference fields
  from the synthetic fixture. This does not yet prove native QR image decoding.
- Journal-entry construction enforces non-empty balanced debit/credit lines.
- Current period-mutating service flows reject writes to locked tax years:
  statement import transactions and computed tax fact refreshes. Statement
  imports also reject transactions that would touch a locked VAT period.
- Tax-year lock/reopen actions persist period status, write audit events, and
  update the Tax Studio app snapshot.
- Tax facts store provenance refs and preserve them across current-value
  supersession history.
- Tax facts can be marked as user-overridden with a required reason and audit
  trail; recomputation preserves the override.
- Tax facts have a typed explanation service that resolves supporting
  document/transaction refs and reports missing refs.
- Agent proposal decisions preserve who/why/when metadata for user rejections
  and system resolutions.
- Planned agent tools have typed side-effect classes and a safety policy that
  rejects unrestricted SQL/shell access and confirmed writes without explicit
  user confirmation. The executable `AgentToolExecutor` enforces the policy
  before handlers run and validates result provenance.
- Concrete workspace agent tools for account listing, account summary,
  transaction search, document search, document summary, statement coverage,
  open-issue listing, tax requirement listing, tax readiness preview, tax fact
  explanation, audit tracing, tax override-reason proposals, ledger mapping
  proposals, ledger split proposals, closing accrual proposals, approved draft
  journal-entry posting, draft export package generation, export validation,
  issue open/update, and document-match proposals now execute through
  `WorkspaceAgentToolService`,
  which uses `AgentToolExecutor`, scoped invocations, typed JSON inputs/outputs,
  bounded handler arguments, and tool-result provenance. Each concrete
  workspace agent tool invocation now writes a sanitized `agentToolExecuted` or
  `agentToolRejected` audit event with tool name, side-effect class, scopes,
  confirmation presence, result provenance refs, duration, and stable error
  code without storing raw tool inputs or output JSON. Confirmed-write audit
  payloads now include invocation and confirmation input hashes so reviewers can
  correlate an approval to the exact reviewed payload without exposing the raw
  input.
- The app-model Copilot task action now routes its review-issue write through
  the typed `issues.open_or_update` agent tool with `.issuesWrite` scope instead
  of calling `IssueService` directly. The handler bounds task text, validates
  entity/tax-year scope, and rejects scoped object/related refs that belong to
  another entity. `testCopilotAnswerCanCreateInboxTask` verifies the resulting
  issue selection plus the sanitized `agentToolExecuted` audit payload,
  `agentToolWorkflowRejectsIssueOpenForCrossEntityObjectRef` verifies the
  cross-entity rejection path, and `scripts/verify-agent-tool-safety.sh` rejects
  a regression to direct app-model issue writes in that path.
- `tax.propose_override_reason` is proposal-only: it requires an existing
  current tax fact in the requested entity/tax year, rejects locked tax years
  and missing facts, creates a `taxOverrideReview` proposal, and does not set
  `overrideReason`, change fact status, or invent tax-fact values.
- `rules.accept_override` is a confirmed write: `AgentToolExecutor` rejects it
  unless a matching explicit `AgentToolConfirmation` is present, then the
  handler validates entity/tax-year/fact scope, current fact state, open
  tax-year status, optional pending `taxOverrideReview` proposal target, and
  bounded override/approval reasons. It mutates only the approved tax-fact
  override fields, resolves the linked proposal when present, and writes
  user-attributed tax-fact/proposal audit events.
- `ledger.propose_mapping` is proposal-only: it requires an existing
  transaction/account, validates category ownership, bounded tax-code/rationale
  fields, and confidence, creates a `transactionMappingReview` proposal, and
  does not update transaction tax codes or category assignments.
- `ledger.propose_split` is proposal-only: it requires an existing transaction
  and account, validates line count, exact split totals, category ownership,
  field bounds, rationale, and confidence, creates a `transactionSplitReview`
  proposal, and does not create, update, or delete transactions.
- `closing.propose_accrual` is proposal-only: it validates entity/tax-year
  scope, open tax-year status, effective date, ledger-account ownership,
  bounded fields, line-side validity, and balanced debit/credit totals, creates
  a `closingAccrualReview` proposal with a draft journal-entry preview, and
  does not post journal entries or mutate ledger accounts.
- `ledger.apply_draft_entry` is a confirmed write: `AgentToolExecutor` rejects
  it unless a matching explicit `AgentToolConfirmation` is present, then the
  handler validates entity/tax-year scope, open period status, effective date,
  entry-number/memo/line bounds, ledger-account ownership, line-side validity,
  balanced debit/credit totals, and optional pending `closingAccrualReview`
  proposal target. It persists a posted journal entry and journal lines, records
  reviewer identity/time, resolves the linked proposal when present, and writes
  user-attributed journal-entry/proposal audit events.
- `entities.merge_counterparties` is a confirmed write: `AgentToolExecutor`
  rejects it unless a matching explicit `AgentToolConfirmation` is present,
  then the handler validates entity scope, active source/target counterparty
  records, optional pending `counterpartyMergeReview` proposal refs, and
  bounded reviewer fields. It marks the source counterparty merged into the
  target, preserves source counterparty records and imported transaction text,
  and writes user-attributed counterparty/proposal audit events.
- `exports.generate_package` is draft-artifact only: it validates export
  format and metadata bounds, entity/tax-year/VAT-period scope, provider
  artifact metadata, and blocker-free provider results, stores the generated
  artifact in the encrypted blob store, creates a `generated` filing package,
  and does not finalize, submit, or mark the package accepted. The app wires it
  to the deterministic Swiss eCH-0217 VAT XML exporter.
- `exports.finalize_package` is a confirmed write: `AgentToolExecutor` rejects
  it unless a matching explicit `AgentToolConfirmation` is present, then the
  handler validates entity/tax-year/package scope, rejects filed tax years,
  requires a generated package, verifies the reviewed snapshot hash against the
  encrypted artifact blob, marks only finalized package fields, leaves
  `submittedAt` nil, and writes a user-attributed package finalization audit
  event.
- `exports.validate` is read-only: it validates entity/tax-year/VAT-period
  scope and bounded export metadata, returns validation issues with
  provenance, is wired in the app to the deterministic Swiss eCH-0217 VAT
  export validator, and does not create filing packages or export artifacts.
- `audit.trace_object` is read-only: it validates the target object ref and
  bounded result limit, returns reverse-chronological audit event rows with
  bounded payload previews, cites the target and returned audit events, and
  does not expose unrestricted SQL or raw audit-table access.
- Document-match proposals now carry their related transaction ref and can be
  explicitly approved from the Inbox; approval creates a confirmed evidence link
  only after reviewer action. Approved matches can also be revoked from the
  Inbox; revocation marks the evidence link revoked, removes it from
  confirmed-link lookups, and writes audit events. Both flows are covered by
  service and app CI tests.
- Proposal confidence is now reviewer-visible in the Overview attention list,
  Inbox proposal rows, and the proposal inspector as high/medium/low bands with
  percentages and status tones. Low-confidence pending document-match proposals
  remove direct approval and instead route reviewers to manual Open, Reject, and
  Link Transaction actions. Concrete proposal tool outputs now include
  rationale, missing fields, a targeted reviewer question, and manual-review
  metadata; low-confidence proposals auto-fill the question when the caller does
  not provide one.
- Model-provider selection now has a domain policy boundary:
  `ModelProvider` defines the provider invocation protocol and
  `ModelProviderRegistry` declares provider descriptors with role, location,
  capability, network, off-device, and explicit-consent metadata. Requests and
  responses carry source refs and off-device status. `LocalRulesModelProvider`
  provides the concrete in-process local provider for the production
  `local.rules` descriptor, and `ModelProviderExecutor.productionLocalOnly`
  routes local requests through the registry policy before invocation. Policy
  tests prove unknown providers, missing capabilities, network/off-device
  providers in air-gapped mode, descriptor/response mismatches, and unapproved
  hybrid/external providers are rejected before or after selection as
  appropriate. Settings now surfaces the air-gapped AI privacy mode, disabled
  network/cloud model status, and the allowed local provider.
- Business expense evidence linking now covers sole-proprietor/business
  expenses: refresh opens a missing-support issue and pending requirement for an
  imported business expense, and a confirmed receipt link satisfies the
  requirement and resolves the issue.
- Workspace database health is now machine-checkable and visible in Settings:
  fresh workspaces pass quick-check, foreign-key, migration-ledger, and required
  table/view checks; missing migration ledger rows or reporting views are
  reported as blockers.
- Global search is now machine-checkable at the storage layer: documents,
  transactions, counterparties, and issues are indexed through external-content
  FTS triggers and returned as typed, workspace-scoped hits from normal
  repository writes. A larger-workspace regression now seeds more than 5,000
  searchable records and verifies bounded hits inside a one-second query budget
  when the dedicated performance gate sets
  `ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1`. Evidence refresh keeps the index
  healthy across repeated issue synchronization.
- Reporting, tax-status, import/reconciliation lookup, and volume restore
  performance are now machine-checkable at the storage layer: a larger-workspace
  regression seeds statements, transactions, evidence links, issues, tax facts,
  and a VAT period, verifies the read-only reporting views and scoped
  repository lookups inside two-second query budgets under the explicit
  performance-budget environment, and validates backup/restore counts for the
  same persisted volume. Normal full package tests retain functional coverage
  without wall-clock assertions under parallel load. A separate
  customer-scale fixture restore drill verifies a 2,500-row imported statement,
  encrypted source blob, and restored repository counts.
- Global search is now reachable from the app shell: the workspace toolbar and
  `Command-Shift-F` command open a search popover, and selected hits navigate to
  the relevant Documents, Ledger, or Inbox context. Transaction and counterparty
  navigation falls back to typed storage lookups when the current UI cache does
  not already contain the hit.
- Support diagnostics export is now machine-checkable and visible in Settings:
  `WorkspaceAppModel` writes a local sanitized diagnostics JSON report for
  support, and tests prove the report omits sensitive source content, filenames,
  transaction text, amounts, absolute paths, workspace names, and keys.
- Support bundle export is now machine-checkable and visible in Settings:
  `WorkspaceAppModel` writes a local sanitized support JSON bundle with
  diagnostics, audit event counts, actor/event/object-kind summaries, and
  bounded recent event metadata. Tests prove it omits raw audit payloads, raw
  actor IDs, raw object IDs, sensitive payload text, absolute paths, workspace
  names, source document content, transaction descriptions, amounts, and keys.
- Service-level backup/restore round trip passes for workspace metadata,
  database rows, encrypted blobs, workspace key, audit events, recent
  workspaces, manifest file hashes, and tamper rejection.
- A realistic multi-entity backup/restore drill preserves statement imports,
  transactions, documents, evidence links, issues, tax facts, invoice metadata,
  agent proposal decisions, filing-package state, raw statement blobs, and the
  single-default entity-workspace invariant.
- App-level backup/restore actions are wired to File menu and Settings controls
  and covered by app unit tests, including restore rejection for a tampered
  backup bundle and Settings integrity-summary state.
- Safe workspace deletion/reset is now explicit and local: the service layer
  requires exact workspace-name confirmation, closes the database, removes the
  workspace folder, deletes the workspace master key, and removes the recent
  workspace reference. The File menu and Settings expose the destructive action
  through a typed-confirmation alert, and app-model state is cleared after a
  successful deletion.
- Agent orchestration audit state is now persisted locally:
  `AgentRunTrace` records router intent, selected specialists, planned tools,
  unavailable tools, required scopes, context refs, model/provider metadata,
  prompt template, model input scope, off-device status, tool-call outcomes,
  and approval decisions. Migration and storage tests cover the `agentRuns`
  table, run-trace round trips, and reviewer decision metadata alongside
  existing sanitized `agentToolExecuted` / `agentToolRejected` audit events.
- App shell and design-system baseline now has focused local proof. The app
  entry point uses a SwiftUI `WindowGroup` with `RootSplitView`, menu commands,
  app alerts, modal sheets, and Help Center presentation. The workspace shell
  uses `NavigationSplitView` and `SidebarView` with typed `AppSection` groups.
  `ALDesignSystem` provides shared tokens and primitives for badges, summary
  tiles, empty states, inspector panes, document reference rows, and the
  PDF/image document preview host. `testAppShellAndDesignSystemContractsExposeNativeMacPatterns`
  covers the section contract, inspector toolbar routing, design tokens, and
  key primitive construction.
- Design-system preview/demo coverage is now compile-checked through
  `DesignSystemPreviewCatalog` and `DesignSystemDemoGallery`. The gallery
  exercises status badges, summary tiles, work-item rows, document reference
  rows, inspector panes, empty states, and document preview fallback behavior,
  and the app shell contract test locks the expected catalog IDs so component
  demo drift fails CI.
- The app now has a source-backed Copilot main screen. It renders selected
  entity/year/canton context, suggested finance/tax questions, deterministic
  answer cards for tax readiness, missing expense evidence, missing monthly
  statement extracts, VAT explanation, and draft business-export readiness, plus
  clickable `ObjectRef` source rows that deep-link into Inbox, Ledger,
  Documents, Tax Studio, and imported-statement context. Focused app tests cover
  source-backed claims and source navigation.
- Copilot answers can now be turned into explicit review tasks. The
  `Turn Into Task` action creates an open `copilotTask` issue from the grounded
  answer, preserves its source object reference, refreshes the Inbox, and selects
  the task for review without mutating ledger or tax facts. The app-model test
  verifies the resulting audited `issueOpened` event, and the UI suite includes
  the native button flow in representative mode.
- Copilot answer cards now surface typed follow-up questions when the answer
  has unresolved review work. Follow-ups carry source refs and route to Inbox,
  Ledger, or Tax Studio actions for pending tax requirements, missing facts,
  unsupported expenses, missing statement coverage, VAT issues, and blocked
  business-export readiness. `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext`
  covers the current source-backed follow-up IDs, provenance, and action routing.
- Statement-import defaults are now explicit in Settings: the app persists a
  preferred import account per workspace, shows the current default and
  available accounts, uses the saved account before falling back to the selected
  ledger account or first available account for statement imports and retry
  imports, and app tests verify persistence, import routing, and reopen
  behavior.
- Demo workspace creation is now a production path from the workspace chooser
  and File menu. The app creates a local encrypted workspace, adds a demo
  sole-proprietor entity, imports bundled sample statement/document fixtures
  through the normal import services, selects the statement account for visible
  transactions, registers the workspace in recents, and app tests verify the
  imported data, issue generation, and search.
- First-run onboarding and baseline in-app help are now native app surfaces.
  The empty workspace chooser renders a first-run checklist, and a Help Center
  sheet is available from the chooser, Settings, and Help menu with local-first
  setup, evidence review, tax readiness, locked-period, backup, and sanitized
  support guidance. App tests verify the guide state without requiring a
  workspace.
- Release packaging is now repeatable through `scripts/package-release.sh`.
  The script packages a prepared `AlpenLedgerApp.app` into a versioned ZIP,
  writes a SHA-256 sidecar, checks bundle metadata, and runs final artifact
  verification against the staged ZIP/checksum before publishing them to the
  release directory. `scripts/verify-release-packaging.sh` covers the packaging
  dry run, final artifact verifier syntax, checksum-sidecar requirements,
  staged-artifact publishing, and release documentation references in the
  default readiness gate without requiring Apple Developer credentials.
- Agent read-only tool argument validation now rejects missing entity scope for
  finance account listing, transaction search, statement coverage, and issue
  lookups before returning empty results, preventing non-existent context refs
  from being used as answer provenance. Document search validates provided
  entity scope and limits unscoped searches to unassigned intake documents.
  Document summaries reject entity-assigned documents unless the requested
  entity matches the document, while unassigned intake documents remain
  available for triage.
- Audit tracing now resolves target refs through typed repositories before
  reading event payload previews. Entity-owned objects require the matching
  `entityId`, unscoped calls are limited to workspace or unassigned intake
  objects, and evidence-link/audit-event refs are scoped through their
  underlying source object refs.
- Confirmed document-to-transaction evidence links now enforce entity
  boundaries outside the agent-tool path as well. Manual links and
  document-match proposal approval reject documents assigned to another entity,
  and confirmation scopes unassigned intake documents to the transaction
  account's entity so they are no longer exposed as unassigned documents.
- Document retention now has a non-destructive archive path. Archived documents
  keep their encrypted source blob and audit metadata, are removed from active
  document lists, document/global search, and agent document search/summary
  tools, and cannot be archived while they are confirmed evidence, satisfied
  requirement support, or current tax-fact provenance. Re-importing the same
  source restores the archived document instead of creating duplicate evidence.
  Documents review now also exposes an Archived scope plus archive/restore
  inspector actions; explicit restore records reviewer rationale and keeps
  archived documents un-linkable until restored.
- Filing-package review now separates prepared artifacts from filed returns in
  Tax Studio. The app loads persisted packages for the selected entity/year,
  shows generated/finalized package rows as "Not Filed", keeps the package
  inspector explicit about `submittedAt`, and only labels submitted/accepted
  states as external filing states. The app-model test
  `testTaxStudioSnapshotSeparatesPreparedFilingPackagesFromFiledReturns`
  covers the persisted package row and inspector evidence.
- Support documentation now has an operational baseline in `docs/support.md`
  covering private intake, severity, sanitized diagnostics/support bundles,
  privacy exclusions, backup safety, triage runbooks, and escalation hand-off.
  `scripts/verify-support-docs.sh` verifies the support anchors and keeps the
  runbook wired into the default readiness gate.
- Source-style verification now works in disposable source copies that do not
  include `.git`. `scripts/verify-source-style.sh` uses `git ls-files` in a
  working tree and falls back to a repository-shaped filesystem scan for
  fresh-checkout copies, avoiding false style coverage during bootstrap
  verification. It also rejects Bash 4+ shell features in release scripts so
  local and CI gates remain compatible with macOS system Bash 3.2.
- Project-structure verification now checks package-test direct
  `@testable import AL...` usage against `Package.swift` test-target
  dependencies, covering cold-build-only dependency drift.
- Migration fixture breadth improved with
  `databaseMigrationsUpgradeLegacyV14AgentProposalUncertaintyState`, which
  installs a synthetic pre-v15 agent-proposal schema, migrates it to current,
  and verifies pending proposal metadata survives while `missingFields`,
  `question`, and `requiresManualReview` are added with safe defaults.
- Error/help copy review now has an explicit release baseline in
  `docs/copy-review.md`. `domainErrorCopyIsSpecificAndActionableForReleaseReview`
  covers representative `DomainError` cases for specific titles, localized
  descriptions, and actionable recovery suggestions, while
  `scripts/verify-copy-review.sh` keeps the copy-review document, release-note
  English-first limitation, checklist evidence, and focused copy test in the
  default readiness gate.
- Localization framework now has an English-first baseline:
  `docs/localization.md`, `config/localization-catalog.json`,
  `App/AlpenLedgerApp/Resources/en.lproj/Localizable.strings`,
  `Package.swift` `defaultLocalization: "en"`, and `LocalizationPolicy` define
  the default language, planned German/French boundaries, glossary keys, and
  release-claim rules. `scripts/verify-localization.sh` checks those anchors
  and runs `localizationPolicyKeepsPilotLanguageClaimsConservative` in the
  default readiness gate.
- Documentation alignment now has a verifier-backed source-of-truth map.
  `docs/governance.md` declares the canonical vision, architecture,
  architecture-pass, agent, build-plan, prompt, product-scope, and checklist
  docs; `docs/internal/prompt.md` uses canonical `docs/` paths in its required
  reading order; `agents.md` cross-links point at checked-in `docs/` files; and
  `scripts/verify-doc-alignment.sh` rejects stale root-level doc references
  while checking local-first, Zurich 2026, pilot-business, export-first, and
  typed-tool trust-boundary anchors in the default readiness gate.
- Backup and restore panel handling now has a testable boundary:
  `BackupPanelClient` preserves live `NSSavePanel`/`NSOpenPanel` selection in
  production while allowing deterministic local URL selections in debug
  automation. `testBackupPanelActionsUseConfiguredSelectionsThroughWorkspaceAppModel`
  covers create/check/restore through the panel-driven app-model methods, and
  `testRuntimeConfigurationCanProvideDeterministicBackupPanelSelectionsForUITests`
  verifies the UI-test environment wiring.
- User-selected import source reads now go through a security-scoped access
  boundary. `SecurityScopedResourceAccess.live` starts access with macOS'
  security-scoped resource API and stops it when the import read finishes;
  `documentServiceBracketsImportedSourceWithSecurityScopedAccess` and
  `importJobServiceBracketsStatementSourceWithSecurityScopedAccess` verify
  document intake and bank-statement import use that boundary.
- Document-vault review now covers the full local intake loop: drag-and-drop
  and panel-selected document imports share the same service path, PDF/image
  previews use materialized encrypted blobs, extracted text and document type
  persist on document rows, and the inspector can correct type/date metadata
  through `DocumentService.reviewDocumentMetadata`. The review operation only
  mutates active documents, refreshes search indexing, and writes a
  `documentMetadataReviewed` audit event. Covered by
  `documentServiceReviewsMetadataWithAuditAndSearchRefresh`,
  `documentServiceRejectsMetadataReviewForArchivedDocument`, and
  `testDocumentMetadataReviewUpdatesVaultAndAuditTrail`.
- Workspace lifecycle now has a non-destructive close path. The Workspace menu
  exposes `Close Workspace` with `Command-Shift-W`, and
  `WorkspaceAppModel.closeCurrentWorkspace` clears the active session,
  selections, search state, and workspace-specific transient UI without
  deleting the workspace or removing its recent reference. Covered by
  `testCloseWorkspaceClearsSessionStateWithoutRemovingRecentReference`.
- Account opening balances now have a persisted account-level baseline through
  `FinancialAccount.openingBalanceMinor` / `openingBalanceDate` and migration
  `v21_account_opening_balances`. Ledger/app summaries and agent account
  summaries compute balances from imported running balances when available, or
  from opening balances plus transactions when running balances are unavailable.
  Covered by focused domain, migration, agent-tool, and app-summary tests.
- CSV bank-statement import now has a versioned `1.2.0` mapping layer with
  built-in canonical AlpenLedger, generic Swiss, and PostFinance-style presets.
  The importer recognizes mapped headers, semicolon/tab-delimited exports,
  separate debit/credit columns, Swiss date formats, and comma/dot/apostrophe
  amount conventions while retaining row-level diagnostics for malformed rows.
  Covered by focused CSV importer, edge-case, and importer fixture harness tests.
- Document intake no longer makes weak extraction metadata look definitive.
  `DocumentExtractionPipeline.detectMetadata` returns confidence and a reason;
  `DocumentService` stores filename-only or unknown detections as proposed
  metadata and records a `document.low_confidence_metadata` import warning,
  while text/XML-backed detections remain confirmed. OCR-less imports do not
  populate the legacy `document_search` FTS index, preserving database health
  while global search still covers filenames. Covered by focused pipeline,
  document-service, and offline smoke tests.
- Opt-in UI automation now has a fast local preflight. The representative UI
  suite still cannot execute on this runner because
  `tell application "System Events" to get UI elements enabled` returns
  `false`, but `RUN_UI_TESTS=1 scripts/verify-readiness.sh` now stops at
  `scripts/verify-ui-automation-preflight.sh` with a direct Accessibility
  remediation instead of spending minutes on XCTest activation timeouts.
  The default non-UI readiness gate still passes after the preflight wiring.
- UI smoke evidence is now machine-checkable for release candidates.
  `scripts/verify-ui-smoke-evidence.sh` validates the documented
  `docs/release-evidence/ui-smoke-v0.1.0.json` schema for full UI automation,
  default and Reduce Motion manual passes, the three target window sizes,
  archived evidence references, true exit criteria, and empty blockers. Default
  readiness runs it with `--allow-missing-evidence`; strict release-candidate
  use remains open until the evidence file is captured on a permitted release
  machine.
  The strict verifier now rejects placeholder refs, absolute paths, URLs,
  missing archived refs, and refs that point back to the manifest instead of
  supporting evidence.
- Final release evidence is now machine-checkable as a manifest.
  `scripts/verify-release-evidence.sh` validates the documented
  `docs/release-evidence/release-v0.1.0.json` schema for version/build, release
  git revision, default readiness, fresh-checkout verification, full UI
  readiness, UI smoke evidence, strict release notes, support/copy/localization
  gates, strict release preflight, package creation, final artifact
  verification, notarization/stapling flags, checksum digest, and empty
  blockers. Default readiness runs it with `--allow-missing-evidence`; strict
  release-candidate use remains open until a signed/notarized artifact and
  archived command evidence exist.
  The strict verifier now checks archived refs exist under
  `docs/release-evidence/`, rejects placeholder manifest commands, and verifies
  that `artifact.zipPath`, `artifact.checksumPath`, and `artifact.sha256` agree
  with the actual release-machine ZIP and checksum sidecar.

Not proven:

- Full manual UI smoke pass from `docs/ui-smoke-pass-macos.md`.
- Current full UI automation execution after the global-search and Copilot-task
  UI test additions. The expanded UI target builds, but local execution was
  blocked before test bodies ran by the macOS automation-mode state described
  above.
- Clean-machine bootstrap without cached dependencies/toolchain setup. The
  disposable fresh-checkout verifier now passes with the local SwiftPM cache
  available, but this is not a no-cache clean-machine proof.
- Signed/notarized release artifacts.
  The current release preflight still needs strict-mode evidence with real
  Developer ID and notary credentials, followed by
  `scripts/verify-release-artifact.sh` evidence for the signed, notarized,
  stapled ZIP.
- Native backup/restore file-picker interaction. The Settings UI test
  `testSettingsBackupCheckAndRestoreFlowUsesPanelSelection` is present, but
  this machine timed out while enabling macOS automation mode before UI test
  bodies ran; run it or the full UI suite on a permitted release machine.
- Full filing/period-close workflow beyond lock/reopen basics.
- Free-form chat/copilot flows and concrete model-provider integrations beyond
  the current source-backed Copilot screen, local rules provider, provider
  executor, orchestration trace, and issue/proposal, approved/revoked
  document-match, tax override, counterparty-merge, journal-posting, and
  export-finalization workflows.
- Full performance profiling on representative release hardware, including
  import throughput and UI interaction timing beyond the storage-level
  larger-workspace regressions.
- Full completion of `docs/checklist.md`.

## Next Highest-Value Work

1. Broaden UI automation and manual checks to the full
   `docs/ui-smoke-pass-macos.md` coverage, including window-size and Reduce
   Motion passes.
2. Continue closing unchecked global release gates in `docs/checklist.md`,
   starting with fuller AI/copilot UI workflows, fixture/migration breadth, and
   release signing.
