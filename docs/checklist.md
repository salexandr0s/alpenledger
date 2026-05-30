# checklist.md — AlpenLedger build checklist

Use this file as the operational build checklist for AlpenLedger.

## How to use

- Mark `[x]` only when the item is **implemented, tested, documented, and reviewable**.
- Leave `[ ]` if it is not done.
- If something is partially done, keep it unchecked and add a note under the relevant section.
- Add short evidence notes, file paths, PR links, or commit references under sections as work completes.
- Do not treat prototypes, mocks, or placeholder TODOs as done.

## Global release gates

- [x] The app builds cleanly from a fresh checkout.
  - 2026-05-30 evidence: `scripts/verify-fresh-checkout.sh` creates a
    disposable source copy from tracked and non-ignored untracked files,
    requires the verified XcodeGen 2.45.2 baseline, regenerates
    `AlpenLedgerApp.xcodeproj` with `xcodegen generate`, and passes the default
    readiness gate with XML validation, offline smoke verification, fixture and
    schema verification, performance verification, 247 package tests, and 53
    app CI unit tests. The fresh-copy run exposed and now guards against cold
    package test-target dependency drift in `ALDocumentsTests`, `ALStorageTests`,
    and `ALImportsTests`. Historical full UI automation passed on 2026-05-29;
    current full-scheme `build-for-testing` also passes after adding global
    search UI coverage. The latest focused UI execution attempt on 2026-05-30
    built the UI runner but was blocked before test bodies ran by macOS
    automation mode timing out while enabling automation.
- [x] The app can run fully offline in local-only mode.
  - 2026-05-30 evidence: `scripts/verify-offline-smoke.sh` runs the
    `scripts/verify-local-only.sh` runtime source check and the focused
    `testLocalOnlyOfflineSmokeCoversCoreWorkspaceWorkflow` app test. The smoke
    test uses isolated local workspace, secret-store, and defaults roots,
    verifies unsupported `ALPENLEDGER_PRIVACY_MODE=cloud` resolves to
    local-only, creates and switches to a local sole-proprietor workspace,
    imports bundled sample bank/document fixtures, searches local data, exports
    sanitized diagnostics and support bundles, creates/checks/restores a local
    backup, and verifies Settings surfaces the local-only/cloud-disabled state.
    `scripts/verify-readiness.sh` includes this offline smoke gate.
- [x] Authoritative data remains local by default.
  - 2026-05-29 evidence: runtime app/package Swift sources pass
    `scripts/verify-local-only.sh`, with no networking or web runtime APIs in
    `App/AlpenLedgerApp` or `Packages/AlpenLedgerKit/Sources`. Workspaces,
    documents, SQLCipher databases, keys, and backup bundles are local by
    default.
- [x] All authoritative AI writes require explicit approval; low-risk agent writes are scoped and audited.
  - 2026-05-29 evidence: `AgentToolRegistry.productionDefaults`
    classifies read-only, proposal, draft-artifact, issue-update, and
    confirmed-write tools. Confirmed-write tools are required to declare
    explicit user confirmation, and `AgentToolExecutor` rejects confirmed-write
    invocations unless they include a matching explicit approval. 2026-05-30
    hardening: `AgentToolConfirmation` now carries an `approvedInputHash`, so
    approval is bound to the exact JSON payload reviewed for that tool rather
    than only to the tool name. The executor rejects stale or replayed
    confirmations before any handler can mutate state, and agent-tool audit
    events record the invocation and confirmation hashes without storing raw
    inputs.
    `WorkspaceAgentToolService` now routes concrete issue/proposal workflows
    through the executor: `issues.open_or_update` writes issue state only with
    `.issuesWrite` scope after bounding fingerprint/summary text and validating
    entity/tax-year scope plus scoped object/related refs,
    `ledger.propose_split` and
    `tax.propose_override_reason` create review proposals without changing
    transactions or tax facts, `closing.propose_accrual` creates a draft-entry
    review proposal without posting journal entries, `ledger.apply_draft_entry`
    posts a reviewed balanced journal entry only with matching explicit
    approval, `exports.generate_package`
    creates a non-finalized filing package artifact without submission,
    `exports.finalize_package` marks a generated filing package finalized only
    with matching explicit approval and artifact hash evidence,
    `entities.merge_counterparties` marks duplicate counterparty identities
    merged only with matching explicit approval while preserving source
    counterparty records and imported transaction text,
    `rules.accept_override` applies tax-fact override reasons only with a
    matching explicit approval and audit trail, and
    `docs.propose_match` creates a review proposal with same-entity document
    and transaction refs without creating a confirmed evidence link. The inbox
    approval path can then turn that proposal into a
    confirmed evidence link only after an explicit reviewer action, and reviewer
    revocation marks the link revoked instead of deleting evidence. 2026-05-30
    copilot-state hardening: `AgentPendingApproval` persists confirmed-write
    requests with tool name, reviewed input hash, required scopes, target refs,
    pending/approved/rejected/expired status, and reviewer decision metadata; it
    can only produce an `AgentToolConfirmation` after approval. 2026-05-30
    Copilot task creation now routes its review-issue write through
    `issues.open_or_update` on `WorkspaceAgentToolService` instead of directly
    calling `IssueService`, so the app-model path also gets scope validation,
    provenance, and a sanitized `agentToolExecuted` audit event. Covered by
    `agentToolWorkflowRejectsIssueOpenForCrossEntityObjectRef`,
    `testCopilotAnswerCanCreateInboxTask`, `AgentToolPolicy` tests, and
    `scripts/verify-agent-tool-safety.sh`, which rejects direct
    app-model issue writes from the Copilot path.
- [x] Raw imports remain immutable.
  - 2026-05-29 evidence:
    `statementImportPreservesRawSourceBlobAfterSourceFileChanges` and
    `documentImportPreservesRawSourceBlobAfterSourceFileChanges` verify that
    imported CSV and document source bytes remain readable from encrypted blobs
    after the original files change on disk.
  - 2026-05-30 hardening:
    `documentImportFailureRemovesNewBlobAndTempMaterialization` verifies failed
    document intake marks the import job failed, records a
    `document.import_failed` diagnostic, removes the materialized temp source,
    and deletes the encrypted blob only when that failed import created it and
    no persisted document references it.
- [x] Major features have migration coverage.
  - 2026-05-30 evidence: migration coverage now verifies current
    empty-database schema creation, full migration idempotency, and a legacy
    v4-to-current data backfill for entity-scoped documents, entity workspaces,
    agent proposal metadata, agent uncertainty metadata, and transaction
    counterparty identity links. It also verifies persisted transaction VAT
    mapping, VAT period table/index creation, counterparty table/index creation,
    agent conversation/message/pending-approval table/index creation,
    read-only reporting view creation through migration `v13_reporting_views`,
    a synthetic legacy v12-to-current reporting-view upgrade where existing
    statement coverage, cashflow, spending, missing-evidence, tax-fact,
    unmatched-transaction, and VAT-period data is exposed through the new
    read-only views after migration, global-search FTS creation through
    migration `v14_global_search`, document archive-state backfill through
    migration `v20_document_archive_state`, a
    synthetic legacy v13-to-current global-search upgrade where existing
    documents, transactions, counterparties, and issues are backfilled into the
    new search index and remain searchable after migration, a synthetic legacy
    v9-to-current filing-package upgrade where
    `v10_filing_package_finalization` adds finalization metadata without
    losing generated package state or locked VAT-period evidence, and a
    synthetic legacy v10-to-current accounting upgrade where
    `v11_journal_entries` adds journal-entry and journal-line posting tables
    without losing ledger accounts, transactions, VAT period state, filing
    package metadata, or computed tax facts. It also verifies a synthetic
    legacy v5-to-current proposal metadata upgrade where v6/v7/v15 add
    decision, related-ref, and uncertainty fields to an existing pending
    proposal, the row remains readable through the production repository, and
    the migrated repository can update the new review metadata. It also
    verifies a synthetic legacy v14-to-current proposal upgrade where
    `v15_agent_proposal_uncertainty_metadata` adds default uncertainty metadata
    without losing pending proposal evidence, related refs, confidence, or
    decision fields. It also verifies a synthetic legacy v15-to-current import
    diagnostics upgrade where `v16_import_diagnostics` adds the diagnostics
    table and indexes, accepts diagnostics for existing import jobs through the
    production repository, preserves foreign-key integrity, and cascades
    diagnostic cleanup with deleted import jobs. It also verifies a synthetic
    legacy v17-to-current upgrade
    where `v18_import_job_source_tracking` adds source blob/fingerprint columns
    and indexes to existing import jobs while `v19_agent_run_trace` creates
    agent-run trace storage without losing existing conversations, messages, or
    pending approvals. `workspaceStorageManagerRestoresDatabaseSnapshotWhenMigrationFails`
    covers safe migration rollback for a legacy workspace missing a later
    migration.
- [x] Major features have realistic sample fixtures.
  - 2026-05-30 partial evidence: `config/fixture-catalog.json` now records the
    current CSV bank-statement, single and multi-container CAMT.052/CAMT.053
    bank statements, CAMT.054 single and batched debit/credit notifications,
    customer-scale bank-statement import, QR-bill, PDF receipt, Swiss VAT
    quarter reconciliation, eCH-0196/eCH-0248/eCH-0275 import detection,
    eCH-0217 VAT export, Zurich 2026 personal-tax certificate and draft export,
    and Zurich 2026 sole-proprietor business-tax draft export fixture packs
    with stable hashes, synthetic-data declarations, purpose, and test coverage
    references.
    `scripts/verify-fixtures.sh` verifies fixture coverage, format sanity,
    app-resource registration, customer-scale row/counterparty/currency
    expectations, eCH tax-certificate XML markers, expected tax facts, draft
    personal/business export-readiness fixtures, and high-risk personal-data
    patterns.
- [x] User-facing errors are understandable and actionable.
  - 2026-05-30 evidence: `DomainError` now exposes a short
    `userFacingTitle` and `recoverySuggestion` for domain failures,
    `WorkspaceAppModel` stores alert title/message/recovery fields separately,
    and the root SwiftUI alert shows the actionable recovery text instead of a
    generic "Error" dialog. `testDomainErrorsProduceActionableAlertPresentation`
    verifies the app-model path for an invalid workspace name, including
    dismissal cleanup. `scripts/verify-readiness.sh` now passes with 247 package
    tests and 53 app CI unit tests. The last full UI readiness pass covered 23
    full-scheme app unit tests and 7 UI tests.
- [x] Backup and restore work on realistic workspaces.
  - 2026-05-29 evidence: storage/service backup and restore now round-trip a
    workspace database, encrypted blobs, workspace master key, audit events,
    temp directory exclusion, recent-workspace registration, manifest file
    hashes, and tamper rejection in package tests.
    `workspaceBackupRestorePreservesRealisticWorkspaceGraph` covers a
    multi-entity workspace graph with statements, transactions, documents,
    evidence links, issues, tax facts, invoice metadata, proposal decisions,
    filing-package state, raw statement blobs, and the single-default
    entity-workspace invariant. `customerScaleStatementImportSurvivesBackupRestoreDrill`
    imports the cataloged 2,500-row customer-scale CSV fixture, validates the
    backup bundle, restores it into a new workspace root, and verifies the
    restored import job, source blob, statement, 2,500 transactions, 80
    counterparties, audit event, and recent-workspace registration. File menu
    and Settings controls are wired and app-tested. 2026-05-30 hardening:
    `BackupPanelClient` keeps live `NSSavePanel`/`NSOpenPanel` behavior for
    production while allowing deterministic local URL selections in debug UI
    automation. `testBackupPanelActionsUseConfiguredSelectionsThroughWorkspaceAppModel`
    verifies `createBackupFromPanel`, `validateBackupFromPanel`, and
    `restoreBackupFromPanel` through the app-model path, and
    `testSettingsBackupCheckAndRestoreFlowUsesPanelSelection` covers the
    Settings UI flow when macOS automation mode is available. Dedicated native
    file-picker interaction and full UI automation remain pending release
    evidence.
- [ ] Release artifacts can be signed/notarized.
  - 2026-05-30 partial evidence: the app target enables hardened runtime in
    `project.yml`, and `scripts/verify-release-preflight.sh` verifies release
    configuration, packaging prerequisites, version metadata,
    `notarytool`/`stapler` availability, and required Developer ID/notary
    environment. `scripts/verify-release-artifact.sh` now validates a final
    release ZIP after signing/notarization/stapling and records bundle metadata
    plus an adjacent `.sha256` sidecar whose filename and digest must match the
    ZIP. CI and the default readiness gate run the preflight in
    configuration-only mode with `--allow-missing-secrets`. This remains open
    until strict preflight and artifact verification pass with real Apple
    Developer credentials and a signed, notarized, stapled artifact is archived
    as release evidence.
  - 2026-05-30 release-evidence hardening:
    `scripts/verify-release-evidence.sh` now defines a strict final manifest
    for release-candidate proof, tying default readiness, fresh-checkout
    verification, full UI readiness, UI smoke evidence, strict release notes,
    support/copy/localization checks, strict preflight, packaging, and final
    artifact verification to the current version/build and final checksum.
    Strict UI and release evidence now rejects placeholder refs, absolute paths,
    URLs, missing archived refs, manifest self-references, and final artifact
    paths whose ZIP/checksum files do not exist or whose SHA-256 data does not
    match.

---

## 0. Product governance and scope

- [x] Lock the v1 product thesis and target user profiles.
  - 2026-05-30 evidence: `docs/product-scope.md` locks the v0.1 pilot
    thesis as a local-first macOS Swiss finance workspace with deterministic
    ledger/evidence/tax truth, review-first AI assistance, and explicit target
    users for natural persons, sole proprietors/freelancers, and fiduciary
    reviewers. `scripts/verify-product-governance.sh` verifies the required
    scope anchors.
- [x] Lock the pilot canton for personal tax.
  - 2026-05-30 evidence: `docs/product-scope.md` locks Zurich as the v0.1
    personal-tax pilot canton for tax year 2026 and links that scope to the
    Zurich adapter, rule-pack catalog, and synthetic fixture evidence.
- [x] Lock the pilot business profile for business/VAT workflows.
  - 2026-05-30 evidence: `docs/product-scope.md` locks the v0.1 business
    pilot profile to a Swiss sole proprietor / freelancer service business
    with CHF bank/card activity, receipt/invoice evidence, statement coverage,
    VAT readiness, and year-end diagnostics while leaving payroll-heavy,
    inventory, multi-currency, consolidated, and broad GmbH/AG filing coverage
    out of scope.
- [x] Create and maintain architectural decision records (ADRs).
  - 2026-05-30 evidence: `docs/adr/` contains accepted ADRs for local-core
    module boundaries, SQLite/SQLCipher persistence, and entity workspace
    scoping. `docs/governance.md` defines when ADRs must be added or updated,
    and `scripts/verify-product-governance.sh` verifies ADR status, decision,
    and consequence sections.
- [x] Create a risk register for legal, tax, security, and data-integrity risks.
  - 2026-05-30 evidence: `docs/risk-register.md` tracks release-impacting
    legal, tax, security, data-integrity, AI-safety, release, and UI-quality
    risks with mitigations, evidence, and open/mitigated status. The product
    governance verifier checks required categories and risk states.
- [x] Define release naming/versioning strategy.
  - 2026-05-30 evidence: `docs/release.md` defines release names as
    `v<CFBundleShortVersionString>`, requires `MAJOR.MINOR.PATCH` app marketing
    versions, treats `CFBundleVersion` as the build number, and
    `scripts/verify-release-preflight.sh` enforces version/build metadata in
    `App/AlpenLedgerApp/Info.plist`.
- [x] Define sample-data anonymization and fixture governance.
  - 2026-05-30 evidence: `docs/fixture-governance.md` defines fixture catalog,
    synthetic-data, hash-review, app-resource, and golden-output rules.
    `config/fixture-catalog.json` records all checked-in `Fixtures/` files, and
    `scripts/verify-fixtures.sh` fails on unregistered fixture files, hash
    drift, missing coverage references, missing required packs, app-resource
    drift, invalid expected-fact JSON, and high-risk personal-data patterns.
- [x] Define documentation maintenance rules.
  - 2026-05-30 evidence: `docs/governance.md` defines source-of-truth
    ownership, checklist evidence rules, readiness-audit updates, ADR update
    triggers, risk-register maintenance, release-note draft rules, and
    verifier-first release gate expectations. The product governance verifier
    is included in `scripts/verify-readiness.sh`.
- [x] Keep `docs/vision.md`, `docs/architecture.md`, `docs/architecture-pass-v1.md`, `agents.md`, `docs/buildplan.md`, `docs/internal/prompt.md`, and `docs/checklist.md` aligned.
  - 2026-05-30 evidence: `docs/governance.md` now declares the canonical
    source-of-truth map for the vision, architecture, architecture pass, agent
    design, build plan, build prompt, product scope, and checklist docs.
    `docs/internal/prompt.md` uses canonical `docs/` paths in its required
    reading order, `agents.md` cross-links point at checked-in `docs/` files,
    and `scripts/verify-doc-alignment.sh` checks canonical paths, source-of-truth
    anchors, prompt precedence, stale root-link rejection, and the core
    local-first/Zurich/pilot-business/export-first/typed-tool boundaries. The
    verifier is included in `scripts/verify-readiness.sh`.

---

## 1. Repository, toolchain, and project setup

- [x] Create the Xcode project / workspace.
  - 2026-05-30 evidence: `AlpenLedger.xcworkspace`,
    `AlpenLedgerApp.xcodeproj`, `project.yml`, the app target, app unit-test
    target, UI-test target, and `AlpenLedgerAppCI` shared scheme are checked in.
    `scripts/verify-project-structure.sh` verifies those artifacts and validates
    the CI scheme XML.
- [x] Pin the scaffold to the current stable Xcode/Swift baseline and current stable third-party package versions.
  - 2026-05-30 evidence: `project.yml` pins XcodeGen `2.45.2`,
    Xcode `26.3.0`, macOS deployment target `15.6`, and hardened runtime for
    the app target. `Packages/AlpenLedgerKit/Package.swift` pins
    `swift-tools-version: 6.2`, macOS package platform `v15`, and the reviewed
    local GRDB vendor package. `scripts/verify-project-structure.sh` verifies
    the selected local Xcode `26.3` build `17C529`, Swift `6.2.4`, XcodeGen
    `2.45.2`, bundle version metadata, and direct package-source policy.
- [x] Create Swift Package Manager internal package boundaries.
  - 2026-05-30 evidence: `Packages/AlpenLedgerKit/Package.swift` exposes
    internal package products for domain, audit, storage, workspace, imports,
    ledger, documents, evidence, tax core, Swiss tax adapter, design system, and
    feature surfaces. The project-structure verifier checks every expected
    product and test target.
- [x] Set a consistent module/dependency graph.
  - 2026-05-30 evidence: `Package.swift` keeps `ALDomain` dependency-free,
    routes storage through `ALStorage`, UI through `ALFeatures`, and app target
    dependencies through local package products. `scripts/verify-project-structure.sh`
    verifies the expected module surface, rejects direct remote package URLs
    in the main package, and checks package-test `@testable import AL...` usage
    against declared test-target dependencies.
- [x] Add build scripts and bootstrap instructions.
  - 2026-05-29 evidence: added `scripts/verify-readiness.sh` for XML
    validation, source style verification, release-note structure verification,
    local-only source verification, dependency review policy verification,
    vendored GRDB/SQLCipher offline-invariant verification, fixture catalog
    verification, schema validation, package tests, app CI unit tests, and
    opt-in UI automation.
    The opt-in full UI mode now passes through
    `RUN_UI_TESTS=full scripts/verify-readiness.sh`. Added
    `scripts/verify-fresh-checkout.sh` for disposable checkout bootstrap
    verification. Added `docs/local-development.md` with toolchain, bootstrap,
    verification, UI automation, runtime environment, and backup-handling notes.
