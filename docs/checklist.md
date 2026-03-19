# checklist.md — AlpenLedger build checklist

Use this file as the operational build checklist for AlpenLedger.

## How to use

- Mark `[x]` only when the item is **implemented, tested, documented, and reviewable**.
- Leave `[ ]` if it is not done.
- If something is partially done, keep it unchecked and add a note under the relevant section.
- Add short evidence notes, file paths, PR links, or commit references under sections as work completes.
- Do not treat prototypes, mocks, or placeholder TODOs as done.

## Global release gates

- [ ] The app builds cleanly from a fresh checkout.
- [ ] The app can run fully offline in local-only mode.
- [ ] Authoritative data remains local by default.
- [ ] All AI writes require explicit approval.
- [ ] Raw imports remain immutable.
- [ ] Major features have migration coverage.
- [ ] Major features have realistic sample fixtures.
- [ ] User-facing errors are understandable and actionable.
- [ ] Backup and restore work on realistic workspaces.
- [ ] Release artifacts can be signed/notarized.

---

## 0. Product governance and scope

- [ ] Lock the v1 product thesis and target user profiles.
- [ ] Lock the pilot canton for personal tax.
- [ ] Lock the pilot business profile for business/VAT workflows.
- [ ] Create and maintain architectural decision records (ADRs).
- [ ] Create a risk register for legal, tax, security, and data-integrity risks.
- [ ] Define release naming/versioning strategy.
- [ ] Define sample-data anonymization and fixture governance.
- [ ] Define documentation maintenance rules.
- [ ] Keep `vision.md`, `architecture.md`, `architecture-pass-v1.md`, `agents.md`, `buildplan.md`, `docs/internal/prompt.md`, and `checklist.md` aligned.

---

## 1. Repository, toolchain, and project setup

- [ ] Create the Xcode project / workspace.
- [ ] Pin the scaffold to the current stable Xcode/Swift baseline and current stable third-party package versions.
- [ ] Create Swift Package Manager internal package boundaries.
- [ ] Set a consistent module/dependency graph.
- [ ] Add build scripts and bootstrap instructions.
- [ ] Add linting and formatting rules.
- [ ] Add CI for build, test, and static checks.
- [ ] Add feature-flag support.
- [ ] Add environment/configuration handling.
- [ ] Add dependency review policy.
- [ ] Document local development setup.

---

## 2. App shell and design system

- [ ] Create the macOS app entry point and windowing setup.
- [ ] Build a sidebar-based navigation shell.
- [ ] Implement toolbar actions and global search entry points.
- [ ] Build a reusable inspector pattern.
- [ ] Build basic list, table, badge, status, and empty-state components.
- [ ] Build a document preview container.
- [ ] Implement commands/menu items and core keyboard shortcuts.
- [ ] Create a design token system for spacing, typography, radii, and iconography.
- [ ] Ensure the visual style feels native to macOS.
- [ ] Add preview/demo states for key UI components.

---

## 3. Workspace lifecycle and local security

- [ ] Implement workspace creation.
- [ ] Implement workspace opening and closing.
- [ ] Implement workspace metadata and recent-workspace management.
- [ ] Choose and implement encrypted-at-rest storage strategy.
- [ ] Store secrets in Keychain.
- [ ] Implement per-workspace key derivation or equivalent isolation.
- [ ] Implement optional workspace lock/auth gate.
- [ ] Define workspace storage layout on disk.
- [ ] Implement corruption detection / safe-open behavior.
- [ ] Implement workspace export and import metadata handling.

---

## 4. Database, migrations, and persistence foundation

- [ ] Integrate the primary SQLite-based database layer.
- [ ] Implement a migration framework.
- [ ] Add migration smoke tests.
- [ ] Add idempotent migration checks.
- [ ] Implement full-text search tables/indexes.
- [ ] Implement import idempotency tracking.
- [ ] Implement read-only analytics/reporting views.
- [ ] Implement audit tables / event persistence.
- [ ] Implement database health checks.
- [ ] Document schema evolution strategy.

---

## 5. Core domain model

### Workspace and entity model
- [ ] `Workspace`
- [ ] `LegalEntity`
- [ ] `TaxYear`
- [ ] Household / spouse / joint-filing context support
- [ ] Sole proprietor entity support
- [ ] Legal-entity support baseline (simple GmbH/AG path)