- [x] Add linting and formatting rules.
  - 2026-05-30 evidence: `.editorconfig` defines repository formatting rules,
    and `scripts/verify-source-style.sh` verifies owned app/package, docs,
    script, config, and workflow text files for LF line endings, final
    newlines, trailing whitespace, unresolved merge-conflict markers, leading
    tabs in hand-edited source/docs, executable shell scripts, shell syntax, and
    Bash 3.2 compatibility for macOS release runners.
    The verifier is included in `scripts/verify-readiness.sh`.
- [x] Add CI for build, test, and static checks.
  - 2026-05-30 evidence: `.github/workflows/macos-ci.yml` runs on push and pull
    request, selects Xcode 26.3, installs XcodeGen, checks patch whitespace with
    `git diff --check`, verifies the dependency review policy, verifies the
    fixture catalog, verifies the GRDB vendor snapshot, regenerates the Xcode
    project and fails on project drift, runs release preflight in
    configuration-only mode, and executes `scripts/verify-readiness.sh`, which
    includes source style verification and the same configuration-only release
    preflight for local parity.
- [x] Add feature-flag support.
  - 2026-05-30 evidence: `AppFeatureFlags` parses
    `ALPENLEDGER_FEATURE_FLAGS` and
    `ALPENLEDGER_ENABLE_QA_VALIDATION_FIXTURES`, `DependencyContainer` carries
    flags into the app model, and the debug-only QA fixture import command is
    hidden unless `qa-validation-fixtures` is explicitly enabled. Covered by
    `testFeatureFlagsDefaultToProductionSafe`,
    `testFeatureFlagsParseEnvironmentAndExplicitOverrides`, and
    `testQAValidationFixturesRequireFeatureFlagAndWorkspace`.
- [x] Add environment/configuration handling.
  - 2026-05-30 evidence: `AppRuntimeConfiguration.fromEnvironment()` centralizes
    workspace root, secret store, defaults suite, and deterministic clock
    overrides through `ALPENLEDGER_WORKSPACES_ROOT`,
    `ALPENLEDGER_SECRET_STORE_ROOT`, `ALPENLEDGER_DEFAULTS_SUITE`,
    `ALPENLEDGER_FIXED_NOW`, and `ALPENLEDGER_PRIVACY_MODE`. The UI suite
    launches with these overrides, and `docs/local-development.md` documents
    them for isolated local runs.
- [x] Add dependency review policy.
  - 2026-05-30 evidence: `docs/dependency-review.md` defines dependency review
    rules, required update evidence, and current reviewed dependency records.
    `config/dependency-review.json` records the reviewed SwiftPM pin for
    `SQLCipher.swift` and the vendored GRDB snapshot with exact versions,
    revisions, purpose, risk, review docs, and patch metadata.
    `scripts/verify-dependency-review.sh` fails on unreviewed `Package.resolved`
    pins, package resolution origin drift, direct remote package declarations in
    the main app package, missing review docs, and forbidden vendored metadata.
    The verifier is included in `scripts/verify-readiness.sh` and macOS CI.
- [x] Document local development setup.
  - 2026-05-29 evidence: `docs/local-development.md` documents the verified
    local Xcode/Swift toolchain, XcodeGen flow, readiness commands, and runtime
    environment overrides, including the disposable fresh-checkout verifier.

---

## 2. App shell and design system

- [x] Create the macOS app entry point and windowing setup.
  - 2026-05-30 evidence: `AlpenLedgerApp` is the `@main` SwiftUI entry point,
    creates the primary `WindowGroup`, wires `RootSplitView`, app alerts, modal
    sheets, Help Center presentation, default window sizing, and macOS command
    menus. Covered by the app CI build and
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns`.
- [x] Build a sidebar-based navigation shell.
  - 2026-05-30 evidence: `WorkspaceShellView` uses `NavigationSplitView` with
    `SidebarView`, and `AppSection` groups Overview, Inbox, Copilot, Ledger,
    Documents, Tax Studio, and Settings into native sidebar sections with
    stable labels, symbols, subtitles, and command shortcuts. Covered by
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns` and
    representative UI navigation tests.
- [x] Implement toolbar actions and global search entry points.
  - 2026-05-30 evidence: `WorkspaceShellView` exposes a top-level workspace
    search toolbar button plus a `Command-Shift-F` "Find in Workspace" command.
    The search popover uses `SQLiteSearchIndex.search` results and routes
    document, transaction, counterparty, and issue hits into the existing
    Documents, Ledger, and Inbox views. Covered by
    `testGlobalSearchFindsAndNavigatesWorkspaceRecords`.
- [x] Build a reusable inspector pattern.
  - 2026-05-30 evidence: `InspectorPane` and `InspectorSectionRow` provide the
    reusable inspector section pattern, while Ledger, Documents, Tax Studio, and
    Inbox attach native SwiftUI inspector panes with stable column widths and
    selection-aware content. Covered by
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns`,
    `testToggleInspectorForActiveSectionRoutesToVisibleSectionOnly`, and
    inspector-focused app tests.
- [x] Build basic list, table, badge, status, and empty-state components.
  - 2026-05-30 evidence: `ALDesignSystem` includes `StatusBadge`,
    `PaneEmptyState`, `SummaryTile`, `WorkItemRow`, `DocumentReferenceRow`, and
    `PaneHeader`; feature views compose them with native `List`, `Table`,
    `GroupBox`, and `ContentUnavailableView` surfaces. Covered by
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns` and feature
    snapshot/app tests for Overview, Inbox, Ledger, Documents, Tax Studio,
    Copilot, Settings, and workspace chooser states.
- [x] Build a document preview container.
  - 2026-05-30 evidence: `DocumentPreviewHost` wraps PDFKit for PDF preview,
    renders image files through `NSImage`, and falls back to native unavailable
    states for missing/unsupported files. `DocumentsFeatureView` embeds the
    preview in the document split view and exposes the stable
    `documents.previewPane` accessibility hook. Covered by
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns` and document
    preview UI tests.
- [x] Implement commands/menu items and core keyboard shortcuts.
  - 2026-05-30 evidence: `AlpenLedgerApp` defines Workspace, Go,
    Selection, View, and Help command groups for create/open/close workspace,
    imports, sample data, backup/check/restore, diagnostics/support exports,
    workspace deletion, section navigation (`Command-1` through `Command-7`),
    global search (`Command-Shift-F`), inspector toggling
    (`Command-Option-0`), and Help (`Command-?`). Close Workspace now returns
    to the chooser without deleting the workspace and preserves the recent
    reference. Covered by
    `testCloseWorkspaceClearsSessionStateWithoutRemovingRecentReference`.
- [x] Create a design token system for spacing, typography, radii, and iconography.
  - 2026-05-30 evidence: `AppTheme` centralizes spacing, corner radii, pane
    widths, table column sizing, native macOS colors, typography, SF Symbol
    rendering, and motion transitions consumed by app shell and feature views.
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns` verifies the
    stable token contract for core layout and radius values.
- [ ] Ensure the visual style feels native to macOS.
  - 2026-05-30 partial evidence: the shell uses SwiftUI `WindowGroup`,
    `NavigationSplitView`, `.sidebar`, `.inspector`, `GroupBox`, `Table`,
    `ContentUnavailableView`, SF Symbols, and native color tokens. This remains
    open until representative UI automation screenshots or manual macOS visual
    review evidence is recorded.
  - 2026-05-30 preflight evidence: `scripts/verify-readiness.sh` now runs
    `scripts/verify-ui-automation-preflight.sh` before opt-in UI automation so
    missing macOS Accessibility permission fails immediately instead of timing
    out during app activation.
  - 2026-05-30 evidence-format hardening: release candidates now need a strict
    `docs/release-evidence/ui-smoke-v0.1.0.json` record validated by
    `scripts/verify-ui-smoke-evidence.sh`, covering full UI automation, default
    and Reduce Motion manual passes, the three target window sizes, archived
    evidence refs, and empty blockers. The verifier now requires those refs to
    be existing repo-relative supporting files under `docs/release-evidence/`,
    not placeholders, URLs, absolute paths, or self-references.
- [x] Add preview/demo states for key UI components.
  - 2026-05-30 evidence: `DesignSystemPreviewCatalog` and
    `DesignSystemDemoGallery` provide compile-checked component demo states for
    status badges, summary tiles, work-item rows, document reference rows,
    inspector panes, empty states, and document preview fallback behavior.
    `testAppShellAndDesignSystemContractsExposeNativeMacPatterns` asserts the
    demo catalog IDs and constructs the gallery through the app CI scheme.

---

## 3. Workspace lifecycle and local security

- [x] Implement workspace creation.
  - 2026-05-30 evidence: `WorkspaceService.createWorkspace` and
    `WorkspaceAppModel.createWorkspace` create encrypted local workspaces,
    initialize default entity/year/account data, register recents, and route the
    user into the workspace shell. Covered by
    `workspaceServiceCreatesEncryptedWorkspaceInTempDirectory`,
    `testCreateDemoWorkspaceBuildsLocalSampleWorkspace`, and app-model
    workspace creation coverage.
- [x] Implement workspace opening and closing.
  - 2026-05-30 evidence: recent and panel-based opening route through
    `WorkspaceService.openWorkspace` and `WorkspaceAppModel.configure`, which
    recovers interrupted imports and refreshes workspace state. `Close
    Workspace` now clears the active session, selection, search state, and
    transient workspace-specific sheets/popovers while preserving recent
    workspace references. Covered by
    `testRecentWorkspaceReferenceReopensThroughWorkspaceAppModel` and
    `testCloseWorkspaceClearsSessionStateWithoutRemovingRecentReference`.
- [x] Implement workspace metadata and recent-workspace management.
  - 2026-05-30 evidence: workspace manifests persist IDs, names, timestamps,
    and schema metadata, while `RecentWorkspacesStore` tracks created, opened,
    restored, and deleted workspace references. Rename/delete/restore coverage
    verifies metadata and recents stay aligned through lifecycle operations.
- [x] Choose and implement encrypted-at-rest storage strategy.
  - 2026-05-30 evidence: `SQLCipherDatabasePoolProvider` opens the workspace
    SQLite database with a derived passphrase, and `EncryptedBlobStore` stores
    imported source files and generated artifacts under the workspace `blobs`
    directory. Covered by `workspaceServiceCreatesEncryptedWorkspaceInTempDirectory`
    and backup/restore tests that reopen persisted database rows and encrypted
    blobs.
- [x] Store secrets in Keychain.
  - 2026-05-30 evidence: production runtime configuration and
    `WorkspaceStorageManager` default to `KeychainSecretStore`, which stores,
    loads, and deletes per-workspace master keys as generic-password Keychain
    items. File and in-memory stores remain explicit test/debug overrides.
- [x] Implement per-workspace key derivation or equivalent isolation.
  - 2026-05-30 evidence: workspace creation generates a unique master key and
    salt, persists the salt in `workspace.json`, stores the master key by
    workspace ID, and derives separate SQLCipher and blob keys through
    `WorkspaceCrypto` HKDF labels.
- [x] Implement optional workspace lock/auth gate.
  - 2026-05-30 evidence: `WorkspaceLockAuthenticationClient` uses macOS
    device-owner authentication before opening a locked workspace,
    `WorkspaceUIPreferencesStore` persists the per-workspace lock preference,
    and `WorkspaceAppModel.lockCurrentWorkspace()` clears the active decrypted
    session back to the workspace chooser. Settings and the File menu expose
    the lock controls. Covered by
    `testWorkspaceUIPreferencesStorePersistsWorkspaceLockPerWorkspace` and
    `testWorkspaceLockGateRequiresAuthenticationBeforeReopening`.
- [x] Define workspace storage layout on disk.
  - 2026-05-30 evidence: `WorkspacePaths` defines `workspace.json`,
    `workspace.sqlite`, `blobs/`, `exports/`, and `temp/` under each workspace
    root, while `WorkspaceStorageManager.defaultWorkspacesRoot()` places
    workspaces in Application Support by default.
- [x] Implement corruption detection / safe-open behavior.
  - 2026-05-30 evidence: `WorkspaceStorage.databaseHealthReport()` runs SQLite
    `quick_check`, foreign-key checks, migration-ledger validation, and required
    table/view checks; migration open creates a recovery snapshot and restores
    it on migration failure. Covered by the database health tests and
    `workspaceStorageManagerRestoresDatabaseSnapshotWhenMigrationFails`.
- [x] Implement workspace export and import metadata handling.
  - 2026-05-30 evidence: `WorkspaceBackupManifest` records backup format,
    workspace ID/name, storage version, workspace directory, key filename,
    excluded paths, and per-file SHA-256 hashes/byte counts. Backup validation
    verifies the manifest, key file, workspace manifest, excluded paths, and
    hashes before restore. Covered by
    `workspaceBackupRestoreRoundTripsDatabaseBlobsKeyAndAuditTrail`,
    `workspaceBackupValidationRejectsTamperedHashedFile`, and app-model
    backup/restore tests.

---

## 4. Database, migrations, and persistence foundation

- [x] Integrate the primary SQLite-based database layer.
  - 2026-05-30 evidence: `WorkspaceStorage` exposes a GRDB `DatabasePool`
    backed by SQLCipher and wires the production repositories for workspaces,
    entities, tax years, accounts, imports, transactions, journals, documents,
    evidence, issues, tax facts, proposals, conversations, filing packages, and
    audit events.
- [x] Implement a migration framework.
  - 2026-05-30 evidence: `makeAlpenLedgerDatabaseMigrator()` centralizes the
    GRDB migrator registration, and `WorkspaceStorageManager.openWorkspace`
    applies it through `migrate(dbPool:)`.
- [x] Add migration smoke tests.
  - 2026-05-30 evidence:
    `databaseMigrationsCreateRequiredSchemaFromEmptyDatabase` migrates an empty
    database and verifies the expected migration ledger, required tables and
    views, latest columns, named indexes, and `document_search`/`global_search`
    FTS tables.
- [x] Add idempotent migration checks.
  - 2026-05-30 evidence:
    `databaseMigrationsAreIdempotentAfterFullApplication` reapplies the full
    migrator and verifies the schema snapshot and migration ledger do not
    change.
- [x] Implement full-text search tables/indexes.
  - 2026-05-30 evidence: migration `v14_global_search` creates the
    `globalSearchRecords` metadata table and external-content `global_search`
    FTS5 table. Required-table health coverage tracks both, and
    `workspaceGlobalSearchFindsDocumentsTransactionsCounterpartiesAndIssues`
    verifies indexed search output from repository writes.
- [x] Implement import idempotency tracking.
  - 2026-05-30 evidence: import jobs now persist raw `sourceBlobHash` and
    parsed `sourceFingerprint` values with indexed lookup by workspace/kind.
    `ImportPipeline` rejects an exact raw-source re-import before creating a
    second job or transaction set, while statement fingerprints continue to
    catch semantic duplicates after parsing. Covered by
    `importJobServiceRejectsDuplicateRawSourceBeforeCreatingSecondStatementJob`
    and migration coverage for `v18_import_job_source_tracking`.
- [x] Implement read-only analytics/reporting views.
  - 2026-05-30 evidence: migration `v13_reporting_views` creates the
    required read-only SQLite views for AI/UI reporting. `workspaceReportingViewsExposeReadOnlyScopedSummaries`
    queries the views against real workspace data and verifies they reject
    writes.
- [x] Implement audit tables / event persistence.
  - 2026-05-30 evidence: migration `v1_core` creates the `auditEvents` table,
    `v4_performance_indexes` adds the workspace/occurred-at index, and
    `GRDBAuditEventRepository` is wired into `WorkspaceStorage`. Workspace,
    import, tax, evidence, agent-tool, backup/restore, and support-bundle tests
    assert persisted audit events and sanitized audit exports.
- [x] Implement database health checks.
  - 2026-05-29 evidence: `WorkspaceStorage.databaseHealthReport()` runs
    SQLite `quick_check`, verifies foreign-key enforcement and violations,
    checks the GRDB migration ledger against the expected migration list, and
    verifies required schema tables and views. `SettingsFeatureView` surfaces
    the result as a Data Health section. Covered by
    `workspaceDatabaseHealthReportPassesForFreshWorkspace`,
    `workspaceDatabaseHealthReportFlagsMissingMigrationLedgerRows`, and
    `workspaceDatabaseHealthReportFlagsMissingRequiredViews`, and
    `testSettingsSnapshotShowsWorkspaceDatabaseHealth`.
- [x] Document schema evolution strategy.
  - 2026-05-30 evidence: `docs/schema-evolution.md` documents migration
    identifier rules, additive/default-safe schema changes, required migration
    test evidence, data-backfill constraints, and recovery expectations.

---

## 5. Core domain model

### Workspace and entity model
- [x] `Workspace`
  - 2026-05-30 evidence: `Workspace` is a persisted domain object backed by
    `GRDBWorkspaceRepository`, the `workspaces` migration table, workspace
    manifests, and `WorkspaceService` create/open flows. Covered by
    `workspaceServiceCreatesEncryptedWorkspaceInTempDirectory` and app-model
    workspace lifecycle tests.
- [x] `LegalEntity`
  - 2026-05-30 evidence: `LegalEntity` is persisted through
    `GRDBLegalEntityRepository`, scoped to workspaces, and managed by
    `LegalEntityService` with audit-backed create/delete behavior. Covered by
    `entityWorkspaceCRUDAndUniqueConstraint`,
    `legalEntityDeleteRemovesEmptySoleProprietor`, and
    `legalEntityDeleteReturnsBlockingDependenciesWhenTransactionsExist`.
- [x] `TaxYear`
  - 2026-05-30 evidence: `TaxYear` is persisted through
    `GRDBTaxYearRepository` and governed by `TaxYearService` status transitions
    for open, locked, and filed years. Covered by
    `taxYearServiceLocksAndUnlocksTaxYearWithAuditTrail` and
    `taxYearServiceDoesNotReopenFiledTaxYear`.
- [ ] Household / spouse / joint-filing context support
- [x] Sole proprietor entity support
  - 2026-05-30 evidence: `LegalEntityKind.soleProprietor`,
    `LegalEntityService.createSoleProprietor`, sole-proprietor ledger
    templates, and Zurich self-employment fact computation are implemented.
    Covered by `zurichSoleProprietorFixtureImportProducesProfitAndLossFacts`,
    `zurichSoleProprietorBusinessTaxFixtureProducesExpectedFactsAndExportReadiness`,
    and the legal-entity deletion/entity-workspace tests.
- [ ] Legal-entity support baseline (simple GmbH/AG path)

### Finance model
- [x] `LedgerAccount`
  - 2026-05-30 evidence: `LedgerAccount` is persisted through
    `GRDBLedgerAccountRepository`, seeded through `LedgerTemplates`, and
    referenced by journal-entry, proposal, and account-summary workflows.
    Covered by `agentToolWorkflowProposesClosingAccrualWithoutPostingJournalEntry`
    and `agentToolWorkflowAppliesDraftJournalEntryWithExplicitConfirmation`.
- [x] `FinancialAccount`
  - 2026-05-30 evidence: `FinancialAccount` is persisted through
    `GRDBFinancialAccountRepository`, created for entity workspaces, and used
    as the statement-import and transaction scope. Covered by
    `agentToolWorkflowListsFinancialAccountsThroughExecutor` and statement
    import workflow tests.
- [x] `ImportJob`
  - 2026-05-30 evidence: `ImportJob` is persisted through
    `GRDBImportJobRepository` with status, diagnostics, source blob hashes, and
    retry/recovery metadata. Covered by
    `importJobServiceRecoversInterruptedStartedImports`,
    `importJobServicePersistsCSVParseDiagnostics`, and
    `importJobServiceRetriesCancelledCSVFromStoredSourceBlob`.