### Finance model
- [ ] `LedgerAccount`
- [ ] `FinancialAccount`
- [ ] `ImportJob`
- [ ] `StatementImport`
- [ ] `Transaction`
- [ ] `JournalEntry`
- [ ] `JournalLine`
- [ ] Account opening balances
- [ ] Currency handling baseline
- [ ] Period locking model

### Document and evidence model
- [ ] `Document`
- [ ] `EvidenceLink`
- [ ] `Requirement`
- [ ] `Issue`

### Tax and AI model
- [ ] `TaxFact`
- [ ] `FilingPackage`
- [ ] `AgentProposal`
- [ ] `AuditEvent`

### Invariants
- [ ] Balanced journal-entry enforcement
- [ ] Raw-import immutability
- [ ] Locked-period protection
- [ ] Manual-override marking
- [ ] Provenance preservation
- [ ] User approval state tracking

---

## 6. File vault and document infrastructure

- [ ] Implement content-addressed file storage.
- [ ] Implement hash-based dedupe.
- [ ] Preserve original filenames and source metadata.
- [ ] Support security-scoped file imports where relevant.
- [ ] Support drag-and-drop intake.
- [ ] Support PDF preview.
- [ ] Support image preview.
- [ ] Support document metadata editing/review.
- [ ] Implement extracted-text persistence.
- [ ] Implement document search indexing.
- [ ] Implement document tagging / type classification storage.
- [ ] Implement safe delete/archive semantics.

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
- [ ] QR-bill
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
- [ ] Implement import-job records.
- [ ] Track parser version per import.
- [ ] Store raw source metadata per import.
- [ ] Support import retry/reprocess.
- [ ] Support safe duplicate detection.
- [ ] Support import warnings and severity levels.
- [ ] Implement import summaries for UI review.
- [ ] Implement importer test harnesses.

---

## 9. Bank and payment imports

### CSV
- [ ] CSV importer framework
- [ ] Column mapping support
- [ ] Per-bank CSV presets
- [ ] CSV date/amount normalization
- [ ] CSV import fixture coverage

### CAMT / ISO 20022
- [ ] `camt.052` support
- [ ] `camt.053` support
- [ ] `camt.054` support
- [ ] Structured reference extraction
- [ ] Booking date / value date handling
- [ ] Balance extraction where available
- [ ] CAMT regression fixtures

### QR-bill
- [ ] QR-bill detection
- [ ] Structured reference extraction
- [ ] Creditor / debtor extraction
- [ ] Amount and currency extraction
- [ ] Structured address handling
- [ ] QR-bill fixture coverage

---

## 10. Tax and evidence document imports

- [ ] Salary certificate document handling
- [ ] Salary certificate field extraction baseline
- [ ] `eCH-0196` import baseline
- [ ] `eCH-0248` import baseline
- [ ] `eCH-0275` import baseline
- [ ] Mortgage statement handling baseline
- [ ] Annual bank/broker tax-statement handling baseline
- [ ] Tax-office notice handling baseline
- [ ] Low-confidence extraction review flows
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
- [ ] Counterparty tracking

### Bookkeeping
- [ ] Journal posting engine
- [ ] Chart-of-accounts support
- [ ] Personal category mapping
- [ ] Business chart-of-accounts templates
- [ ] Draft journal proposal workflow
- [ ] Manual journal-entry workflow
- [ ] Balance calculations
- [ ] Period close / lock basics

### Mixed finance handling
- [ ] Personal-vs-business classification support
- [ ] Owner draw / owner contribution flows
- [ ] Review path for mixed-use expenses
- [ ] Clear entity boundaries in UI and reports

---

## 12. Reconciliation engine

- [ ] Exact-match reconciliation
- [ ] Reference-number reconciliation
- [ ] Fuzzy amount/date/vendor reconciliation
- [ ] Duplicate detection
- [ ] Transfer matching
- [ ] Document-to-transaction matching
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

- [ ] Global search across documents, transactions, counterparties, and issues
- [ ] Read-only reporting views for AI and UI
- [ ] `vw_spend_by_month`
- [ ] `vw_cashflow_by_entity`
- [ ] `vw_missing_evidence`
- [ ] `vw_statement_coverage`
- [ ] `vw_tax_fact_status`
- [ ] `vw_unmatched_transactions`
- [ ] `vw_vat_reconciliation`
- [ ] Query performance checks on realistic datasets