- [x] `StatementImport`
  - 2026-05-30 evidence: `StatementImport` is persisted through
    `GRDBStatementImportRepository`, linked to financial accounts and source
    fingerprints, and restored through backup drills. Covered by
    `statementImportDefaultRoutesImportsAndPersistsAcrossReopen` and
    `customerScaleStatementImportSurvivesBackupRestoreDrill`.
- [x] `Transaction`
  - 2026-05-30 evidence: `Transaction` is persisted through
    `GRDBTransactionRepository`, linked to statement imports, counterparties,
    ledger refs, tax codes, and evidence workflows. Covered by
    `csvImporterParsesRowsIntoTransactions`,
    `statementImportCreatesCounterpartiesForTransactions`, and
    `workspaceReportingViewsExposeReadOnlyScopedSummaries`.
- [x] `Counterparty`
  - 2026-05-30 evidence: `Counterparty` is persisted in the `counterparties`
    table through migration `v12_counterparties`, with entity scope,
    normalized name, active/merged status, merge target, and timestamps.
    Transaction imports and repository saves attach transactions to persisted
    counterparties without replacing imported transaction text. Covered by
    `statementImportCreatesCounterpartiesForTransactions` and
    `databaseMigrationsBackfillLegacyV4WorkspaceData`.
- [x] `JournalEntry`
  - 2026-05-30 evidence: `JournalEntry` is persisted in the
    `journalEntries` table through migration `v11_journal_entries`, including
    entity/tax-year scope, entry number, effective date, status, memo, approval
    identity, and approval timestamp. `ledger.apply_draft_entry` posts reviewed
    balanced entries through `JournalEntryRepository`.
- [x] `JournalLine`
  - 2026-05-30 evidence: `JournalLine` is persisted in the `journalLines`
    table through migration `v11_journal_entries`, including ledger-account
    refs, debit/credit amounts, currency, tax code, source refs, and memo.
    `agentToolWorkflowAppliesDraftJournalEntryWithExplicitConfirmation`
    verifies posted line round-trip through the repository.
- [x] Account opening balances
  - 2026-05-30 evidence: `FinancialAccount` stores nullable opening balance
    amount/date through migration `v21_account_opening_balances`; account
    summaries compute from the latest imported running balance plus later
    transactions, or from opening balance plus transactions when running
    balances are unavailable. Agent account summaries expose the opening
    balance fields. Covered by
    `financialAccountComputesBalanceFromOpeningBalanceWhenRunningBalanceIsMissing`,
    `financialAccountExtendsLatestRunningBalanceWithLaterTransactions`,
    `databaseMigrationsUpgradeLegacyV20FinancialAccountOpeningBalances`,
    `agentToolWorkflowAccountSummaryUsesOpeningBalanceWhenRunningBalanceIsMissing`,
    and `testLedgerAccountSummaryShowsUnavailableWithoutRunningBalance`.
- [x] Currency handling baseline
  - 2026-05-30 evidence: `CurrencyCode`, `Money`, and `MoneyFormatter` enforce
    ISO-code normalization, currency-safe arithmetic, decimal conversion, and
    deterministic Swiss formatting. Covered by `CurrencyCodeTests`,
    `MoneyTests`, `MoneyFormatterTests`, and CSV decimal edge-case tests.
- [x] Period locking model
  - 2026-05-29 evidence: `TaxYearStatus` is enforced through
    `TaxYearService.lockTaxYear` / `unlockTaxYear`, transition validation,
    audit events, and locked-period guards in import and tax fact mutation
    paths. Covered by `taxYearServiceLocksAndUnlocksTaxYearWithAuditTrail`,
    `taxYearServiceDoesNotReopenFiledTaxYear`,
    `statementImportRejectsLockedTaxYearTransactions`, and
    `refreshFactsRejectsLockedTaxYear`.

### Document and evidence model
- [x] `Document`
  - 2026-05-30 evidence: `Document` is persisted through
    `GRDBDocumentRepository`, imported with encrypted source blobs, reviewed
    through metadata workflows, archived/restored without source deletion, and
    indexed for search. Covered by `documentServiceReviewsMetadataWithAuditAndSearchRefresh`
    and document archive/restore tests.
- [x] `EvidenceLink`
  - 2026-05-30 evidence: `EvidenceLink` is persisted through
    `GRDBEvidenceLinkRepository` and used to connect documents, transactions,
    requirements, issues, and tax facts with entity-scope validation. Covered by
    `evidenceTablesRoundTrip`,
    `reconciliationServiceApproveDocumentMatchProposalConfirmsEvidenceAndResolves`,
    and `businessExpenseEvidenceLinkSatisfiesMissingEvidenceRequirement`.
- [x] `Requirement`
  - 2026-05-30 evidence: `Requirement` is persisted through
    `GRDBRequirementRepository` and refreshed from missing-evidence policies for
    statement coverage and expense support. Covered by
    `statementCoverageRefreshCreatesSingleMissingFebruaryIssue` and
    `missingExpenseEvidenceDropsAfterConfirmedLink`.
- [x] `Issue`
  - 2026-05-30 evidence: `Issue` is persisted through `GRDBIssueRepository`,
    supports open/resolved/dismissed lifecycle states, and is surfaced in Inbox,
    Overview, agent tools, and readiness summaries. Covered by
    `issueServiceResolveAndDismissTransitionsPersist`,
    `agentToolWorkflowOpensIssueThroughExecutorWithProvenance`, and
    `readinessSummaryTracksNotStartedNeedsAttentionAndReadyForReview`.

### Tax and AI model
- [x] `TaxFact`
  - 2026-05-30 evidence: `TaxFact` is persisted through
    `GRDBTaxFactRepository` with current/superseded status, provenance refs,
    source-type distinctions, manual override handling, and deterministic
    recompute behavior. Covered by
    `taxFactRepositoryPreservesSingleCurrentVersionAfterSupersession`,
    `manualOverrideMarksFactAuditsAndSurvivesRecompute`, and
    `taxFactExplanationResolvesSupportingDocumentRefs`.
- [x] `FilingPackage`
  - 2026-05-30 evidence: `FilingPackage` stores
    generated/finalized/submitted lifecycle state, generated/finalized/submitted
    timestamps, reviewer identity for finalization, snapshot hash, export
    format, and entity/tax-year scope. Migration
    `v10_filing_package_finalization` adds finalization columns for existing
    workspaces, and
    `agentToolWorkflowFinalizesExportPackageWithExplicitConfirmation` verifies
    finalization without submission.
- [x] `AgentProposal`
  - 2026-05-30 evidence: `AgentProposal` is persisted through
    `GRDBAgentProposalRepository` with proposal type, confidence, source refs,
    missing fields, status, decision metadata, and review-state migrations.
    Covered by `agentToolWorkflowCreatesDocumentMatchProposalThroughExecutor`,
    `agentConversationStoragePersistsHistoryRefsAndPendingApprovals`, and
    `databaseMigrationsUpgradeLegacyV14AgentProposalUncertaintyState`.
- [x] `AuditEvent`
  - 2026-05-30 evidence: `AuditEvent` is persisted through
    `GRDBAuditEventRepository` and written by `AuditLogger` for workspace,
    import, tax, evidence, agent-tool, backup/restore, and support-bundle
    workflows. Covered by
    `workspaceBackupRestoreRoundTripsDatabaseBlobsKeyAndAuditTrail`,
    `workspaceSupportBundleExportIncludesSanitizedAuditLog`, and
    `agentToolWorkflowAuditsSuccessfulToolExecutionWithoutRawInputOrOutput`.

### Invariants
- [x] Balanced journal-entry enforcement
  - 2026-05-29 evidence: `JournalEntry` construction requires non-empty
    balanced debit/credit lines. `journalEntryBalances`,
    `journalEntryRejectsUnbalancedLines`, and `journalEntryRejectsEmptyLines`
    cover the invariant.
- [x] Raw-import immutability
  - 2026-05-29 evidence: imported bank statement and document source bytes are
    preserved in encrypted content-addressed blobs and covered by source-file
    mutation tests.
- [x] Locked-period protection
  - 2026-05-29 evidence: statement imports reject transactions in locked tax
    years and tax fact refresh rejects locked tax years. Covered by
    `statementImportRejectsLockedTaxYearTransactions` and
    `refreshFactsRejectsLockedTaxYear`. `TaxYearService` now provides audited
    lock/reopen transitions, and Tax Studio exposes the selected period status
    plus lock/reopen actions.
- [x] Manual-override marking
  - 2026-05-29 evidence: tax facts can be marked `.overridden` only with a
    non-empty reason, overrides are blocked for locked tax years, audit events
    are written, and deterministic recomputation preserves the current
    user-overridden fact. Covered by
    `manualOverrideMarksFactAuditsAndSurvivesRecompute` and
    `manualOverrideRejectsLockedTaxYear`.
- [x] Provenance preservation
  - 2026-05-29 evidence: tax fact supersession preserves the retired fact's
    original `provenanceRefs`, stores the replacement's current provenance refs,
    and links the current value to the superseded value. Covered by
    `taxFactRepositoryPreservesSingleCurrentVersionAfterSupersession`.
- [x] User approval state tracking
  - 2026-05-29 evidence: agent proposals now persist decision status, decision
    timestamp, deciding actor, and decision reason. Rejected proposals preserve
    user decision metadata across resync, auto-resolved proposals record a
    system decision reason, and the inbox inspector renders the decision state.
    Covered by `reconciliationServiceRejectPreservesRejectedProposalOnResync`,
    `documentLinkProposalResolvesAfterConfirmedLink`, `evidenceTablesRoundTrip`,
    and `testInboxProposalInspectorShowsDecisionMetadata`.

---

## 6. File vault and document infrastructure

- [x] Implement content-addressed file storage.
  - 2026-05-30 evidence: `EncryptedBlobStore` stores encrypted blobs under
    SHA-256 content hashes and materializes read-only temp copies on demand.
- [x] Implement hash-based dedupe.
  - 2026-05-30 evidence: blob storage returns existing hashes without
    rewriting encrypted blobs, documents have a unique workspace/blob hash
    index, and statement imports now reject exact raw-source duplicates before
    creating a second import job.
- [x] Preserve original filenames and source metadata.
  - 2026-05-30 evidence: documents keep `originalFilename`, import jobs keep
    the source filename plus raw source hash/fingerprint metadata, and
    statement imports keep source format, blob hash, and statement fingerprint.
- [x] Support security-scoped file imports where relevant.
  - 2026-05-30 evidence: `SecurityScopedResourceAccess` wraps user-selected
    source URLs before document intake and bank-statement import reads. The
    production implementation calls `startAccessingSecurityScopedResource` and
    balances successful starts with `stopAccessingSecurityScopedResource`, while
    tests inject a recorder. Covered by
    `documentServiceBracketsImportedSourceWithSecurityScopedAccess` and
    `importJobServiceBracketsStatementSourceWithSecurityScopedAccess`.
- [x] Support drag-and-drop intake.
  - 2026-05-30 evidence: `DocumentsFeatureView` accepts dropped file URLs with
    `.dropDestination(for: URL.self)` and routes them through the same
    document-intake path as panel-selected imports.
- [x] Support PDF preview.
  - 2026-05-30 evidence: `DocumentPreviewHost` renders imported PDF sources
    with `PDFKit.PDFView`, and `ActiveWorkspaceSession` materializes selected
    document blobs into preview URLs.
- [x] Support image preview.
  - 2026-05-30 evidence: `DocumentPreviewHost` renders supported imported
    images with `NSImage`, using the same materialized preview URL path as PDF
    documents.
- [x] Support document metadata editing/review.
  - 2026-05-30 evidence: `DocumentService.reviewDocumentMetadata` updates
    active document type and issue date, confirms metadata, refreshes search
    indexing, and writes a `documentMetadataReviewed` audit event. The
    Documents inspector exposes type/date review controls and a confirm action.
    Covered by `documentServiceReviewsMetadataWithAuditAndSearchRefresh`,
    `documentServiceRejectsMetadataReviewForArchivedDocument`, and
    `testDocumentMetadataReviewUpdatesVaultAndAuditTrail`.
- [x] Implement extracted-text persistence.
  - 2026-05-30 evidence: document intake stores `extractedText` from
    `DocumentExtractionPipeline` on `Document` rows; fixture coverage verifies
    PDF/text/XML extraction survives repository fetches.
- [x] Implement document search indexing.
  - 2026-05-30 evidence: document intake and metadata review call
    `storage.searchIndex.indexDocument`, migrations maintain external-content
    global-search triggers for document rows, and document/global-search tests
    cover searchable source text and navigation.
- [x] Implement document tagging / type classification storage.
  - 2026-05-30 evidence: persisted `Document.documentType` stores detected or
    reviewer-confirmed classifications, the document browser filters by stored
    type, and eCH/receipt/QR-bill fixture tests cover classification storage.
- [x] Implement safe delete/archive semantics.
  - 2026-05-30 evidence: documents now have active/archived lifecycle
    state plus archive reviewer metadata. `DocumentService.archiveDocument`
    preserves the encrypted source blob, removes archived documents from active
    repository lists, document FTS, global search, and agent document
    search/summary tools, and rejects archival when the document is still a
    confirmed evidence link, a satisfied requirement source, or a current tax
    fact source. Re-importing the same source restores the archived document
    instead of creating a duplicate. `DocumentService.restoreArchivedDocument`
    restores archived documents explicitly with reviewer rationale and audit
    evidence. The Documents review UI now has an Archived scope plus
    archive/restore inspector actions, and archived documents cannot be linked
    to transactions until restored. Covered by
    `documentServiceArchivesUnlinkedDocumentWithoutDeletingSource`,
    `documentServiceRestoresArchivedDuplicateOnReimport`,
    `documentServiceRestoresArchivedDocumentExplicitly`,
    `documentServiceRejectsArchivingActiveEvidenceDocuments`,
    `documentServiceRejectsArchivingFilingEvidenceDocuments`,
    `testDocumentArchiveAndRestoreActionsSwitchReviewViews`,
    `agentToolWorkflowGetsDocumentSummaryThroughExecutorWithBoundedSnippet`,
    `agentToolWorkflowSearchesDocumentsThroughExecutorWithProvenance`, and
    `databaseMigrationsUpgradeLegacyV19DocumentArchiveState`.

---

## 7. Document pipeline

- [ ] File intake pipeline
- [ ] Hash and dedupe stage
- [ ] Type detection stage
- [ ] Native PDF text extraction stage
- [ ] OCR fallback stage
- [ ] Structured extraction stage
- [ ] Entity matching stage
- [ ] Evidence suggestion stage
- [ ] Issue generation stage
- [ ] Search indexing stage
- [ ] Reprocessing / parser-version replay support
- [ ] Import diagnostics and parse logs

### Supported document categories
- [ ] Receipt
- [ ] Supplier invoice
- [ ] Customer invoice
- [x] QR-bill
  - 2026-05-30 evidence: `DocumentExtractionPipeline` detects Swiss QR-bill
    text payloads as `.qrBill`, and app/feature document labels render that
    document type.
- [ ] Salary certificate
- [ ] Bank statement / extract
- [ ] eCH tax statement
- [ ] Health-insurance tax certificate
- [ ] Pillar 2 / pillar 3a certificate
- [ ] Mortgage statement
- [ ] Tax office correspondence
- [ ] Contract / lease
- [ ] Payroll export
- [ ] Annual financial statement

---

## 8. Import framework

- [ ] Create a versioned importer plugin architecture.
- [ ] Implement `canRecognize`, `parse`, `normalize`, `validate`, and `emitIssues` flow.
- [x] Implement import-job records.
  - 2026-05-30 evidence: statement and document intake create `ImportJob`
    records with started/completed/failed status, parser identity, warning
    count, source filename, and source hash metadata.
- [x] Track parser version per import.
  - 2026-05-30 evidence: `ImportJob` stores `parserKey` and `parserVersion`
    for each import and importers pass their parser identity through the
    default pipeline.
- [x] Store raw source metadata per import.
  - 2026-05-30 evidence: import jobs persist the original source filename,
    raw `sourceBlobHash`, and parsed `sourceFingerprint` where available.
- [x] Support import retry/reprocess.
  - 2026-05-30 evidence: `ImportJobService.retryStatementImport` fetches a
    failed or cancelled bank-statement import job, materializes its stored
    encrypted `sourceBlobHash` into workspace temp storage, preserves the
    original source filename for the replacement import job and audit payloads,
    reruns the normal import pipeline, and cleans up the materialized source.
    `importJobServiceRetriesCancelledCSVFromStoredSourceBlob` cancels a valid
    CSV import, deletes the original source file, retries from the stored blob,
    persists one completed statement import and transaction, and verifies the
    same raw source remains duplicate-protected after retry.
- [x] Support safe duplicate detection.
  - 2026-05-30 evidence: the import pipeline checks completed raw-source
    hashes before mutation and statement-import fingerprints after parsing;
    duplicate attempts do not create extra transactions.
- [x] Support import warnings and severity levels.
  - 2026-05-30 evidence: `ImportDiagnostic` persists warning/error severity,
    code, location, message, and creation time per import job. Covered by CSV
    parse diagnostic and rejected-import diagnostic tests.
- [x] Implement import summaries for UI review.
  - 2026-05-30 evidence: Inbox import rows and inspectors summarize status,
    parser identity, timing, stored-source availability, source fingerprint,
    warnings/errors, and diagnostics. Failed or cancelled bank-statement imports
    with stored source expose a `Retry Import` action that reprocesses from the
    encrypted blob through `ImportJobService.retryStatementImport`, then
    refreshes and selects the replacement completed import where available.
    Covered by `testImportInspectorOffersRetryForCancelledStatementImport` and
    `testInboxRetryImportActionReprocessesStoredStatementBlob`.
- [x] Implement importer test harnesses.
  - 2026-05-30 evidence: `ImporterFixtureHarnessTests` provides a reusable
    bank-statement importer fixture contract for CSV, CAMT.052, CAMT.053, and
    CAMT.054 fixtures. The harness verifies recognizer behavior, parser identity,
    import-job kind, statement source metadata, fingerprint presence, coverage
    ordering, balances, row counts, warnings/errors, transaction account links,
    statement-import links, CHF normalization, references, source-line refs, and
    format-specific recognizer specificity. Covered by
    `importerFixtureHarnessValidatesBankStatementImporterContracts` and
    `importerFixtureHarnessChecksRecognizerSpecificity`.

---

## 9. Bank and payment imports

### CSV
- [x] CSV importer framework
  - 2026-05-30 evidence: `CSVBankStatementImporter` is a versioned
    `Importer` plugin with recognizer, parse, statement payload, parse-log,
    diagnostics, source fingerprint, and import-job integration through
    `ImportPipeline`. Covered by `csvImporterRecognizesFixtureHeader`,
    `csvImporterParsesRowsIntoTransactions`,
    `importerFixtureHarnessValidatesBankStatementImporterContracts`, and
    import-job persistence/retry/diagnostic tests.
- [x] Column mapping support
  - 2026-05-30 evidence: `CSVBankStatementImporter` detects mapped headers
    instead of requiring the canonical column order, including signed amount
    columns and separate debit/credit columns. Covered by
    `csvImporterParsesSwissSemicolonMappedStatement`,
    `csvImporterParsesDebitCreditPresetColumns`, and
    `csvImporterRejectsUnmappedCSVHeader`.
- [x] Per-bank CSV presets
  - 2026-05-30 evidence: the CSV importer ships versioned built-in presets for
    canonical AlpenLedger CSV, generic Swiss bank CSV, and PostFinance-style
    debit/credit exports. `csvImporterExposesVersionedColumnMappingPresets`
    verifies the preset registry and parser version.
- [x] CSV date/amount normalization
  - 2026-05-30 evidence: CSV parsing accepts canonical ISO dates, Swiss
    day-month-year dates, comma/dot/apostrophe thousands/decimal conventions,
    semicolon/tab delimiters, and debit/credit sign normalization while keeping
    row-level diagnostics for bad dates, bad amounts, and missing columns.
    Covered by `CSVParsingEdgeCaseTests`,
    `csvImporterParsesSwissSemicolonMappedStatement`, and
    `csvImporterParsesDebitCreditPresetColumns`.