---

## 16. Tax engine core

- [ ] Canonical `TaxFact` model
- [ ] Tax-fact provenance storage
- [ ] Tax-fact explanation support
- [ ] Rule-pack schema
- [ ] Rule-pack loading/versioning
- [ ] Jurisdiction/year selection
- [ ] Field mapping framework
- [ ] Validation rule framework
- [ ] Evidence requirement framework
- [ ] Manual override handling
- [ ] Tax-engine unit tests
- [ ] Tax-engine regression fixtures

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
- [ ] Explicit “prepared vs filed” status separation

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
- [ ] Expense evidence linking
- [ ] Asset register baseline
- [ ] Depreciation baseline
- [ ] Year-end pre-close checks
- [ ] Owner-draw / mixed-expense workflows

### VAT
- [ ] VAT code model
- [ ] VAT mapping on transactions/journal lines
- [ ] VAT period model
- [ ] VAT period lock
- [ ] VAT reconciliation report
- [ ] Consistency checks
- [ ] `eCH-0217` export generator
- [ ] `eCH-0217` validation
- [ ] VAT issue surfacing in UI

---

## 19. Business year-end and business tax

- [ ] Year-end closing checklist
- [ ] Draft adjusting-entry workflow
- [ ] Trial balance reporting
- [ ] Balance sheet mapping
- [ ] Profit-and-loss mapping
- [ ] Business tax canonical facts
- [ ] `eCH-0276` export generator
- [ ] `eCH-0276` validation
- [ ] Export manifests and diagnostics
- [ ] Accountant/fiduciary review bundle
- [ ] Explicit blocker reporting for incomplete year-end states

---

## 20. Explainability, provenance, and audit

- [ ] Per-value provenance model
- [ ] Ability to explain where a number came from
- [ ] Ability to explain which rule produced a tax fact
- [ ] Ability to explain which evidence supports a field
- [ ] Audit log for user actions
- [ ] Audit log for import actions
- [ ] Audit log for AI/agent tool calls
- [ ] Override history
- [ ] Review screen for proposed changes
- [ ] Exportable diagnostic/audit bundle

---

## 21. AI platform foundation

### Provider abstraction
- [ ] `ModelProvider` abstraction
- [ ] Local model provider integration
- [ ] Optional cloud model provider integration
- [ ] Embedding provider abstraction if used
- [ ] Reranker abstraction if used
- [ ] Provider capability registry

### Chat/session infrastructure
- [ ] Chat session storage
- [ ] Conversation history persistence
- [ ] Local memory separation from authoritative domain facts
- [ ] Pending-approval state handling
- [ ] Unresolved-question tracking
- [ ] Privacy-mode controls

### Privacy modes
- [ ] Air-gapped mode
- [ ] Hybrid mode
- [ ] External-assistant mode
- [ ] Explicit consent and redaction settings
- [ ] Network activity visibility to user

---

## 22. Tool bus and safe finance chat

- [ ] Typed tool registry
- [ ] `finance.list_accounts`
- [ ] `finance.search_transactions`
- [ ] `finance.explain_balance`
- [ ] `docs.search`
- [ ] `docs.get_document_summary`
- [ ] `reconcile.list_open_issues`
- [ ] `reconcile.find_missing_statements`
- [ ] `tax.list_requirements`
- [ ] `tax.preview_return`
- [ ] `tax.explain_fact`
- [ ] `ledger.propose_split`
- [ ] `exports.validate`
- [ ] Safe argument validation on all tools
- [ ] Tool-result provenance rendering
- [ ] No unrestricted raw SQL access for the model

---

## 23. Agent system

### Router / planner
- [ ] Router Agent
- [ ] Intent-to-tool/agent planning
- [ ] Context handling for active entity/year/canton

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
- [ ] Read-only vs proposal vs confirmed-write permissions
- [ ] Confidence protocol
- [ ] Escalation on uncertainty
- [ ] No silent financial mutations
- [ ] No invented tax facts
- [ ] Agent audit logging
- [ ] Agent evaluation harness

---

## 24. Copilot user experience