- [x] CSV import fixture coverage
  - 2026-05-30 evidence: `Fixtures/Bank/sample-bank-statement.csv` is registered
    in `config/fixture-catalog.json` with a stable SHA-256 hash, synthetic-data
    declaration, and coverage references. `CSVBankStatementImporterTests`
    verifies header recognition and transaction parsing, and the fixture is also
    used by reconciliation and sole-proprietor tax tests.

### CAMT / ISO 20022
- [ ] `camt.052` support
  - 2026-05-30 partial evidence: `CAMTBankStatementImporter` recognizes and
    parses the synthetic `camt.052.001.08` account-report fixture through the
    default import pipeline, including statement import persistence and
    import-job status. Multi-report coverage now verifies earliest coverage
    start, latest coverage end, first opening balance, and latest closing
    balance selection. This remains open until broader bank-variant and
    intraday-report samples are covered.
- [ ] `camt.053` support
  - 2026-05-30 partial evidence: `CAMTBankStatementImporter` recognizes and
    parses the synthetic `camt.053.001.08` statement fixture through the default
    import pipeline, including statement import persistence and import-job
    status. Multi-statement coverage now verifies earliest coverage start,
    latest coverage end, first opening balance, and latest closing balance
    selection. This remains open until broader bank-variant samples are covered.
- [ ] `camt.054` support
  - 2026-05-30 partial evidence: `CAMTBankStatementImporter` recognizes and
    parses the synthetic `camt.054.001.08` debit/credit notification fixture
    through the default import pipeline, including statement import persistence
    and import-job status. Batch and multi-notification coverage now verifies
    split transaction details, earliest coverage start, and latest coverage
    end. This remains open until broader bank-variant samples are covered.
- [x] Structured reference extraction
  - 2026-05-30 evidence: CAMT transaction details extract `EndToEndId` and
    account-servicer references into transaction references, covered by
    `CAMTBankStatementImporterTests.camt052ImporterParsesReportBalancesAndTransactions`
    `CAMTBankStatementImporterTests.camt053ImporterParsesBalancesAndTransactions`,
    `CAMTBankStatementImporterTests.camt054ImporterParsesNotificationTransactions`,
    and `CAMTBankStatementImporterTests.camt054ImporterParsesBatchAndMultiNotificationTransactions`.
- [x] Booking date / value date handling
  - 2026-05-30 evidence: CAMT entry booking/value dates are parsed into
    transactions and used for statement coverage fallback.
- [x] Balance extraction where available
  - 2026-05-30 evidence: CAMT opening (`OPBD`) and closing (`CLBD`) balances
    are parsed into the `StatementImport` and covered by importer tests,
    including multi-container selection of the earliest opening balance and
    latest closing balance.
- [x] CAMT regression fixtures
  - 2026-05-30 evidence: `Fixtures/Bank/sample-camt052-report.xml`,
    `Fixtures/Bank/sample-camt052-multi-report.xml`,
    `Fixtures/Bank/sample-camt053-statement.xml`,
    `Fixtures/Bank/sample-camt053-multi-statement.xml`,
    `Fixtures/Bank/sample-camt054-notification.xml`, and
    `Fixtures/Bank/sample-camt054-batch-notification.xml` are cataloged in
    `config/fixture-catalog.json` with stable SHA-256 hashes, synthetic-data
    declarations, and coverage references. `scripts/verify-fixtures.sh`
    verifies CAMT.052/CAMT.053/CAMT.054 fixture shape and personal-data scan.

### QR-bill
- [x] QR-bill detection
  - 2026-05-30 evidence: `documentTypeDetectionFindsSwissQRBillPayload`
    verifies Swiss QR-code text payload detection. Native QR image decoding and
    OCR fallback remain outside this narrow baseline.
- [x] Structured reference extraction
  - 2026-05-30 evidence: `qrBillExtractionParsesStructuredPaymentFields`
    verifies QRR reference type and structured reference extraction.
- [x] Creditor / debtor extraction
  - 2026-05-30 evidence: the same QR-bill extraction test verifies creditor and
    debtor names from the Swiss QR-code payload structure.
- [x] Amount and currency extraction
  - 2026-05-30 evidence: QR-bill extraction parses CHF amount into `Money`.
- [x] Structured address handling
  - 2026-05-30 evidence: QR-bill extraction parses creditor and debtor street,
    building number, postal code, town, and country fields.
- [x] QR-bill fixture coverage
  - 2026-05-30 evidence: `Fixtures/Documents/sample-qr-bill.txt` is cataloged
    as `qr-bill`, hash-verified by `scripts/verify-fixtures.sh`, and covered by
    document extraction tests.

---

## 10. Tax and evidence document imports

- [ ] Salary certificate document handling
- [ ] Salary certificate field extraction baseline
- [ ] `eCH-0196` import baseline
  - 2026-05-30 partial evidence:
    `Fixtures/Tax/eCH/eCH-0196-tax-statement-2026.xml` is cataloged,
    hash-verified, imported by `DocumentService`, detected as
    `eCH0196TaxStatement`, and used for XML tax-year extraction coverage. This
    remains open until a semantic eCH-0196 parser maps supported fields into
    deterministic tax facts or review proposals.
- [ ] `eCH-0248` import baseline
  - 2026-05-30 partial evidence:
    `Fixtures/Tax/eCH/eCH-0248-pension-contributions-2026.xml` is cataloged,
    hash-verified, imported by `DocumentService`, detected as
    `eCH0248PensionCertificate`, and used for XML tax-year extraction coverage.
    This remains open until a semantic eCH-0248 parser maps supported fields
    into deterministic tax facts or review proposals.
- [ ] `eCH-0275` import baseline
  - 2026-05-30 partial evidence:
    `Fixtures/Tax/eCH/eCH-0275-health-insurance-2026.xml` is cataloged,
    hash-verified, imported by `DocumentService`, detected as
    `eCH0275HealthInsuranceCertificate`, and used for XML tax-year extraction
    coverage. This remains open until a semantic eCH-0275 parser maps supported
    fields into deterministic tax facts or review proposals.
- [ ] Mortgage statement handling baseline
- [ ] Annual bank/broker tax-statement handling baseline
- [ ] Tax-office notice handling baseline
- [x] Low-confidence extraction review flows
  - 2026-05-30 evidence: `DocumentExtractionPipeline.detectMetadata` now
    returns confidence and reason alongside the detected type. `DocumentService`
    stores filename-only or unknown document metadata as `.proposed`, keeps
    high-confidence text/XML-backed detections `.confirmed`, and records a
    `document.low_confidence_metadata` warning diagnostic on the completed
    import job. OCR-less imports are also excluded from the legacy
    `document_search` FTS index so database health remains clean; filename
    discovery stays available through global search. Covered by
    `documentMetadataDetectionMarksFilenameOnlySignalsAsLowConfidence`,
    `documentMetadataDetectionConfirmsTextBackedSignals`, and
    `documentServiceStoresLowConfidenceMetadataAsProposedWithDiagnostic`.
- [ ] Year and entity detection for imported tax documents

---

## 11. Ledger and bookkeeping core

### Accounts and transactions
- [ ] Account list and detail screens
- [ ] Transaction list and detail screens
- [ ] Transaction filters/search
- [ ] Transaction normalization pipeline
- [ ] Transfer detection baseline
- [ ] Split transactions
- [ ] Manual transaction creation/editing rules
- [x] Counterparty tracking
  - 2026-05-30 evidence: statement imports and transaction repository writes
    now create/reuse entity-scoped `Counterparty` records, transactions store
    a `counterpartyId`, migration `v12_counterparties` backfills legacy
    transaction counterparties, and the confirmed-write
    `entities.merge_counterparties` tool marks duplicate identities merged
    without deleting source counterparties or rewriting imported transaction
    text.

### Bookkeeping
- [ ] Journal posting engine
- [ ] Chart-of-accounts support
- [ ] Personal category mapping
- [ ] Business chart-of-accounts templates
- [ ] Draft journal proposal workflow
- [ ] Manual journal-entry workflow
- [ ] Balance calculations
- [x] Period close / lock basics
  - 2026-05-29 evidence: Tax Studio shows the selected tax year's open,
    locked, or filed status and exposes lock/reopen actions for supported
    transitions. `WorkspaceAppModel` refreshes the Tax Studio snapshot after
    each action and avoids recomputing tax facts when selecting a locked year.
    Covered by
    `testTaxYearLockActionsUpdateTaxStudioSnapshotThroughWorkspaceAppModel`.

### Mixed finance handling
- [ ] Personal-vs-business classification support
- [ ] Owner draw / owner contribution flows
- [ ] Review path for mixed-use expenses
- [ ] Clear entity boundaries in UI and reports
  - 2026-05-30 partial evidence: confirmed document-to-transaction evidence
    links now validate that the document is unassigned or already assigned to
    the transaction account's entity before creating the link. Confirming a link
    scopes an unassigned intake document to that entity so later document search
    and summaries do not continue treating entity evidence as unassigned intake.
    Cross-entity manual links and stale cross-entity document-match proposal
    approvals are rejected. Covered by
    `documentServiceRejectsCrossEntityLinksAndScopesUnassignedLinks`,
    `documentServiceScopesDuplicateImportsToRequestedEntity`, and
    `reconciliationServiceRejectsCrossEntityDocumentMatchApproval`.

---

## 12. Reconciliation engine

- [ ] Exact-match reconciliation
- [ ] Reference-number reconciliation
- [ ] Fuzzy amount/date/vendor reconciliation
- [ ] Duplicate detection
- [ ] Transfer matching
- [ ] Document-to-transaction matching
  - 2026-05-30 partial evidence: document-match proposals remain review-only,
    and approval now revalidates the target document and related transaction
    against the transaction account entity before creating confirmed evidence.
    Unassigned documents are scoped on approval; documents assigned to a
    different entity are rejected. Covered by
    `reconciliationServiceApproveDocumentMatchProposalConfirmsEvidenceAndResolves`
    and `reconciliationServiceRejectsCrossEntityDocumentMatchApproval`.
- [ ] Statement-to-transaction coverage linking
- [ ] Manual accept/reject override flows
- [ ] Merge safety rules
- [ ] Reconciliation confidence scoring
- [ ] Reconciliation diagnostics
- [ ] Reconciliation regression tests

---

## 13. Statement coverage and missingness engine

### Statement coverage
- [ ] Account coverage cadence model
- [ ] Monthly cadence support
- [ ] Quarterly cadence support
- [ ] Annual cadence support
- [ ] Ad-hoc cadence support
- [ ] Coverage timeline visualization
- [ ] Missing period detection
- [ ] Partial coverage detection
- [ ] Imported-but-unverified state
- [ ] Satisfied state

### Missing evidence
- [ ] Requirement rule engine
- [ ] Transaction-class-based evidence rules
- [ ] Entity-type-based evidence rules
- [ ] Tax-year-aware evidence rules
- [ ] Filing-mode-aware evidence rules
- [ ] User policy overrides

### Missingness outputs
- [ ] Missing invoice alerts
- [ ] Missing receipt alerts
- [ ] Missing monthly statement alerts
- [ ] Missing annual tax statement alerts
- [ ] Missing salary certificate alerts
- [ ] Missing pillar 2 / pillar 3a certificate alerts
- [ ] Missing health-insurance certificate alerts
- [ ] Missing deductible-medical-cost evidence alerts
- [ ] Filing blocker vs soft-warning severity model
- [ ] Issue/task generation from missingness results

---

## 14. Inbox and task system

- [ ] Unified inbox for new imports
- [ ] Queue for uncategorized transactions
- [ ] Queue for unmatched documents
- [ ] Queue for low-confidence AI suggestions
- [ ] Queue for missingness issues
- [ ] Bulk review actions
- [ ] Accept/reject suggestion actions
- [ ] Snooze/defer task support
- [ ] Priority/severity indicators
- [ ] “Why is this here?” explanations

---

## 15. Search and analytics read models

- [x] Global search across documents, transactions, counterparties, and issues
  - 2026-05-30 evidence: `SQLiteSearchIndex.search(workspaceId:query:limit:)`
    returns typed `GlobalSearchHit` rows scoped to a workspace. Migration
    `v14_global_search` maintains external-content FTS records for documents,
    transactions, counterparties, and issues through triggers and backfill.
    Covered by
    `workspaceGlobalSearchFindsDocumentsTransactionsCounterpartiesAndIssues`;
    `workspaceGlobalSearchStaysBoundedOnLargerWorkspace` seeds more than 5,000
    persisted searchable records and verifies bounded FTS results for document,
    transaction, counterparty, and issue hits within a one-second query budget;
    `evidenceRefreshIsIdempotent` also verifies database health after issue
    indexing and re-indexing. `WorkspaceShellView` exposes those hits through a
    top-level toolbar search popover, and
    `testGlobalSearchFindsAndNavigatesWorkspaceRecords` verifies app-model
    search plus navigation for document, transaction, counterparty, and issue
    results.
- [x] Read-only reporting views for AI and UI
  - 2026-05-30 evidence: migration `v13_reporting_views` adds the reporting
    view layer, `AlpenLedgerDatabaseMigrations.requiredViews` makes it part of
    database health, and `workspaceReportingViewsExposeReadOnlyScopedSummaries`
    covers scoped summary output plus write rejection.
- [x] `vw_spend_by_month`
- [x] `vw_cashflow_by_entity`
- [x] `vw_missing_evidence`
- [x] `vw_statement_coverage`
- [x] `vw_tax_fact_status`
- [x] `vw_unmatched_transactions`
- [x] `vw_vat_reconciliation`
- [x] Query performance checks on realistic datasets
  - 2026-05-30 evidence: global-search performance is covered by
    `workspaceGlobalSearchStaysBoundedOnLargerWorkspace`, which seeds a larger
    persisted local workspace and verifies bounded FTS search results within a
    one-second query budget. `workspaceReportingViewsScopedLookupsAndRestoreStayBoundedOnLargerWorkspace`
    seeds a larger local workspace with statements, transactions, evidence
    links, issues, tax facts, and a VAT period; verifies reporting views,
    tax-status rows, import/reconciliation lookups, and scoped repository
    fetches inside two-second query budgets; and validates backup/restore counts
    for the same persisted volume.

---

## 16. Tax engine core

- [ ] Canonical `TaxFact` model
- [x] Tax-fact provenance storage
  - 2026-05-29 evidence: `TaxFact.provenanceRefs` round-trip through storage as
    JSON and are preserved across supersession history. Covered by
    `taxFactsRoundTripProvenanceAsJSON` and
    `taxFactRepositoryPreservesSingleCurrentVersionAfterSupersession`.
- [x] Tax-fact explanation support
  - 2026-05-29 evidence: `TaxFactExplanationService` resolves tax fact
    provenance refs to document/transaction source summaries and reports missing
    refs explicitly. Covered by
    `taxFactExplanationResolvesSupportingDocumentRefs` and
    `taxFactExplanationReportsMissingSourceRefs`.
- [ ] Rule-pack schema
- [ ] Rule-pack loading/versioning
- [ ] Jurisdiction/year selection
- [ ] Field mapping framework
- [ ] Validation rule framework
- [ ] Evidence requirement framework
- [x] Manual override handling
  - 2026-05-29 evidence: `TaxComputationService.markFactOverridden` delegates to
    the typed tax fact service, trims and stores the override reason, rejects
    blank reasons and locked periods, logs `taxFactOverridden`, and prevents
    recomputation from silently replacing overridden facts.
- [ ] Tax-engine unit tests
- [x] Tax-engine regression fixtures
  - 2026-05-30 evidence: the Zurich 2026 personal-tax fixture pack contains
    synthetic salary, health-insurance, and pillar 3a certificate text fixtures
    plus `expected-tax-facts.json`. The catalog verifier validates the pack and
    `zurichNaturalPersonFixtureImportProducesObservedFacts` compares computed
    facts against the golden expected facts.

---

## 17. Personal Tax Studio

### Core workflow
- [ ] Tax-year selection
- [ ] Canton selection
- [ ] Filing-status overview
- [ ] Requirement checklist UI
- [ ] Missing-document grouping
- [ ] Tax-fact review UI
- [ ] Field-by-field explanation inspector
- [ ] Attachment manifest
- [ ] Filing completeness report
- [ ] Filing export review screen

### Personal-tax data areas
- [ ] Income categories
- [ ] Deductions
- [ ] Assets
- [ ] Liabilities
- [ ] Household/spouse context
- [ ] Security/investment statement handling baseline
- [ ] Pension contribution handling baseline
- [ ] Health-insurance evidence handling baseline

### Export
- [ ] `eCH-0119` export generator
- [ ] `eCH-0119` schema validation
- [ ] Export diagnostics report
- [ ] Filing package bundling
- [ ] Pilot-canton completion path
- [x] Explicit “prepared vs filed” status separation
  - 2026-05-30 evidence: `FilingPackage` stores generated, finalized,
    submitted, and accepted lifecycle states separately. `Tax Studio` now
    loads persisted filing packages for the selected entity/year and renders
    package rows plus inspector details with explicit "Generated, Not Filed"
    and "Finalized, Not Filed" labels. Generated/finalized packages show a
    not-filed boundary, `submittedAt` remains nil unless a separate external
    status is recorded, and `testTaxStudioSnapshotSeparatesPreparedFilingPackagesFromFiledReturns`
    verifies the app-model review state and inspector copy.

### Future-proofing
- [ ] Keep canonical model ready for `eCH-0278`
- [ ] Keep canton-specific extension points isolated from core logic

---

## 18. Business finance and VAT

### Business finance
- [ ] Business entity settings
- [ ] Business chart-of-accounts templates
- [ ] AP/AR-lite baseline
- [ ] Supplier invoice support
- [ ] Customer invoice support
- [x] Expense evidence linking
  - 2026-05-30 evidence: `DocumentService.linkDocument` creates a confirmed
    document-to-transaction evidence link, and
    `EvidenceRefreshService.refreshExpenseEvidence` applies those links to
    sole-proprietor/business bank and card expenses. The
    `businessExpenseEvidenceLinkSatisfiesMissingEvidenceRequirement` test
    verifies a real business entity imported expense moves from an open missing
    evidence issue and pending requirement to a resolved issue and satisfied
    requirement after a receipt is linked.
- [ ] Asset register baseline
- [ ] Depreciation baseline
- [ ] Year-end pre-close checks
- [ ] Owner-draw / mixed-expense workflows

### VAT
- [x] VAT code model
  - 2026-05-30 evidence: `VATCode`, `VATCodeBook`, and
    `SwissVATCodeBook.current2026()` define deterministic Swiss VAT codes for
    output/input standard, reduced, accommodation, exempt, and outside-scope
    treatments. `swissVATCodeBookContainsCurrentOfficialRates` verifies the
    2026 code book rates.
- [x] VAT mapping on transactions/journal lines
  - 2026-05-30 evidence: `Transaction.taxCode` is persisted through migration
    `v8_transaction_vat_code` and covered by storage round-trip and migration
    tests. `JournalLine.taxCode` remains available for posted-entry mapping and
    is covered by `journalLineCarriesTaxCodeMapping`.
- [x] VAT period model
  - 2026-05-30 evidence: `VATPeriod` models entity, period dates, currency, and
    status for deterministic period previews. `VATPeriodRepository` persists
    periods through migration `v9_vat_periods`.
- [x] VAT period lock
  - 2026-05-30 evidence: `VATPeriodService` creates non-overlapping periods,
    reconciles persisted periods from the entity ledger, locks only periods
    without blocker issues, audits lock/reopen transitions, and
    `ImportPipeline` rejects statement imports that would touch a locked VAT
    period. Covered by `VATPeriodServiceTests`.
- [x] VAT reconciliation report
  - 2026-05-30 evidence: `VATPeriodComputationService` computes output tax,
    recoverable input tax, net payable tax, line-level taxable bases, and
    reconciliation issues from mapped transactions.
- [x] Consistency checks
  - 2026-05-30 evidence:
    `vatPeriodReportsMissingAndInvalidTaxCodes` covers missing/unknown VAT
    codes as blockers, and `vatPeriodWarnsWhenTaxDirectionDoesNotMatchTransactionSign`
    covers sign/code direction warnings.
- [x] `eCH-0217` export generator
  - 2026-05-30 evidence: `SwissVATDeclarationExportService` generates
    deterministic eCH-0217 v2.0.0 XML for the Swiss effective reporting method
    from a VAT reconciliation report and required UID, organisation, submission,
    reporting, business-reference, and sending-application metadata. The
    generator emits the official eCH-0217 v2 namespace, mandatory
    `generalInformation`, `turnoverComputation`, `effectiveReportingMethod`,
    and `payableTax` sections, source refs for the VAT period and included
    transactions, and is covered by
    `swissVATDeclarationExportGeneratesExpectedECH0217XML`.
- [x] `eCH-0217` validation
  - 2026-05-30 evidence: `SwissVATDeclarationExportService.validate` rejects
    unsupported jurisdictions/currencies, ruleset mismatches, reconciliation
    blockers and warnings, invalid Swiss UID metadata, missing application
    metadata, malformed XML, missing required eCH-0217 sections, invalid period
    and submission fields, and payable-tax mismatches against the reconciliation
    report. `scripts/verify-schemas.sh` separately validates the golden
    eCH-0217 export fixture against vendored official eCH XSDs with
    `xmllint --nonet`.
- [x] VAT issue surfacing in UI
  - 2026-05-30 evidence: `TaxStudioSnapshot` now carries VAT period summaries
    and reconciliation issue rows, `TaxStudioFeatureView` renders a VAT section
    with output/input/payable totals, blocker/warning badges, issue rows, and
    inspector details with source refs. `ActiveWorkspaceSession.refreshTaxStudio`
    reconciles persisted VAT periods for the selected entity/year, and
    `testTaxStudioSnapshotSurfacesPersistedVATReconciliationIssues` verifies a
    real workspace VAT period with a missing transaction tax code surfaces as a
    blocking Tax Studio VAT issue.

---

## 19. Business year-end and business tax

- [ ] Year-end closing checklist
- [ ] Draft adjusting-entry workflow
- [ ] Trial balance reporting
- [ ] Balance sheet mapping
- [ ] Profit-and-loss mapping
- [ ] Business tax canonical facts
  - 2026-05-30 partial evidence:
    `Fixtures/Tax/Business/2026/expected-business-tax-facts.json` records the
    deterministic Zurich 2026 sole-proprietor self-employment fact boundary
    currently supported by the tax adapter. `TaxComputationServiceTests` loads
    that fixture after importing the synthetic bank statement and verifies
    derived revenue, expense, and net-profit facts with transaction provenance.
    This remains open until broader year-end business-tax facts are modeled.
- [ ] `eCH-0276` export generator
- [ ] `eCH-0276` validation
- [ ] Export manifests and diagnostics
- [ ] Accountant/fiduciary review bundle
- [ ] Explicit blocker reporting for incomplete year-end states

---

## 20. Explainability, provenance, and audit

- [ ] Per-value provenance model
- [x] Ability to explain where a number came from
  - 2026-05-29 evidence: current tax facts can be explained through typed
    provenance refs with resolved source summaries and explicit missing-source
    reporting. UI review flows and chat answer provenance remain separate open
    gates.
- [ ] Ability to explain which rule produced a tax fact
- [ ] Ability to explain which evidence supports a field
- [ ] Audit log for user actions
- [ ] Audit log for import actions
- [x] Audit log for AI/agent tool calls
  - 2026-05-30 evidence: `WorkspaceAgentToolService.execute` now wraps every
    concrete agent tool invocation with sanitized `agentToolExecuted` or
    `agentToolRejected` audit events. The payload records tool name,
    side-effect class, required/granted scopes, invocation input hash,
    confirmation input hash when present, confirmation presence, result
    provenance refs, duration, and stable error codes without storing raw tool
    inputs or output JSON. Covered by
    `agentToolWorkflowAuditsSuccessfulToolExecutionWithoutRawInputOrOutput` and
    the rejected-scope assertions in
    `agentToolWorkflowRequiresScopeBeforeOpeningIssue`.
- [ ] Override history
- [ ] Review screen for proposed changes
- [x] Exportable diagnostic/audit bundle
  - 2026-05-30 evidence: `WorkspaceStorage.exportSupportBundle(to:)`
    writes a sanitized local JSON support bundle that combines database
    diagnostics with audit-log counts, actor/event/object-kind summaries, and
    recent audit-event metadata. It fingerprints event IDs, actor IDs, and
    object IDs, and excludes raw audit payloads, workspace names, absolute
    paths, workspace keys, source document contents, document filenames,
    transaction descriptions, and transaction amounts. Covered by
    `workspaceSupportBundleExportIncludesSanitizedAuditLog` and
    `testExportSupportBundleThroughWorkspaceAppModel`.

---

## 21. AI platform foundation

### Provider abstraction
- [x] `ModelProvider` abstraction
  - 2026-05-30 evidence: `ModelProvider`, `ModelProviderRequest`,
    `ModelProviderResponse`, `ModelProviderRegistry`, and
    `ModelProviderDescriptor` define provider roles, locations, capabilities,
    request source refs, output source refs, network/off-device flags,
    explicit-consent requirements, and local-first policy decisions before any
    provider can be selected or invoked. The production
    default is `local.rules`, an in-process provider descriptor that requires
    no network access and sends no data off-device. Covered by
    `ModelProviderPolicyTests`.
- [x] Local model provider integration
  - 2026-05-30 evidence: `LocalRulesModelProvider` is the concrete in-process
    local provider for the production `local.rules` descriptor. It preserves
    source refs, rejects unsupported capabilities and invalid request bounds,
    reports `sentDataOffDevice = false`, and is callable through
    `ModelProviderExecutor.productionLocalOnly`. Covered by
    `localRulesModelProviderReturnsLocalSourceBackedResponse`,
    `localRulesModelProviderRejectsUnsupportedOrInvalidRequests`, and
    `modelProviderExecutorRunsLocalProviderThroughAirGappedPolicy`.
- [ ] Optional cloud model provider integration
- [ ] Embedding provider abstraction if used
- [ ] Reranker abstraction if used
- [x] Provider capability registry
  - 2026-05-30 evidence: `ModelProviderRegistry.allowedProviders(...)`
    filters registered providers by required capabilities, privacy mode, and
    explicit consent. Tests prove unknown providers, missing capabilities,
    cloud providers in air-gapped mode, and unapproved hybrid/external
    providers are rejected before selection.

### Chat/session infrastructure
- [x] Chat session storage
  - 2026-05-30 evidence: `AgentConversation` persists local copilot sessions in
    the encrypted workspace database with workspace, active entity/year, status,
    and timestamps. `v17_agent_conversation_storage` creates
    `agentConversations`, and `WorkspaceStorage` exposes
    `AgentConversationRepository`.
- [x] Conversation history persistence
  - 2026-05-30 evidence: `AgentMessage` persists ordered user, assistant, system,
    and tool messages per conversation, including provider/prompt metadata,
    off-device flags, source refs, and timestamps. Covered by
    `agentConversationStoragePersistsHistoryRefsAndPendingApprovals`.
- [x] Local memory separation from authoritative domain facts
  - 2026-05-30 evidence: chat messages store natural-language conversation
    history separately from ledger/tax/document tables and cite authoritative
    objects only through `ObjectRef` source refs. Message text is not read back as
    a ledger, tax, or document fact. Covered by `docs/copilot-state-storage.md`
    and the storage round-trip test.
- [x] Pending-approval state handling
  - 2026-05-30 evidence: `AgentPendingApproval` stores confirmed-write review
    requests with tool name, reviewed input hash, required scopes, target refs,
    requester, pending/approved/rejected/expired status, and reviewer decision
    metadata. It only yields an `AgentToolConfirmation` after approval, binding
    that confirmation to the reviewed input hash. Covered by
    `agentConversationStoragePersistsHistoryRefsAndPendingApprovals`.
- [x] Unresolved-question tracking
  - 2026-05-30 evidence: `AgentMessage.unresolvedQuestions` persists follow-up
    questions separately from grounded answer claims, so unresolved uncertainty can
    be rendered as a blocker/question instead of being treated as a fact.
    `scripts/verify-copilot-storage.sh` covers storage plus the focused
    migration test group, including legacy proposal uncertainty metadata, and is
    included in `scripts/verify-readiness.sh`.
- [x] Privacy-mode controls
  - 2026-05-30 evidence: Settings renders an "AI & Privacy" section from the
    app privacy mode, provider registry, explicit consent settings, redaction
    policy, and approved-provider list. Local-only mode ignores off-device
    consent overrides, hybrid/external modes surface consent, redaction controls,
    and latest provider activity, and `ModelProviderExecutor` blocks off-device
    requests whose input scope exceeds the configured redaction policy. Covered by
    `testSettingsSnapshotSurfacesHybridConsentAndRedactionControls` and
    `modelProviderPolicyRequiresRedactionControlsForOffDeviceInputScopes`.

### Privacy modes
- [x] Air-gapped mode
  - 2026-05-30 evidence: the app runtime defaults to local-only, unsupported
    cloud/offline privacy values resolve to local-only, local-only maps to
    `ModelProviderPrivacyMode.airGapped`, Settings surfaces the air-gapped
    provider state, and `ModelProviderExecutor` blocks network/off-device cloud
    providers before invocation in air-gapped mode. Covered by
    `testPrivacyModeDefaultsToLocalOnlyAndRejectsCloudRuntime`,
    `testSettingsSnapshotSurfacesLocalOnlyPrivacyMode`, and
    `modelProviderExecutorRejectsCloudProviderBeforeInvocationInAirGappedMode`.
- [ ] Hybrid mode
  - 2026-05-30 partial evidence: the app runtime parses `.hybrid`, Settings
    surfaces network/off-device consent plus redaction controls, and the
    model-provider policy blocks off-device input scopes that exceed the
    configured redaction policy. This remains open until concrete cloud provider
    integration is implemented.
- [ ] External-assistant mode
  - 2026-05-30 partial evidence: the model-provider policy models
    `.externalAssistant`, the app runtime parses it, and per-provider approval
    plus redaction policy enforcement still applies. This remains open until an
    MCP/Codex-style adapter and scoped external access controls exist.
- [x] Explicit consent and redaction settings
  - 2026-05-30 evidence: `ModelProviderConsent` carries network consent,
    off-device consent, approved provider IDs, and
    `ModelProviderRedactionPolicy`. Local-only runtime mode resolves to
    `.none`, while hybrid/external modes can be configured through runtime
    settings. Settings renders these controls and provider blocked/available
    states. Covered by
    `testPrivacyModeDefaultsToLocalOnlyAndRejectsCloudRuntime`,
    `testSettingsSnapshotSurfacesHybridConsentAndRedactionControls`, and
    `modelProviderPolicyRequiresRedactionControlsForOffDeviceInputScopes`.
- [x] Network activity visibility to user
  - 2026-05-30 evidence: `ModelProviderExecutor` records provider activity
    snapshots for running, completed, blocked, and failed executions, including
    provider, capability, input scope, privacy mode, network/off-device flags,
    sent-off-device result, and block/error reason. Settings renders the latest
    activity with network and off-device status. Covered by
    `modelProviderActivityLogRecordsRunningCompletedAndBlockedExecutions` and
    `testSettingsSnapshotSurfacesHybridConsentAndRedactionControls`.

---

## 22. Tool bus and safe finance chat

- [x] Typed tool registry
  - 2026-05-29 evidence: `AgentToolRegistry.productionDefaults` declares the
    current planned internal tool surface with typed side effects, scopes,
    provenance requirement, and confirmation requirement. `AgentToolExecutor`
    consumes this registry before a tool handler is allowed to run.
- [x] `finance.list_accounts`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `finance.list_accounts` through `AgentToolExecutor`, requires
    `.financeRead`, returns account summaries scoped by entity, and returns
    financial-account provenance. Covered by
    `agentToolWorkflowListsFinancialAccountsThroughExecutor`.
- [x] `finance.search_transactions`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `finance.search_transactions` through `AgentToolExecutor`, requires
    `.financeRead`, bounds result limits, validates date and amount ranges,
    rejects cross-entity account IDs, returns scoped transaction summaries, and
    returns transaction provenance. Covered by
    `agentToolWorkflowSearchesTransactionsThroughExecutorWithScopedProvenance`.
- [x] `finance.account_summary`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `finance.account_summary` through `AgentToolExecutor`, requires
    `.financeRead`, validates account ownership for the requested entity,
    returns bounded account, balance, transaction, and statement-import
    summaries, and returns financial-account, statement-import, and transaction
    provenance. Covered by
    `agentToolWorkflowExplainsAccountSummaryThroughExecutorWithProvenance`.
- [x] `docs.search`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes `docs.search`
    through `AgentToolExecutor`, requires `.documentsRead`, bounds result
    limits, supports entity/type/query filters, validates provided entity scope,
    limits unscoped searches to unassigned intake documents, returns document
    summaries without raw document text, and returns document provenance.
    Covered by `agentToolWorkflowSearchesDocumentsThroughExecutorWithProvenance`.
- [x] `docs.get_summary`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `docs.get_summary` through `AgentToolExecutor`, requires `.documentsRead`,
    validates the document exists, bounds snippet length, returns a truncated
    text snippet instead of unrestricted document contents, and returns document
    provenance. Covered by
    `agentToolWorkflowGetsDocumentSummaryThroughExecutorWithBoundedSnippet`.
- [x] `issues.list_open`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `issues.list_open` through `AgentToolExecutor`, requires `.reconcileRead`,
    returns open issue summaries with related object refs, and returns issue
    provenance. Covered by
    `agentToolWorkflowListsOpenIssuesThroughExecutorWithProvenance`.
- [x] `reconcile.statement_coverage`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `reconcile.statement_coverage` through `AgentToolExecutor`, requires
    `.reconcileRead`, validates account/entity scoping, reports pending or
    satisfied statement-coverage requirements with linked issue state, and
    returns financial-account, requirement, issue, and support provenance.
    Covered by
    `agentToolWorkflowReportsStatementCoverageThroughExecutorWithProvenance`.
- [x] `tax.list_requirements`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `tax.list_requirements` through `AgentToolExecutor`, requires `.taxRead`,
    validates entity/tax-year scope, supports requirement code/status filters
    and bounded limits, and returns requirement provenance. Covered by
    `agentToolWorkflowListsTaxRequirementsThroughExecutorWithProvenance`.
- [x] `tax.preview_status`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `tax.preview_status` through `AgentToolExecutor`, requires `.taxRead`,
    validates entity/tax-year scope, returns current tax facts, pending
    requirements, open issues, and readiness counts, and returns entity,
    tax-year, tax-fact, requirement, and issue provenance. The app injects
    `TaxValidationService` so expected concept checks come from the
    deterministic tax engine. Covered by
    `agentToolWorkflowPreviewsTaxStatusThroughExecutorWithProvenance`.
- [x] `tax.explain_fact`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `tax.explain_fact` through `AgentToolExecutor`, requires `.taxRead`,
    validates fact/entity/tax-year scope, resolves supporting document and
    transaction refs without inventing missing sources, reports unresolved
    source refs explicitly, and returns tax-fact/source provenance. Covered by
    `agentToolWorkflowExplainsTaxFactThroughExecutorWithProvenance`.
- [x] `audit.trace_object`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `audit.trace_object` through `AgentToolExecutor`, requires `.auditRead`,
    validates the target object ref and bounded result limit, returns bounded
    audit-event rows in reverse chronological order, and returns target/audit
    event provenance. Covered by
    `agentToolWorkflowTracesAuditObjectThroughExecutorWithProvenance` and
    `agentToolWorkflowRejectsAuditTraceWithInvalidLimit`.
- [x] `tax.propose_override_reason`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `tax.propose_override_reason` through `AgentToolExecutor`, requires
    `.taxPropose`, validates the tax fact exists, is current, and belongs to the
    requested entity/tax year, rejects locked tax years, validates
    reason/rationale/confidence bounds, and creates only a
    `taxOverrideReview` proposal. It does not mutate the authoritative
    `TaxFact` or set an override reason. Covered by
    `agentToolWorkflowProposesTaxOverrideReasonWithoutMutatingTaxFact` and
    `agentToolWorkflowRejectsTaxOverrideProposalForMissingFact`.
- [x] `rules.accept_override`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `rules.accept_override` through `AgentToolExecutor`, requires
    `.rulesWrite`, and is rejected before the handler runs unless a matching
    explicit `AgentToolConfirmation` is provided. The handler validates
    entity/tax-year/fact scope, current tax-fact state, open tax-year status,
    optional pending `taxOverrideReview` proposal target, and bounded override
    and approval reasons. It mutates only the confirmed `TaxFact` override
    status/reason/updated timestamp, resolves the linked proposal when present,
    and writes user-attributed tax-fact/proposal audit events. Covered by
    `agentToolWorkflowAcceptsTaxOverrideWithExplicitConfirmation` and
    `agentToolWorkflowRejectsTaxOverrideAcceptanceWithoutConfirmation`.
- [x] `ledger.propose_mapping`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `ledger.propose_mapping` through `AgentToolExecutor`, requires
    `.ledgerPropose`, validates the target transaction/account, category
    existence and entity ownership, bounded tax-code/rationale fields, and
    confidence range, then creates only a `transactionMappingReview` proposal.
    It does not update transaction tax codes or category assignments. Covered
    by `agentToolWorkflowProposesLedgerMappingWithoutMutatingTransaction` and
    `agentToolWorkflowRejectsLedgerMappingForForeignCategory`.
- [x] `ledger.propose_split`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `ledger.propose_split` through `AgentToolExecutor`, requires
    `.ledgerPropose`, validates the target transaction and account, checks
    split-line count, non-zero amounts, exact sum to the transaction amount,
    category existence and entity ownership, memo/tax-code bounds, rationale,
    and confidence range, then creates only a `transactionSplitReview`
    proposal. It does not create, update, or delete transactions. Covered by
    `agentToolWorkflowProposesLedgerSplitWithoutMutatingTransaction` and
    `agentToolWorkflowRejectsLedgerSplitWhenLinesDoNotBalance`.
- [x] `closing.propose_accrual`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `closing.propose_accrual` through `AgentToolExecutor`, requires
    `.closingPropose`, validates entity/tax-year scope, open tax-year status,
    effective date, bounded memo/rationale/confidence fields, ledger-account
    ownership, line-side validity, and balanced debit/credit totals, then
    creates only a `closingAccrualReview` proposal with a draft journal-entry
    preview. It does not post journal entries or mutate ledger accounts.
    Covered by `agentToolWorkflowProposesClosingAccrualWithoutPostingJournalEntry`
    and `agentToolWorkflowRejectsClosingAccrualWhenUnbalanced`.
- [x] `ledger.apply_draft_entry`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `ledger.apply_draft_entry` through `AgentToolExecutor`, requires
    `.ledgerWrite`, and is rejected before mutation without explicit
    confirmation. The handler validates entity/tax-year scope, open tax-year
    status, effective date, entry-number/memo/line bounds, ledger-account
    ownership, line-side validity, balanced debit/credit totals, and optional
    pending `closingAccrualReview` proposal target. It persists a posted
    journal entry and journal lines, records reviewer identity/time, resolves
    the linked proposal when present, and writes user-attributed
    journal-entry/proposal audit events. Covered by
    `agentToolWorkflowAppliesDraftJournalEntryWithExplicitConfirmation`,
    `agentToolWorkflowRejectsDraftJournalEntryWithoutConfirmation`, and
    `agentToolWorkflowRejectsDraftJournalEntryForLockedTaxYear`.