- [ ] Copilot main screen
- [ ] Inline answers with source references
- [ ] “Turn answer into task” action
- [ ] Review UI for proposals
- [ ] Suggestion confidence display
- [ ] Follow-up question flow
- [ ] Entity/year/canton context awareness
- [ ] Example workflows for:
  - [ ] “What is missing for my 2025 Zurich return?”
  - [ ] “Which business expenses lack invoices?”
  - [ ] “Why is my VAT due so high this quarter?”
  - [ ] “Which accounts still miss monthly extracts?”
  - [ ] “Prepare my business tax export”

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
- [ ] Year-end UI
- [ ] Business tax export UI

### Settings/help
- [ ] Settings screen
- [ ] AI/privacy controls
- [ ] Import defaults
- [ ] Backup/restore controls
- [ ] Help/about/onboarding entry points

---

## 26. Settings, backup, and data portability

- [ ] Settings architecture
- [ ] Local backup creation
- [ ] Local backup restore
- [ ] Backup integrity verification
- [ ] Workspace export/import
- [ ] Data retention controls
- [ ] Local log export for support
- [ ] Privacy explanation copy
- [ ] Redaction controls for cloud AI mode
- [ ] Safe reset / factory-reset path

---

## 27. Optional MCP / Codex integration

- [ ] Separate MCP adapter layer on top of the internal tool bus
- [ ] Disabled by default
- [ ] Narrow scope model (`finance.read`, `documents.read`, `tax.read`, `ledger.propose`, `exports.generate`)
- [ ] No unrestricted file access
- [ ] No unrestricted SQL exposure
- [ ] Local-power-user mode design
- [ ] Remote authenticated mode kept optional and isolated
- [ ] Clear documentation of auth model and trust boundaries

---

## 28. Testing and validation

### Automated tests
- [ ] Unit tests
- [ ] Integration tests
- [ ] Migration tests
- [ ] Import golden tests
- [ ] Reconciliation tests
- [ ] Missingness tests
- [ ] Tax rule tests
- [ ] Export validation tests
- [ ] AI tool-safety tests
- [ ] Backup/restore tests
- [ ] Performance tests
- [ ] UI smoke tests

### Fixtures
- [ ] CSV fixture pack
- [ ] CAMT fixture pack
- [ ] QR-bill fixture pack
- [ ] Salary certificate fixture pack
- [ ] `eCH-0196` fixture pack
- [ ] `eCH-0248` fixture pack
- [ ] `eCH-0275` fixture pack
- [ ] Personal tax export fixture pack
- [ ] VAT export fixture pack
- [ ] Business tax export fixture pack

### Validation
- [ ] XSD/schema validation harnesses
- [ ] Import parse diagnostics
- [ ] Rule-pack validation
- [ ] Realistic end-to-end scenario tests

---

## 29. Performance, resilience, and operations

- [ ] Large-workspace performance profiling
- [ ] Import throughput checks
- [ ] Background-task cancellation/resume
- [ ] Safe error recovery paths
- [ ] Crash-safe import handling
- [ ] Corrupt-file handling
- [ ] Migration rollback/recovery strategy
- [ ] Restore drills on realistic backups
- [ ] Support diagnostics export
- [ ] Release note generation process

---

## 30. Distribution, onboarding, localization, and support

- [ ] App signing
- [ ] Notarization pipeline
- [ ] Release packaging
- [ ] First-run onboarding
- [ ] Sample/demo workspace
- [ ] In-app help baseline
- [ ] Error/help copy review
- [ ] Localization framework
- [ ] German/French/English readiness strategy
- [ ] Support documentation baseline

---

## 31. Manual acceptance scenarios

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
- [ ] Review accountant bundle

### AI scenario
- [ ] Ask what is missing for a tax year
- [ ] Ask which expenses lack invoices
- [ ] Ask why VAT is high
- [ ] Receive source-backed answers
- [ ] Turn an answer into a task
- [ ] Review and approve/reject AI proposals

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
- [ ] VAT periods reconcile to the ledger
- [ ] Business expenses can be evidence-linked
- [ ] VAT export works

### Slice D — AI Copilot
- [ ] Chat answers are provenance-backed
- [ ] Tool access is safe
- [ ] Proposals are reviewable and reversible

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