- [x] `entities.merge_counterparties`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `entities.merge_counterparties` through `AgentToolExecutor`, requires
    `.entityWrite`, and is rejected before mutation without explicit
    confirmation. The handler validates entity scope, active source/target
    counterparties, optional pending `counterpartyMergeReview` proposal refs,
    bounded reviewer fields, then marks the source counterparty merged into the
    target while preserving the source record and imported transaction text.
    It writes user-attributed counterparty/proposal audit events and returns
    source/target/entity provenance. Covered by
    `agentToolWorkflowMergesCounterpartiesWithExplicitConfirmation` and
    `agentToolWorkflowRejectsCounterpartyMergeWithoutConfirmation`.
- [x] `exports.generate_package`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `exports.generate_package` through `AgentToolExecutor`, requires
    `.exportsGenerate`, validates export format and bounded metadata, checks
    entity/tax-year/VAT-period scope, delegates deterministic artifact
    generation through a typed provider, rejects blocker-bearing provider
    results, stores the generated artifact in the encrypted blob store, and
    creates a non-finalized `FilingPackage` with status `generated`. The app
    wires this provider to `SwissVATDeclarationExportService` for eCH-0217 VAT
    XML. Covered by `agentToolWorkflowGeneratesExportPackageDraftArtifact` and
    `agentToolWorkflowRejectsExportPackageGenerationForMissingVATPeriod`.
- [x] `exports.finalize_package`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `exports.finalize_package` through `AgentToolExecutor`, requires
    `.exportsGenerate`, and is rejected before mutation without explicit
    confirmation. The handler validates entity/tax-year/package scope, rejects
    filed tax years, requires a generated package, verifies the reviewed
    snapshot hash against the encrypted artifact blob, sets only finalized
    package status/timestamp/reviewer fields, leaves `submittedAt` nil, and
    writes a user-attributed package finalization audit event. Covered by
    `agentToolWorkflowFinalizesExportPackageWithExplicitConfirmation`,
    `agentToolWorkflowRejectsExportFinalizationWithoutConfirmation`, and
    `agentToolWorkflowRejectsExportFinalizationForSnapshotMismatch`.
- [x] `exports.validate`
  - 2026-05-30 evidence: `WorkspaceAgentToolService` executes
    `exports.validate` through `AgentToolExecutor`, requires
    `.exportsGenerate`, validates entity/tax-year/VAT-period scope, bounds
    metadata fields, returns deterministic validation issues with
    entity/tax-year/VAT-period/source provenance, and does not create filing
    packages or export artifacts. The app wires this tool to the Swiss
    eCH-0217 VAT export validator. Covered by
    `agentToolWorkflowValidatesExportThroughExecutorWithProvenance` and
    `agentToolWorkflowRejectsExportValidationForMissingVATPeriod`.
- [ ] Safe argument validation on all tools
  - 2026-05-30 partial evidence: concrete handlers now validate required
    scopes through `AgentToolExecutor`; issue writes validate bounded
    fingerprints/summaries, entity/tax-year scope, and scoped object/related
    refs before mutation; ledger mapping proposals validate
    transaction/account scope, category ownership, bounded tax-code/rationale
    fields, and confidence range; ledger split proposals validate transaction/account
    scope, exact split totals, category ownership, line fields, rationale, and
    confidence range; closing accrual proposals validate entity/tax-year scope,
    open periods, effective dates, ledger-account ownership, balanced journal
    lines, field bounds, and confidence range; export package generation
    validates export format, metadata bounds, entity/tax-year/VAT-period scope,
    artifact metadata, and blocker-free provider results; export validation validates entity/tax-year/VAT-period
    scope and bounded export metadata; document-match proposals validate target existence,
    assigned document/transaction entity boundaries through the transaction
    account, rationale, and confidence range; tax override proposals validate existing
    current tax-fact scope, open tax year, reason/rationale bounds, and
    confidence range; counterparty merges validate entity scope, active
    source/target identities, optional merge-review proposal refs, and
    reviewer fields; audit tracing validates bounded limits and resolves
    target refs to workspace/unassigned or matching entity scope before reading
    payload previews; finance/document/reconciliation/tax read-only tools
    validate limits, ranges, snippet bounds, query length, fact/entity/tax-year
    scope, and entity/account scoping. 2026-05-30 hardening: read-only
    finance/document/reconciliation/issue tools now reject missing entity scope
    before returning empty results, so agent answers cannot cite non-existent
    context refs as provenance. Document searches now limit unscoped access to
    unassigned intake documents, and document summaries require matching entity
    scope for entity-assigned documents while still permitting unassigned intake
    documents for triage. Audit tracing now rejects entity-owned target refs
    when entity scope is missing or mismatched and validates evidence-link and
    audit-event refs through repository lookups before tracing. Covered by
    `agentReadOnlyToolsRejectMissingEntityScopeBeforeReturningEmptyProvenance`,
    `agentToolWorkflowSearchesDocumentsThroughExecutorWithProvenance`, and
    `agentToolWorkflowGetsDocumentSummaryThroughExecutorWithBoundedSnippet`,
    `agentToolWorkflowTracesAuditObjectThroughExecutorWithProvenance`, and
    `agentToolWorkflowRejectsAuditTraceOutsideEntityScope`.
    This remains open until every planned tool has a concrete handler and
    validation test.
- [x] Tool-result provenance rendering
  - 2026-05-30 evidence: Inbox inspectors now carry dedicated source rows for
    issue, proposal, and import-job selections. Proposal inspectors render the
    agent proposal, target ref, and related ref as source rows using shared
    provenance titles/icons instead of only embedding raw refs in text details.
    Covered by `testInboxProposalInspectorOffersApprovalForDocumentMatch`.
- [x] Concrete issue/proposal tool execution
  - 2026-05-29 evidence: `WorkspaceAgentToolService` exposes
    `finance.list_accounts`, `finance.search_transactions`,
    `finance.account_summary`, `docs.search`, `docs.get_summary`,
    `reconcile.statement_coverage`, `issues.list_open`,
    `tax.list_requirements`, `tax.preview_status`, `tax.explain_fact`,
    `audit.trace_object`, `tax.propose_override_reason`,
    `rules.accept_override`, `ledger.propose_mapping`, `ledger.propose_split`,
    `closing.propose_accrual`, `ledger.apply_draft_entry`,
    `entities.merge_counterparties`, `exports.generate_package`,
    `exports.finalize_package`, `exports.validate`, `issues.open_or_update`,
    and `docs.propose_match` through
    `AgentToolExecutor`. Tests prove missing scopes reject before mutation,
    read-only tools return scoped outputs with provenance, issue open/update
    returns issue/object provenance and audit events while rejecting
    cross-entity object refs, document-match proposals
    persist related transaction refs while returning proposal/document/transaction
    provenance without creating confirmed evidence links, and tax override
    proposals return proposal/tax-fact provenance without changing tax-fact
    values. Audit tracing returns target/audit-event provenance without exposing
    unrestricted database access. Ledger mapping and split proposals return
    proposal/transaction/account/category provenance without changing
    transaction rows. Closing accrual proposals return
    proposal/entity/tax-year/ledger-account/source provenance with a draft
    journal-entry preview and no posted entry. Draft journal-entry application
    returns journal-entry/entity/tax-year/proposal/line/account/source
    provenance, persists only balanced posted entries after explicit approval,
    and is rejected without confirmation or for locked periods. Counterparty
    merge returns source/target/entity provenance, marks duplicate
    counterparty identities merged after explicit approval, and preserves
    source records plus imported transaction text. Export package
    generation returns filing-package/entity/tax-year/VAT-period/source
    provenance, stores a draft artifact blob, and does not finalize or submit
    the package. Export finalization returns filing-package/entity/tax-year
    provenance, verifies the reviewed artifact hash, marks the package
    finalized without submission, and is rejected without explicit confirmation.
    Export validation returns
    validation issues with entity/tax-year/VAT-period/source provenance without
    creating filing packages or artifacts. Confirmed tax override acceptance
    returns entity/tax-year/tax-fact/proposal/source provenance and is rejected
    without explicit confirmation. Confirmed-write approvals are bound to the
    reviewed invocation input hash, so a reviewer approval for one draft payload
    cannot be reused for a different payload of the same tool. The service also logs
    sanitized agent-tool success/rejection audit events for these concrete tool
    calls.
- [x] No unrestricted raw SQL access for the model
  - 2026-05-30 evidence: `AgentToolRegistry.validateSafetyPolicy()` rejects
    tools that allow unrestricted file access, raw SQL, or shell execution;
    production defaults pass the policy. `AgentToolExecutor` rejects an unsafe
    registry before invoking any tool handler, and
    `scripts/verify-agent-tool-safety.sh` runs this focused gate inside the
    readiness script.

---

## 23. Agent system

### Router / planner
- [x] Router Agent
  - 2026-05-30 evidence: `AgentRouter` deterministically classifies user
    messages into v1 intents, selects narrow specialist responsibilities, and
    returns no plan for unsupported raw-SQL/shell/destructive requests. Covered
    by `AgentRouterTests` and documented in `docs/agent-routing.md`.
- [x] Intent-to-tool/agent planning
  - 2026-05-30 evidence: router plans are built only from
    `AgentToolRegistry.productionDefaults`, return registered tool names,
    required scopes, selected specialists, unavailable requested tools, and
    rationale without executing tools or mutating state. Tests cover missing
    tax evidence, expense evidence, VAT, business-tax export, provenance,
    reconciliation, transaction classification, document intake, and general
    finance routes.
- [x] Context handling for active entity/year/canton
  - 2026-05-30 evidence: `AgentRouterContext` carries active workspace,
    entity, tax year, and canton context. Plans include object refs for known
    context and ask a targeted clarification question when an entity or tax
    year is required but missing.

### Specialists
- [ ] Intake & Triage Agent
- [ ] Document Extraction Agent
- [ ] Transaction Classification Agent
- [ ] Reconciliation Agent
- [ ] Missing Evidence Agent
- [ ] Personal Tax Agent
- [ ] VAT Agent
- [ ] Business Year-End Agent
- [ ] Filing Packager Agent
- [ ] CFO / Q&A Agent
- [ ] Explainability & Audit Agent

### Guardrails
- [x] Read-only vs proposal vs confirmed-write permissions
  - 2026-05-29 evidence: `AgentToolSideEffect` separates `readOnly`,
    `proposal`, `issueUpdate`, `draftArtifact`, and `confirmedWrite` tools.
    Production default confirmed-write tools require explicit user
    confirmation, and `AgentToolExecutor` enforces required scopes,
    confirmation, and tool-result provenance before returning a tool result.
- [ ] Confidence protocol
  - 2026-05-30 partial evidence: concrete proposal tools now persist and return
    `confidence`, `rationale`, `missingFields`, `question`, and
    `requiresManualReview` metadata on `AgentProposalToolOutput`, with
    provenance returned by the executor result. Migration
    `v15_agent_proposal_uncertainty_metadata` adds these fields to stored
    proposals. This remains open until extraction/classification specialist
    outputs use the same schema end to end.
- [ ] Escalation on uncertainty
  - 2026-05-30 partial evidence: low-confidence pending document-match
    proposals no longer get a direct Approve action in the Inbox inspector.
    They show "Manual review required before approval" and leave only Open,
    Reject, and manual Link Transaction actions. Low-confidence agent-tool
    proposals now auto-fill a targeted reviewer question when the caller does
    not provide one, persist unresolved fields, and require manual review.
    Covered by `agentToolWorkflowLowConfidenceDocumentMatchEscalatesWithQuestion`,
    `testLowConfidenceDocumentMatchDoesNotOfferDirectApproval`, and
    `testManualReviewProposalShowsQuestionAndBlocksDirectApproval`. This
    remains open until all specialist-agent workflows emit targeted questions
    and unresolved fields through the same protocol.
- [ ] No silent financial mutations
  - 2026-05-29 partial evidence: `AgentToolExecutor` rejects confirmed-write
    tool invocations without explicit matching approval before the handler can
    run, and 2026-05-30 coverage binds that approval to the invocation input
    hash to prevent stale confirmation replay. `WorkspaceAgentToolService`
    covers concrete low-risk issue/proposal workflows, keeps ledger split
    suggestions as proposals without changing transaction rows, posts draft
    journal entries only after explicit approval,
    marks counterparty identities merged only after explicit approval while
    preserving imported transaction text, and keeps document-match suggestions
    as proposals rather than confirmed evidence links; manual document links and
    `approveDocumentMatchProposal` reject cross-entity evidence refs, scope
    unassigned documents to the transaction entity on confirmation, and confirm
    the link only from an explicit reviewer action, and
    `revokeDocumentMatchProposalApproval` reverses that approval by marking the
    evidence link revoked and writing proposal/evidence audit events. This
    remains open until all concrete financial mutation tools are implemented and
    routed through the executor.
- [ ] No invented tax facts
  - 2026-05-30 partial evidence: concrete tax agent tools are read-only or
    proposal-only. `tax.propose_override_reason` requires an existing current
    tax fact in the requested entity/tax year and rejects missing facts before a
    proposal can be created; its tests prove it does not create or mutate tax
    facts. This remains open until the full Personal Tax Agent and filing
    workflow are implemented through the same deterministic-engine boundary.
- [x] Agent audit logging
  - 2026-05-30 evidence: concrete workspace agent tool invocations now
    emit sanitized `agentToolExecuted` and `agentToolRejected` audit events.
    Those events include input/confirmation hashes for review correlation while
    excluding raw tool inputs and outputs.
  - 2026-05-30 evidence: `AgentRunTrace` persists the orchestration record for
    a user turn, including router intent, selected specialists, planned tools,
    unavailable tools, required scopes, context refs, model/provider metadata,
    prompt template, input scope, off-device status, tool-call outcomes, and
    approval decisions. Migration and storage tests cover the `agentRuns`
    table, round-tripping run traces, and reviewer decision metadata.
- [x] Agent evaluation harness
  - 2026-05-30 evidence: `AgentEvaluationHarness` evaluates checked-in routing
    cases from `config/agent-evaluations.json`, including expected intents,
    specialists, registered tool plans, forbidden tool plans, missing-context
    clarification, and unsafe-request rejection. `scripts/verify-agent-evaluations.sh`
    runs the focused harness tests and is included in `scripts/verify-readiness.sh`.
    Documented in `docs/agent-evaluations.md`.

---

## 24. Copilot user experience

- [x] Copilot main screen
  - 2026-05-30 evidence: the app shell now includes a Copilot section backed by
    `CopilotFeatureView` and `CopilotSnapshot`. The screen renders active
    entity/year/canton context, suggested question cards, and deterministic
    answer cards for tax readiness, expense evidence, statement coverage, VAT
    explanation, and business export readiness. Covered by
    `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext`.
- [x] Inline answers with source references
  - 2026-05-30 evidence: Copilot answer cards render claim-level answer rows,
    claim kind indicators, and clickable source rows built from `ObjectRef`
    provenance. `performCopilotAction` routes source refs into Inbox, Ledger,
    Documents, Tax Studio, and imported-statement contexts. Covered by
    `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext` and
    `testPerformCopilotActionDeepLinksToSourceObjects`.
- [x] “Turn answer into task” action
  - 2026-05-30 evidence: Copilot answer cards now expose a secondary
    `Turn Into Task` action. The action creates an explicit open
    `copilotTask` issue from the source-backed answer, keeps the source ref as
    the task object, refreshes the Inbox, and selects the new task for review.
    Covered by `testCopilotAnswerCanCreateInboxTask`, which also verifies the
    audited `issueOpened` event, and by
    `testCopilotAnswerCanCreateInboxTaskFromButton` for the native button flow.
- [x] Review UI for proposals
  - 2026-05-29 evidence: the Inbox proposal inspector renders target/related
    refs, decision metadata, and explicit Approve/Reject/Revoke actions for
    actionable document-match proposals.
    `testInboxProposalInspectorOffersApprovalForDocumentMatch` and
    `testInboxProposalInspectorOffersRevocationForApprovedDocumentMatch` cover
    the approval and revocation action surfaces.
- [x] Suggestion confidence display
  - 2026-05-30 evidence: pending proposal rows in Overview and Inbox now show
    high/medium/low confidence labels with percentages and matching status
    tones. The Inbox proposal inspector renders the same confidence band and a
    review path for reviewer context. Covered by
    `testInboxProposalConfidenceBandsAreVisibleInRowsAndInspector`.
- [x] Follow-up question flow
  - 2026-05-30 evidence: `CopilotSnapshot.AnswerCard` now carries typed
    `FollowUpQuestion` rows with source refs and routed actions, and
    `CopilotFeatureView` renders them inside answer cards. The current Copilot
    answers generate targeted follow-up questions for pending tax requirements,
    missing tax facts, unsupported business expenses, missing statement
    coverage, VAT reconciliation issues, and blocked business-export readiness.
    `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext` verifies the
    follow-up IDs, non-empty provenance, and Inbox/Tax Studio routing.
- [x] Entity/year/canton context awareness
  - 2026-05-30 evidence: Copilot snapshot subtitles and context tiles use the
    selected entity, tax year, and canton, and preserve those IDs when opening
    Tax Studio from answer actions. Covered by
    `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext`.
- [ ] Example workflows for:
  - [x] “What is missing for my 2025 Zurich return?”
  - [x] “Which business expenses lack invoices?”
  - [x] “Why is my VAT due so high this quarter?”
  - [x] “Which accounts still miss monthly extracts?”
  - [x] “Prepare my business tax export”
  - 2026-05-30 evidence: the source-backed Copilot main screen covers the
    return-readiness, expense-evidence, statement-coverage, VAT, and draft
    business-export examples for the selected entity/year/canton. This parent
    item remains open until the examples are supported through the eventual
    free-form Q&A flow.

---

## 25. Main product surfaces

### Overview
- [ ] Overview/home screen
- [ ] Key status summary
- [ ] Open issues snapshot
- [ ] Upcoming tasks snapshot

### Accounts and transactions
- [ ] Accounts list/detail
- [ ] Transactions list/detail
- [ ] Filters and saved views
- [ ] Reconciliation status visuals

### Documents
- [ ] Document vault screen
- [ ] Document search
- [ ] Document detail inspector
- [ ] Evidence links view

### Tax Studio
- [ ] Personal tax workflow UI
- [ ] Filing readiness UI
- [ ] Export/package UI

### Business
- [ ] Business books view
- [ ] VAT period UI
  - 2026-05-30 partial evidence: Tax Studio now renders read-only VAT period
    summaries and reconciliation issues for persisted VAT periods. This remains
    open until users can create/review/manage VAT periods and exports from a
    complete business UI flow.
- [ ] Year-end UI
- [ ] Business tax export UI

### Settings/help
- [ ] Settings screen
- [x] AI/privacy controls
  - 2026-05-30 evidence: Settings renders AI/privacy mode copy, network/cloud
    status, network and off-device consent, redaction policy, approved provider
    count, latest provider activity, and per-provider availability/block reasons.
    Covered by
    `testSettingsSnapshotSurfacesLocalOnlyPrivacyMode` and
    `testSettingsSnapshotSurfacesHybridConsentAndRedactionControls`.
- [x] Import defaults
  - 2026-05-30 evidence: Settings now exposes a statement-import default
    account picker for the current workspace. `WorkspaceUIPreferencesStore`
    persists the preferred account per workspace, `WorkspaceAppModel` uses the
    saved account before falling back to the selected ledger account or first
    available account for statement imports and retry imports, and
    `testWorkspaceUIPreferencesStorePersistsStatementImportDefaultPerWorkspace`
    plus `testStatementImportDefaultRoutesImportsAndPersistsAcrossReopen`
    verify persistence, Settings state, routing to the preferred account, and
    reopen behavior.
- [x] Backup/restore controls
  - 2026-05-29 evidence: File menu and Settings controls call the
    `WorkspaceAppModel` backup/restore actions; Settings includes protection
    copy for backup bundles that contain the workspace encryption key. Settings
    also exposes a backup integrity check action and renders the latest
    blocker/warning report.
- [x] Help/about/onboarding entry points
  - 2026-05-30 evidence: users can open the help/onboarding guide from the
    first-run workspace chooser, Settings, and the app Help menu. The default
    macOS app menu still carries the app-level About entry, while the product
    guide is handled by the native `HelpCenterView` sheet.

---

## 26. Settings, backup, and data portability

- [ ] Settings architecture
- [x] Local backup creation
  - 2026-05-29 evidence: `WorkspaceStorageManager.createBackup(for:at:)` and
    `WorkspaceService.createBackup(for:at:)` create a local backup bundle with
    `backup.json`, a `workspace/` copy, and `workspace.key`. File menu and
    Settings controls are wired through `WorkspaceAppModel`.
  - 2026-05-30 evidence: backup creation now writes into a hidden sibling
    staging directory and moves the complete bundle to the final selected path
    only after the workspace copy, key, hashes, and manifest are complete. If
    creation fails, staged artifacts are removed and the final path is left
    absent. Covered by
    `workspaceBackupCreationCleansUpStagedBundleWhenKeyLoadFails`.
- [x] Local backup restore
  - 2026-05-29 evidence: `WorkspaceStorageManager.restoreBackup(from:)` and
    `WorkspaceService.restoreBackup(from:)` restore a backup into a new local
    workspace root, rewrite the manifest root path, restore the key, log audit
    events, and update recent workspaces. File menu and Settings controls are
    wired through `WorkspaceAppModel`.
- [x] Backup integrity verification
  - 2026-05-29 evidence: `WorkspaceStorageManager.validateBackup(at:)` checks
    the backup manifest version, workspace key presence, workspace manifest
    presence, workspace ID consistency, excluded temp paths, and file hashes for
    the workspace copy and `workspace.key`. Tampered hashed files are reported
    as blocking integrity issues and restore rejects them before opening. The
    Settings backup section can check a backup bundle and show the latest
    integrity status, warning/blocker rows, and affected paths.
- [ ] Workspace export/import
- [ ] Data retention controls
  - 2026-05-30 partial evidence: document retention now prefers archive over
    destructive delete. Archived documents keep the encrypted source blob and
    audit trail, are hidden from active document/search/agent surfaces, and can
    be restored by explicit re-import of the same source file or by reviewer
    action in the Documents archived view. Active filing and evidence
    references block archival. This remains open until broader retention
    policies and user-configurable retention windows are implemented.
- [x] Local log export for support
  - 2026-05-30 evidence: File menu and Settings can export a sanitized support
    bundle JSON report with database diagnostics plus audit-log summaries and
    recent event metadata. It intentionally omits raw audit payloads, raw actor
    IDs, raw object IDs, source documents, document names, transaction text,
    workspace names, absolute paths, amounts, and encryption keys.
- [x] Privacy explanation copy
  - 2026-05-30 evidence: Settings explains local-only, hybrid, and
    external-assistant AI/privacy modes and documents the enforcement model in
    `docs/ai-privacy-controls.md`.
- [x] Redaction controls for cloud AI mode
  - 2026-05-30 evidence: `ModelProviderRedactionPolicy` limits off-device
    requests to metadata-only or redacted-snippet scopes and blocks full
    workspace data from off-device providers. Covered by
    `modelProviderPolicyRequiresRedactionControlsForOffDeviceInputScopes`.
- [x] Safe reset / factory-reset path
  - 2026-05-30 evidence: `WorkspaceStorageManager.deleteWorkspace` and
    `WorkspaceService.deleteWorkspace` require exact workspace-name
    confirmation before deleting local workspace data, close the database pool,
    remove the workspace directory, delete the workspace master key, and remove
    the recent-workspace entry. The File menu and Settings expose a destructive
    "Delete Current Workspace..." action with typed confirmation, and
    `WorkspaceAppModel` clears active workspace state after deletion. Covered by
    `workspaceDeletionRequiresExactWorkspaceNameAndRemovesLocalData` and
    `testWorkspaceDeleteActionRequiresConfirmationAndClearsModelState`.

---

## 27. Optional MCP / Codex integration

- [ ] Separate MCP adapter layer on top of the internal tool bus
- [ ] Disabled by default
- [ ] Narrow scope model (`finance.read`, `documents.read`, `tax.read`, `ledger.propose`, `exports.generate`)
- [x] No unrestricted file access
  - 2026-05-30 evidence: `AgentToolDefinition` now models
    `allowsUnrestrictedFileAccess`, and `AgentToolRegistry.validateSafetyPolicy()`
    rejects any production tool that enables it.
    `scripts/verify-agent-tool-safety.sh` also rejects direct filesystem,
    native file-picker, or shell access in agent-facing sources and runs the
    focused `AgentToolPolicy` tests.
- [x] No unrestricted SQL exposure
  - 2026-05-30 evidence: `AgentToolRegistry.validateSafetyPolicy()` rejects
    tools with `allowsRawSQL`, the router sends raw-SQL requests to
    `unsupported`, and `scripts/verify-agent-tool-safety.sh` rejects production
    source declarations that enable raw SQL or shell execution.
- [ ] Local-power-user mode design
- [ ] Remote authenticated mode kept optional and isolated
- [ ] Clear documentation of auth model and trust boundaries

---

## 28. Testing and validation

### Automated tests
- [ ] Unit tests
- [ ] Integration tests
- [x] Migration tests
  - 2026-05-30 evidence:
    `databaseMigrationsCreateRequiredSchemaFromEmptyDatabase`,
    `databaseMigrationsAreIdempotentAfterFullApplication`, and
    `databaseMigrationsBackfillLegacyV4WorkspaceData` cover empty-database
    smoke, full idempotency, a legacy v4-to-current backfill path, and the
    additive proposal uncertainty metadata columns.
    `databaseMigrationsUpgradeLegacyV5AgentProposalMetadataPreservesPendingRows`
    manually downgrades the v5 agent-proposal table shape, migrates it forward,
    verifies v6/v7/v15 metadata columns preserve the pending row, and
    round-trips the migrated row through `GRDBAgentProposalRepository`.
    `databaseMigrationsUpgradeLegacyV14AgentProposalUncertaintyState` manually
    installs a pre-v15 agent-proposal row and verifies the current migrator adds
    `missingFields`, `question`, and `requiresManualReview` defaults without
    losing fingerprint, source refs, rationale, confidence, status, or decision
    metadata.
    `databaseMigrationsUpgradeLegacyV15ImportDiagnosticsSupportExistingImportJobs`
    migrates a pre-v16 workspace with an existing failed import job, verifies
    the import-diagnostics table and indexes are added, then saves and fetches
    diagnostics through the production repository while preserving foreign-key
    integrity and cascade cleanup.
    `databaseMigrationsUpgradeLegacyV17AgentAndImportState` manually installs a
    pre-v18 schema with legacy import jobs, agent conversations, messages, and
    pending approvals, marks migrations through
    `v17_agent_conversation_storage` as applied, then verifies the current
    migrator adds import-source tracking and agent-run trace storage while
    preserving those rows.
- [ ] Import golden tests
- [ ] Reconciliation tests
- [ ] Missingness tests
- [ ] Tax rule tests
- [ ] Export validation tests
- [x] AI tool-safety tests
  - 2026-05-29 evidence: `productionAgentToolRegistryPassesSafetyPolicy`,
    `confirmedWriteToolsRequireExplicitUserConfirmation`, and
    `agentToolPolicyRejectsUnsafeToolDefinitions` verify policy metadata.
    `agentToolExecutorRunsReadOnlyToolWhenScopesAndProvenanceArePresent`,
    `agentToolExecutorRejectsMissingScopeBeforeHandlerRuns`,
    `agentToolExecutorRequiresExplicitConfirmationForConfirmedWrites`,
    `agentToolExecutorRejectsResultsWithoutRequiredProvenance`, and
    `agentToolExecutorRejectsUnsafeRegistryBeforeRunningHandlers` verify
    executable scope, confirmation, provenance, raw-SQL, shell-execution, and
    duplicate-tool guardrails. `agentToolWorkflowProposesTaxOverrideReasonWithoutMutatingTaxFact`,
    `agentToolWorkflowRejectsTaxOverrideProposalForMissingFact`,
    `agentToolWorkflowAcceptsTaxOverrideWithExplicitConfirmation`,
    `agentToolWorkflowRejectsTaxOverrideAcceptanceWithoutConfirmation`,
    `agentToolWorkflowProposesLedgerMappingWithoutMutatingTransaction`,
    `agentToolWorkflowRejectsLedgerMappingForForeignCategory`,
    `agentToolWorkflowProposesLedgerSplitWithoutMutatingTransaction`, and
    `agentToolWorkflowRejectsLedgerSplitWhenLinesDoNotBalance`,
    `agentToolWorkflowProposesClosingAccrualWithoutPostingJournalEntry`,
    `agentToolWorkflowRejectsClosingAccrualWhenUnbalanced`,
    `agentToolWorkflowAppliesDraftJournalEntryWithExplicitConfirmation`,
    `agentToolWorkflowRejectsDraftJournalEntryWithoutConfirmation`,
    `agentToolWorkflowRejectsDraftJournalEntryForLockedTaxYear`,
    `agentToolWorkflowGeneratesExportPackageDraftArtifact`,
    `agentToolWorkflowRejectsExportPackageGenerationForMissingVATPeriod`,
    `agentToolWorkflowFinalizesExportPackageWithExplicitConfirmation`,
    `agentToolWorkflowRejectsExportFinalizationWithoutConfirmation`,
    `agentToolWorkflowRejectsExportFinalizationForSnapshotMismatch`,
    `agentToolWorkflowMergesCounterpartiesWithExplicitConfirmation`,
    `agentToolWorkflowRejectsCounterpartyMergeWithoutConfirmation`,
    `agentToolWorkflowValidatesExportThroughExecutorWithProvenance`,
    `agentToolWorkflowRejectsExportValidationForMissingVATPeriod`,
    `agentToolWorkflowTracesAuditObjectThroughExecutorWithProvenance`,
    `agentToolWorkflowLowConfidenceDocumentMatchEscalatesWithQuestion`, and
    `agentToolWorkflowRejectsAuditTraceWithInvalidLimit` cover proposal-only
    tax override, ledger mapping, ledger split, closing accrual, approved
    journal posting, counterparty merge, export package generation, export
    validation, audit tracing, and rejection cases.
- [x] Backup/restore tests
  - 2026-05-29 evidence:
    `workspaceBackupRestoreRoundTripsDatabaseBlobsKeyAndAuditTrail` runs in
    `swift test`; `workspaceBackupValidationRejectsTamperedHashedFile` covers
    backup tamper rejection;
    `testBackupActionsCreateAndRestoreThroughWorkspaceAppModel` also checks the
    successful Settings integrity summary;
    `testRestoreBackupRejectsTamperedBundleThroughWorkspaceAppModel` checks the
    blocked Settings integrity summary;
    `workspaceBackupRestorePreservesRealisticWorkspaceGraph` covers a
    multi-entity backup restore drill, and
    `workspaceDeletionRequiresExactWorkspaceNameAndRemovesLocalData` verifies
    safe reset removes the workspace folder, recent reference, and master key
    only after exact typed confirmation;
    `customerScaleStatementImportSurvivesBackupRestoreDrill` verifies the
    customer-scale fixture import survives backup validation and restore with
    encrypted source blob evidence intact; `scripts/verify-readiness.sh` now
    reports 247 package tests and 53 app CI tests. The last
    `RUN_UI_TESTS=full` pass also covered the full app scheme with 23 app unit
    tests and 7 UI tests.
- [x] Performance tests
  - 2026-05-30 evidence: `scripts/verify-performance.sh` runs focused
    performance regressions for CSV import throughput and larger-workspace
    storage behavior with `ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1`.
    `csvImportJobHandlesCustomerScaleFixtureWithinRegressionBudget` imports the
    cataloged 2,500-row customer-scale CSV fixture through `ImportJobService`,
    verifies persisted transactions, counterparties, statement import, audit
    events, and zero diagnostics, and enforces a 12-second local regression
    budget in the dedicated performance gate. Normal full package tests keep the
    same scenario as data-shape coverage without wall-clock assertions under
    parallel test load. `customerScaleStatementImportSurvivesBackupRestoreDrill`
    restores the same fixture-backed import from a backup bundle and verifies restored
    transaction, counterparty, statement, blob, and audit counts.
    `workspaceGlobalSearchStaysBoundedOnLargerWorkspace` and
    `workspaceReportingViewsScopedLookupsAndRestoreStayBoundedOnLargerWorkspace`
    cover global search, reporting views, tax-status rows, scoped transaction
    and statement lookups, evidence-link lookups, and volume backup/restore; the
    bounded query budgets are enforced by `scripts/verify-performance.sh` under
    the explicit performance-budget environment.
    Release-hardware profiling and manual UI responsiveness review remain
    tracked separately under operations/UI smoke.
- [ ] UI smoke tests
  Evidence: run [ui-smoke-pass-macos.md](ui-smoke-pass-macos.md) in default motion and Reduce Motion modes.
  - 2026-05-29 partial evidence: `RUN_UI_TESTS=full scripts/verify-readiness.sh`
    passes the full app scheme with 7 UI tests covering workspace
    creation/recent reopen, settings, entity switching, document search,
    document preview, inspector persistence, and ledger/inbox/document
    selection flows. The full manual UI smoke pass remains pending.
  - 2026-05-30 partial evidence: added
    `testGlobalSearchFindsDocumentAndOpensPreview` to cover toolbar global
    search, result selection, document navigation, and preview display through
    the macOS UI. `xcodebuild build-for-testing -workspace
    AlpenLedger.xcworkspace -scheme AlpenLedgerApp -destination
    'platform=macOS,arch=arm64'` passes, proving the expanded UI target builds.
    Two focused execution attempts for the new test were blocked before test
    bodies ran by macOS LocalAuthentication with `System authentication is
    running`, so current UI execution remains unproven in this environment.

### Fixtures
- [x] CSV fixture pack
  - 2026-05-30 evidence: `Fixtures/Bank/sample-bank-statement.csv` is cataloged
    as `csv-bank-statement`, hash-verified by `scripts/verify-fixtures.sh`, used
    by importer/reconciliation/tax tests, and bundled as a Debug sample app
    resource.
- [x] Customer-scale bank-statement fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Bank/sample-bank-statement-customer-scale.csv` is cataloged as
    `customer-scale-bank-statement`, hash-verified by
    `scripts/verify-fixtures.sh`, checked for at least 2,500 rows, 80
    counterparties, and CHF-only data, and covered by
    `csvImportJobHandlesCustomerScaleFixtureWithinRegressionBudget` and
    `customerScaleStatementImportSurvivesBackupRestoreDrill`.
- [x] CAMT fixture pack
  - 2026-05-30 evidence: six CAMT fixtures now cover CAMT.052 single and
    multi-report files, CAMT.053 single and multi-statement files, and CAMT.054
    single and batched multi-notification files. They are cataloged as
    `camt-bank-report`, `camt-bank-statement`, and `camt-bank-notification`,
    hash-verified by `scripts/verify-fixtures.sh`, and covered by CAMT importer
    and import-pipeline tests.
- [x] QR-bill fixture pack
  - 2026-05-30 evidence: `Fixtures/Documents/sample-qr-bill.txt` is cataloged
    as `qr-bill`, hash-verified by `scripts/verify-fixtures.sh`, and covered by
    QR-bill detection and structured extraction tests.
- [x] Salary certificate fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/Zurich/2026/salary-certificate.txt` is cataloged in the
    Zurich 2026 personal-tax pack, hash-verified by `scripts/verify-fixtures.sh`,
    and covered by tax fact derivation and explanation tests.
- [x] VAT reconciliation fixture pack
  - 2026-05-30 evidence: `Fixtures/VAT/simple-quarter-2026.json` is cataloged
    as `vat-period-reconciliation`, hash-verified by
    `scripts/verify-fixtures.sh`, checked for VAT period, transaction, and
    expected-total structure, and covered by
    `VATPeriodComputationServiceTests.vatPeriodReconcilesSwissFixtureTotals`.
- [x] VAT export fixture pack
  - 2026-05-30 evidence:
    `Fixtures/VAT/eCH-0217-effective-reporting-2026.xml` is cataloged as
    `vat-export`, hash-verified by `scripts/verify-fixtures.sh`, checked for
    eCH-0217 v2 namespace and required VAT declaration sections, and covered by
    `SwissVATDeclarationExportServiceTests.swissVATDeclarationExportGeneratesExpectedECH0217XML`.
    `scripts/verify-schemas.sh` also validates it offline against the vendored
    official eCH-0217 v2.0.0 schema set.
- [x] `eCH-0196` fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/eCH/eCH-0196-tax-statement-2026.xml` is cataloged as
    `ech-0196-tax-statement`, hash-verified by `scripts/verify-fixtures.sh`,
    checked for the eCH-0196 namespace/root/tax-year/CHF markers, and covered
    by document extraction and import tests.
- [x] `eCH-0248` fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/eCH/eCH-0248-pension-contributions-2026.xml` is cataloged as
    `ech-0248-pension-certificate`, hash-verified by
    `scripts/verify-fixtures.sh`, checked for the eCH-0248
    namespace/root/tax-year/CHF markers, and covered by document extraction and
    import tests.
- [x] `eCH-0275` fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/eCH/eCH-0275-health-insurance-2026.xml` is cataloged as
    `ech-0275-health-insurance-certificate`, hash-verified by
    `scripts/verify-fixtures.sh`, checked for the eCH-0275
    namespace/root/tax-year/CHF markers, and covered by document extraction and
    import tests.
- [x] Personal tax export fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/Zurich/2026/export-readiness.json` is cataloged as
    `personal-tax-export`, hash-verified by `scripts/verify-fixtures.sh`,
    checked for Zurich 2026 natural-person draft export readiness shape, and
    covered by
    `zurichNaturalPersonPersonalTaxExportReadinessFixtureMatchesExpectedFacts`.
    This fixture proves draft review readiness; eCH-0119 generation remains
    tracked separately.
- [x] Business tax export fixture pack
  - 2026-05-30 evidence:
    `Fixtures/Tax/Business/2026/expected-business-tax-facts.json` and
    `Fixtures/Tax/Business/2026/export-readiness.json` are cataloged as
    `business-tax-export`, hash-verified by `scripts/verify-fixtures.sh`,
    checked for Zurich 2026 sole-proprietor draft export readiness shape, and
    covered by
    `zurichSoleProprietorBusinessTaxFixtureProducesExpectedFactsAndExportReadiness`.
    This fixture proves draft review readiness; eCH-0276 generation remains
    tracked separately.

### Validation
- [x] XSD/schema validation harnesses
  - 2026-05-30 evidence: `Schemas/eCH/` vendors the official eCH-0217 v2.0.0
    schema and imported eCH dependency XSDs, `config/schema-catalog.json`
    records their source URLs and SHA-256 hashes, and
    `scripts/verify-schemas.sh` verifies the catalog, rejects hash drift or
    absolute local catalog paths, validates the golden eCH-0217 VAT export with
    `xmllint --nonet`, and proves a malformed payload missing `payableTax` is
    rejected. The verifier is included in `scripts/verify-readiness.sh`.
- [x] Import parse diagnostics
  - 2026-05-30 evidence: CSV and CAMT import parsers now emit structured
    `ImportDiagnostic` records with severity, code, source location, message,
    and import-job provenance. `ImportPipeline` persists parser warnings with
    completed imports and writes an error diagnostic for failed statement
    imports. Inbox import rows and inspectors surface diagnostic summaries and
    the first parser findings. Covered by
    `importJobServicePersistsCSVParseDiagnostics`,
    `importJobServicePersistsFailureDiagnosticForRejectedCSV`,
    `databaseMigrationsCreateRequiredSchemaFromEmptyDatabase`, and
    `testImportInspectorShowsStructuredParseDiagnostics`.
- [x] Rule-pack validation
  - 2026-05-30 evidence: `config/rule-pack-catalog.json` records the
    registered Zurich 2026 personal-tax adapter, jurisdiction, ruleset version,
    supported entity kinds, expected concept codes, fixture pack, golden
    expected-facts file, and coverage tests. `RulePackValidationService`
    validates registered packs against fixture samples, rejects undeclared
    computed facts, missing provenance, invalid value shapes, invalid
    confidence, and rule-pack-emitted overrides. `scripts/verify-rule-packs.sh`
    performs catalog/fixture integrity checks and focused
    `RulePackValidation` Swift tests, and is included in
    `scripts/verify-readiness.sh`.
- [x] Realistic end-to-end scenario tests
  - 2026-05-30 evidence:
    `realisticEndToEndScenarioCoversPersonalBusinessEvidenceVATAndRecovery`
    creates an encrypted workspace through `WorkspaceService`, imports Zurich
    personal-tax fixtures through `DocumentService`, refreshes deterministic tax
    facts/readiness, creates a sole-proprietor workspace, imports the CSV bank
    statement through `ImportJobService`, refreshes evidence requirements and
    issues, reconciles and locks a fixture-backed Swiss VAT period, exports a
    sanitized support bundle, and validates a restorable backup.
    `scripts/verify-end-to-end-scenarios.sh` runs this focused scenario and is
    included in `scripts/verify-readiness.sh`.

---

## 29. Performance, resilience, and operations

- [ ] Large-workspace performance profiling
  - 2026-05-30 partial evidence:
    `workspaceGlobalSearchStaysBoundedOnLargerWorkspace` and
    `workspaceReportingViewsScopedLookupsAndRestoreStayBoundedOnLargerWorkspace`
    exercise larger persisted workspaces and enforce bounded storage query
    budgets when `scripts/verify-performance.sh` sets
    `ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS=1`. The focused performance gate
    keeps these regressions in the default readiness gate while normal full
    package tests retain the same functional coverage without wall-clock
    assertions under parallel load. This remains open until representative
    release hardware profiles include import throughput and UI interaction
    timing.
- [x] Import throughput checks
  - 2026-05-30 evidence:
    `csvImportJobHandlesCustomerScaleFixtureWithinRegressionBudget` imports the
    cataloged 2,500-row customer-scale CSV statement through the full import job
    pipeline, verifies persisted transactions, statement import metadata,
    counterparties, audit events, and zero diagnostics, and enforces a
    12-second local regression budget in the dedicated performance gate. The
    focused check is included in `scripts/verify-performance.sh` and the default
    readiness gate; full package tests still verify the imported data shape
    without wall-clock assertions.
- [ ] Background-task cancellation/resume
  - 2026-05-30 partial evidence: CSV statement imports now accept a typed
    cancellation check. A cancellation after the import job is created records
    a `cancelled` job, writes an `import.cancelled` warning diagnostic, audits
    `importJobCancelled`, persists no statement imports or transactions, and
    allows the same source file to be imported successfully later. Retrying a
    cancelled statement import can also reprocess the stored encrypted raw blob
    after the original source file has been removed, and the Inbox inspector now
    exposes this reviewer-facing retry action when the stored source is
    available. Covered by
    `importJobServiceCancelsCSVWithoutPersistingRowsAndAllowsResume` and
    `importJobServiceRetriesCancelledCSVFromStoredSourceBlob`. This remains open
    until other long-running app actions expose equivalent cancellation/resume
    behavior.
- [ ] Safe error recovery paths
  - 2026-05-30 partial evidence: backup creation publishes only completed
    bundles and removes staged artifacts on failure, and failed backup restores
    clean up both the temporary restored workspace directory and any newly
    inserted workspace master key if the restored database cannot be opened.
    Successful statement imports now commit the statement rows, transactions,
    diagnostics, completed import job, and success audit events in one database
    transaction, avoiding post-commit audit failures from rewriting a persisted
    import as failed. Covered by
    `importJobServiceCommitsSuccessfulCSVRowsAndAuditEventsTogether`,
    `workspaceBackupCreationCleansUpStagedBundleWhenKeyLoadFails`, and
    `workspaceBackupRestoreRemovesInsertedKeyWhenOpenFails`. This remains open
    until equivalent recovery coverage exists for the other high-risk app
    operations.
- [x] Crash-safe import handling
  - 2026-05-30 evidence: `ImportPipeline` already persists parsed statement
    data and parser diagnostics inside a single transaction, and failed parser
    attempts are recorded as failed import jobs with error diagnostics. New
    recovery coverage adds `ImportJobService.recoverInterruptedImports`, which
    marks any still-started import jobs as failed, writes an
    `import.interrupted` diagnostic, and records an `importJobRecovered` audit
    event. `WorkspaceAppModel` runs the recovery step when a workspace opens
    before refreshing UI state. Covered by
    `importJobServiceRecoversInterruptedStartedImports` and
    `testOpeningWorkspaceRecoversInterruptedImportJobs`.
- [x] Corrupt-file handling
  - 2026-05-30 evidence: failed statement imports now classify diagnostics as
    `import.corrupt_file`, `import.unsupported_format`, `import.duplicate`,
    `import.locked_period`, or `import.failed` instead of collapsing every
    failure into a generic code. Corrupt CSV and malformed CAMT.053 files are
    rejected with failed import jobs, error diagnostics, and no persisted
    statement imports or transactions. Covered by
    `importJobServiceRejectsCorruptCSVWithoutPersistingPartialRows` and
    `importJobServiceRejectsCorruptCAMTWithoutPersistingPartialRows`.
- [x] Migration rollback/recovery strategy
  - 2026-05-30 evidence: `WorkspaceStorageManager.openWorkspace` now creates a
    hidden database-file recovery snapshot before running pending migrations,
    restores the original `workspace.sqlite`/sidecar files if migration fails,
    and removes stale recovery snapshots after a successful open. Covered by
    `workspaceStorageManagerRestoresDatabaseSnapshotWhenMigrationFails`, which
    injects a failing migrator, verifies the failure marker table is rolled
    back, then reopens the workspace and confirms the migration ledger reaches
    the expected current identifiers.
- [x] Restore drills on realistic backups
  - 2026-05-29 evidence:
    `workspaceBackupRestorePreservesRealisticWorkspaceGraph` creates and
    restores a multi-entity workspace backup with statement imports,
    transactions, documents, evidence links, tax facts, issues, invoice
    metadata, proposal decision metadata, filing-package state, raw statement
    blobs, and entity-workspace defaults.
- [x] Support diagnostics export
  - 2026-05-30 evidence: `WorkspaceStorage.exportSupportDiagnostics(to:)`
    writes a sanitized local JSON diagnostics report with workspace storage
    metadata, `WorkspaceStorage.databaseHealthReport()`, schema table counts,
    and filesystem counts. The report declares that it excludes workspace names,
    absolute paths, workspace keys, document contents, document filenames,
    transaction descriptions, and transaction amounts. Settings and the File
    menu expose the export action through `WorkspaceAppModel`, covered by
    `workspaceSupportDiagnosticsExportIsSanitizedAndIncludesHealthAndCounts`
    and `testExportDiagnosticsThroughWorkspaceAppModel`.
- [x] Support audit/log bundle export
  - 2026-05-30 evidence: `WorkspaceStorage.exportSupportBundle(to:)` writes a
    sanitized local support bundle with diagnostics plus audit event counts,
    actor/event/object-kind summaries, and bounded recent event metadata.
    Settings and the File menu expose the export action through
    `WorkspaceAppModel`, covered by
    `workspaceSupportBundleExportIncludesSanitizedAuditLog` and
    `testExportSupportBundleThroughWorkspaceAppModel`.
- [x] Release note generation process
  - 2026-05-30 evidence: `docs/release.md` requires one
    `docs/release-notes/v<version>.md` draft per app marketing version.
    `docs/release-notes/v0.1.0.md` is the current draft for
    `CFBundleShortVersionString=0.1.0` and build `1`.
    `scripts/verify-release-notes.sh` verifies the current draft exists, matches
    `Info.plist`, includes required user-facing sections, and lists required
    release evidence commands; `--strict` additionally blocks TBD/TODO/FIXME
    placeholders and unchecked verification evidence for release candidates.
    The verifier is included in `scripts/verify-readiness.sh`.

---

## 30. Distribution, onboarding, localization, and support

- [ ] App signing
- [ ] Notarization pipeline
- [x] Release packaging
  - 2026-05-30 evidence: `scripts/package-release.sh` packages a prepared
    `AlpenLedgerApp.app` into a versioned ZIP named from
    `CFBundleShortVersionString` and `CFBundleVersion`, checks bundle metadata
    against the current checkout, stages the ZIP and `.sha256` checksum, runs
    `scripts/verify-release-artifact.sh` by default, and publishes the
    artifacts only after final verification passes. Unverified packaging
    rehearsals require the explicit `--skip-final-verification` flag.
    `scripts/verify-release-packaging.sh` verifies script syntax, dry-run
    metadata, final-artifact verification wiring, staged-artifact publishing,
    and release documentation references, and is included in
    `scripts/verify-readiness.sh`.
- [x] First-run onboarding
  - 2026-05-30 evidence: the empty workspace chooser now shows a first-run
    checklist covering the demo workspace, local workspace creation, and backup
    review before filing. `WorkspaceChooserSnapshot.onboardingItems` provides
    the copy and icons, `WorkspaceChooserView` renders the guide before recent
    workspaces when no recents exist, and
    `testHelpCenterAndFirstRunOnboardingAreAvailableWithoutWorkspace` verifies
    the onboarding state is available without creating or opening a workspace.
- [x] Sample/demo workspace
  - 2026-05-30 evidence: the workspace chooser and File menu expose a
    production demo-workspace action. `WorkspaceAppModel.createDemoWorkspace`
    creates an encrypted local workspace, adds a demo sole-proprietor entity,
    imports the bundled sample bank statement and receipt through the normal
    import services, selects the statement account so transactions are visible,
    registers the workspace as recent, and leaves the user on Overview.
    `testCreateDemoWorkspaceBuildsLocalSampleWorkspace` verifies the local
    workspace roots, imported transactions/documents/import jobs, missingness
    issue generation, recent-workspace registration, and local search.
- [x] In-app help baseline
  - 2026-05-30 evidence: `HelpCenterSnapshot` and `HelpCenterView` provide a
    native in-app help sheet covering first run, evidence review, tax readiness,
    locked periods, backups, and sanitized support exports. The help sheet is
    reachable from the workspace chooser, Settings, and the macOS Help menu.
    `testHelpCenterAndFirstRunOnboardingAreAvailableWithoutWorkspace` verifies
    the guide sections and presentation state without requiring a workspace.
- [x] Error/help copy review
  - 2026-05-30 evidence: `docs/copy-review.md` defines the release-critical
    copy principles for domain errors, app alerts, Help Center, support copy,
    release notes, and localization boundaries.
    `domainErrorCopyIsSpecificAndActionableForReleaseReview` verifies every
    representative `DomainError` has a specific short title, localized
    description, and actionable recovery suggestion without generic fallback
    copy. App tests still cover alert presentation and Help Center availability,
    while `scripts/verify-copy-review.sh` keeps the copy-review runbook,
    checklist evidence, release-note limitation, and focused copy tests wired
    into `scripts/verify-readiness.sh`.
- [x] Localization framework
  - 2026-05-30 evidence: `docs/localization.md` defines the English-first v0.1
    localization baseline, resource layout, release rules, and minimum evidence
    for future languages. `config/localization-catalog.json` records English as
    the default/development language, German and French as planned languages,
    and the required Swiss finance/tax glossary keys. The app target has
    `CFBundleDevelopmentRegion=en`, `App/AlpenLedgerApp/Resources/en.lproj/Localizable.strings`
    provides the initial app-owned string resource, `Package.swift` sets
    `defaultLocalization: "en"`, and `LocalizationPolicy` prevents release
    availability claims for German/French until their status changes.
    `localizationPolicyKeepsPilotLanguageClaimsConservative` and
    `scripts/verify-localization.sh` keep the framework in the readiness gate.
- [ ] German/French/English readiness strategy
  - 2026-05-30 partial evidence: `docs/localization.md` and
    `config/localization-catalog.json` define the English/German/French strategy
    boundary, including Swiss finance/tax glossary keys, pseudo-localization or
    equivalent layout review, and release/support copy alignment. English is
    the only release-ready pilot language. This remains open until German and
    French translations, glossary reviews, and layout evidence exist and are
    verified.
- [x] Support documentation baseline
  - 2026-05-30 evidence: `docs/support.md` now defines the pilot support
    process, private intake checklist, severity levels, sanitized diagnostics
    and support-bundle workflow, privacy exclusions, backup safety, runbooks,
    escalation hand-off, and release support gate. `scripts/verify-support-docs.sh`
    verifies those anchors plus release notes, release docs, local-development
    docs, and readiness-gate wiring, and is included in
    `scripts/verify-readiness.sh`.

---

## 31. Manual acceptance scenarios

Run the dedicated desktop checklist in [ui-smoke-pass-macos.md](ui-smoke-pass-macos.md) before marking these scenarios complete.

### Personal-finance scenario
- [ ] Create a fresh workspace
- [ ] Add a personal entity
- [ ] Import bank statements
- [ ] Import receipts and salary certificate
- [ ] Detect missing monthly extracts
- [ ] Detect missing tax documents
- [ ] Prepare a pilot personal tax package
- [ ] Validate the export
- [ ] Review provenance for key tax values

### Business scenario
- [ ] Add a business entity
- [ ] Import business bank/card activity
- [ ] Link expenses to invoices/receipts
- [ ] Detect missing invoices
- [ ] Reconcile a VAT period
- [ ] Generate VAT export
- [ ] Run year-end checklist
- [ ] Generate pilot business tax export
  - 2026-05-30 partial evidence:
    the business-tax export fixture pack proves the draft review facts and
    readiness shape for the v0.1 Zurich sole-proprietor pilot. Full eCH-0276
    generation is still tracked in section 19.
- [ ] Review accountant bundle

### AI scenario
- [ ] Ask what is missing for a tax year
- [ ] Ask which expenses lack invoices
- [ ] Ask why VAT is high
- [x] Receive source-backed answers
  - 2026-05-30 evidence: `CopilotSnapshot.AnswerCard` exposes claim-level
    source refs and source rows for tax readiness, expense evidence, statement
    coverage, VAT, and draft business-export readiness, while
    `performCopilotAction` deep-links cited refs into Inbox, Ledger, Documents,
    Tax Studio, and imported-statement context. Covered by
    `testCopilotSnapshotSurfacesSourceBackedAnswersAndContext` and
    `testPerformCopilotActionDeepLinksToSourceObjects`.
- [x] Turn an answer into a task
  - 2026-05-30 evidence: `testCopilotAnswerCanCreateInboxTask` verifies that a
    Copilot answer action creates an audited open Inbox task without mutating
    ledger or tax facts. `testCopilotAnswerCanCreateInboxTaskFromButton` covers
    the visible Copilot button.
- [x] Review and approve/reject AI proposals
  - 2026-05-29 evidence: `docs.propose_match` creates pending document-match
    review proposals through `WorkspaceAgentToolService`, the proposal stores the
    related transaction ref, and the Inbox can explicitly approve or reject it.
    `reconciliationServiceApproveDocumentMatchProposalConfirmsEvidenceAndResolves`
    verifies approval creates one confirmed evidence link, resolves the proposal,
    and writes audit events.
    `reconciliationServiceRevokeDocumentMatchProposalApprovalRevokesEvidenceLink`
    verifies a reviewer can reverse approval without deletion by marking the
    link revoked and removing it from confirmed-link lookups. Full chat entry
    points remain tracked by the separate Copilot items above.

---

## 32. V1 acceptance gates

### Slice A — Core local finance workspace
- [ ] Imported files persist locally
- [ ] Transactions are reviewable
- [ ] Document search works
- [ ] Reconciliation and issue queues exist

### Slice B — Personal Tax Studio
- [ ] Personal tax checklist is produced
- [ ] Evidence gaps are identified
- [ ] Return export bundle can be generated and validated

### Slice C — Business finance + VAT
- [x] VAT periods reconcile to the ledger
  - 2026-05-30 evidence: `VATPeriodService.reconcileVATPeriod` loads a persisted
    VAT period, fetches in-period transactions from the entity ledger, and
    produces output tax, recoverable input tax, net payable tax, and
    blocker/warning issues. The persisted period lock state blocks later
    statement imports for the same dates, and Tax Studio surfaces persisted VAT
    reconciliation blockers/warnings for the selected entity/year.
- [x] Business expenses can be evidence-linked
  - 2026-05-30 evidence: a business-entity imported expense is detected as
    missing support, linked to a receipt through the confirmed evidence-link
    service, and re-evaluated as satisfied by
    `EvidenceRefreshService.refreshExpenseEvidence`.
- [x] VAT export works
  - 2026-05-30 evidence: `SwissVATDeclarationExportService` turns a blocker-free
    Swiss VAT reconciliation report into deterministic eCH-0217 v2.0.0 XML and
    validates the required metadata, declaration structure, and payable-tax
    total before returning the draft export artifact. The golden VAT export
    fixture is cataloged, hash-verified, and validated offline against the
    vendored official eCH XSD set.

### Slice D — AI Copilot
- [x] Chat answers are provenance-backed
  - 2026-05-30 evidence: `AgentAnswerComposer` is the typed answer boundary for
    copilot output. It refuses empty answers, uncited claims, citations that were
    not returned by prior tool/model provenance, invalid confidence values, and
    empty follow-up questions. Accepted answers carry claim-level source refs,
    aggregate provenance refs, claim kinds that distinguish observed facts,
    derived values, user overrides, suggestions, and missing information, plus a
    markdown renderer that prints citations beside each claim. Covered by
    `AgentAnswerTests` and `scripts/verify-copilot-answers.sh`, which is included
    in `scripts/verify-readiness.sh`. Chat session storage and a full CFO/Q&A
    agent remain separate open gates.
- [x] Tool access is safe
  - 2026-05-30 evidence: production tool definitions pass safety policy,
    confirmed-write tools require explicit confirmation, raw SQL/shell tools
    are rejected, executor calls enforce scopes and provenance, and
    `WorkspaceAgentToolService` proves concrete read-only
    finance/document/reconciliation/tax, issue, proposal, draft-artifact, and
    confirmed ledger/entity/tax/export tools run through that boundary with sanitized
    success/rejection audit events. The concrete tax override proposal path is
    proposal-only and rejects missing tax facts instead of inventing values; the
    confirmed journal posting, counterparty merge, override acceptance, and
    export finalization paths reject missing confirmation before mutation.
- [x] Proposals are reviewable and reversible
  - 2026-05-29 evidence: document-match proposals are reviewable in the Inbox,
    approval requires an explicit reviewer action, and approved matches can be
    revoked without deleting evidence. Revocation updates decision metadata,
    changes the evidence link status to `revoked`, removes it from confirmed-link
    lookups, and writes audit events. Covered by package and app CI tests.

### Slice E — Year-end + business tax
- [ ] Year-end checklist works
- [ ] Business tax export package exists
- [ ] Accountant review bundle is usable

---

## 33. Post-v1 expansion backlog

- [ ] Additional canton support
- [ ] Broader legal-entity coverage
- [ ] Payroll imports
- [ ] Swissdec-compatible roadmap
- [ ] Standards/rule-pack updater
- [ ] Accountant collaboration/review mode
- [ ] More advanced forecasting/analytics
- [ ] Broader MCP / power-user tooling
- [ ] Additional document/certificate standards as they mature
- [ ] Deeper portal/submission integrations where feasible

---

## Section notes

Add implementation notes, evidence links, or blockers beneath any section as work progresses.
