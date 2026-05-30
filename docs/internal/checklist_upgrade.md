# checklist_upgrade.md

# AlpenLedger Upgrade Checklist

Use this checklist as the working execution tracker.
Do not skip earlier sections and jump to feature work.

---

## 0. Ground rules

- [ ] Preserve the existing Swift/macOS/local-first architecture
- [ ] Do not rewrite the product into web/TypeScript
- [ ] Do not add more logic to `WorkspaceAppModel.swift`
- [ ] Do not mix personal and business records in one active working scope
- [ ] Do not ship schema changes without migrations and tests
- [ ] Do not claim unsupported Swiss tax coverage
- [ ] Do not store money in floating point
- [ ] Do not let OCR or AI guesses become authoritative without review

---

## 1. Read and audit everything first

- [ ] Read `project.yml`
- [ ] Read `Packages/AlpenLedgerKit/Package.swift`
- [ ] Read all app-shell files under `App/AlpenLedgerApp`
- [ ] Read all domain files under `ALDomain`
- [ ] Read storage foundation and migrations under `ALStorage`
- [ ] Read workspace, ledger, documents, evidence, and tax services
- [ ] Read all feature views under `ALFeatures`
- [ ] Read docs under `docs/`
- [ ] Cross-reference every screen in the screenshots with the live code
- [ ] Produce an internal map of what exists, what is stubbed, and what is missing

---

## 2. Sync architecture docs with live code

- [ ] Update `docs/vision.md`
- [ ] Update `docs/architecture.md`
- [ ] Update `docs/architecture-pass-v1.md`
- [ ] Update `docs/buildplan.md`
- [ ] Update `docs/adr/ADR-001-local-core-and-module-boundaries.md`
- [ ] Update `docs/adr/ADR-002-persistence-and-canonical-model.md`
- [ ] Add `docs/adr/ADR-003-entity-workspace-scoping.md`
- [ ] Explicitly document the difference between physical `Workspace` and user-facing `EntityWorkspace`
- [ ] Remove stale wording that suggests the scaffold does not yet exist

---

## 3. Fix the scoping model first

- [ ] Keep `Workspace` as the physical encrypted container on disk
- [ ] Add a new `EntityWorkspace` model
- [ ] Backfill one entity workspace per existing legal entity
- [ ] Make active entity workspace selection a first-class app concept
- [ ] Ensure every primary screen is scoped to the active entity workspace
- [ ] Ensure no mixed personal/business lists appear by default
- [ ] Decide how ambiguous legacy records are handled during migration
- [ ] Surface ambiguous records as review items instead of silently guessing

---

## 4. Decompose the root app model

- [ ] Audit `App/AlpenLedgerApp/Root/WorkspaceAppModel.swift`
- [ ] Move app/session orchestration into a coordinator
- [ ] Move active scope state into a dedicated session object
- [ ] Move feature snapshot building out of the root god object
- [ ] Move formatting helpers out where appropriate
- [ ] Move import-panel flows out where appropriate
- [ ] Keep the UI behavior stable while reducing coupling
- [ ] Leave the root model materially smaller and more focused

Suggested files:
- [ ] `App/AlpenLedgerApp/Root/AppCoordinator.swift`
- [ ] `App/AlpenLedgerApp/Root/ActiveWorkspaceSession.swift`
- [ ] `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherState.swift`
- [ ] `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherView.swift`

---

## 5. Complete the core domain model

- [ ] Add `EntityWorkspace`
- [ ] Add `TaxProfile`
- [ ] Add `Category`
- [ ] Add `InvoiceRecord`
- [ ] Add `JournalEntry`
- [ ] Add `JournalLine`
- [ ] Add `FilingPackage`
- [ ] Review whether `Document` should remain generic and linked from `InvoiceRecord`
- [ ] Ensure IDs and invariants match existing domain conventions
- [ ] Keep everything `Sendable`/codable where appropriate

---

## 6. Complete the storage layer

- [ ] Extend `ALStorage/Migrations.swift` for new phase-1 tables
- [ ] Add repositories for new models
- [ ] Update `WorkspaceStorage` composition
- [ ] Update `DatabaseFoundation.swift`
- [ ] Preserve backward compatibility with existing workspaces
- [ ] Backfill data during migration
- [ ] Add indexes for new scoped query paths
- [ ] Add tests for migrations and repository round-trips
- [ ] Add tests for entity workspace scoping correctness

---

## 7. Re-scope services

- [ ] Refactor `WorkspaceService`
- [ ] Refactor `LegalEntityService`
- [ ] Refactor `FinancialAccountService`
- [ ] Refactor `TransactionService`
- [ ] Refactor `DocumentService`
- [ ] Refactor `DocumentQueryService`
- [ ] Refactor `EvidenceRefreshService`
- [ ] Refactor `RequirementService`
- [ ] Refactor `IssueService`
- [ ] Refactor `TaxComputationService`
- [ ] Refactor `TaxValidationService`
- [ ] Ensure service methods accept or resolve active entity workspace scope cleanly
- [ ] Remove hidden cross-entity assumptions
- [ ] Add tests that prove one entity workspace cannot see another’s records by default

---

## 8. Add the top-level entity workspace switcher

- [ ] Keep the launch workspace chooser
- [ ] Add a switcher inside an opened physical workspace
- [ ] Make it obvious which entity workspace is active
- [ ] Ensure Overview reflects only the active entity workspace
- [ ] Ensure Inbox reflects only the active entity workspace
- [ ] Ensure Accounts/Ledger reflects only the active entity workspace
- [ ] Ensure Documents/Invoices reflect only the active entity workspace
- [ ] Ensure Tax reflects only the active entity workspace
- [ ] Ensure Settings clearly separates container-level and entity-level settings
- [ ] Add UI tests for switching between Personal / Business A / Business B

---

## 9. Clean up feature-state ownership

- [ ] Move feature models closer to their features
- [ ] Stop building all screen state in one root file
- [ ] Add feature-specific state builders/view models as needed
- [ ] Keep the current visual language
- [ ] Preserve the current split-view and inspector strengths
- [ ] Remove raw concept-code leakage from Tax UI
- [ ] Make document search use the search index, not only in-memory filtering

---

## 10. Build invoice management

### Domain and storage
- [ ] Add invoice metadata model
- [ ] Support invoice status states
- [ ] Support VAT metadata
- [ ] Support category assignment
- [ ] Support linked transaction reference
- [ ] Support notes/tags
- [ ] Support review/confidence state

### Filesystem
- [ ] Add configurable invoice inbox folder per entity workspace
- [ ] Add filesystem watcher
- [ ] Add rename logic
- [ ] Add archive logic
- [ ] Preserve original file content and provenance
- [ ] Deduplicate by content hash

### UI
- [ ] Add invoice upload/drop zone
- [ ] Add bulk upload
- [ ] Add invoice review screen
- [ ] Add invoice list with filters
- [ ] Add invoice detail inspector
- [ ] Add transaction matching flow

### Extraction
- [ ] Use native PDF text extraction first
- [ ] Add OCR fallback
- [ ] Add metadata heuristics
- [ ] Route low-confidence results to review

### Tests
- [ ] Add invoice ingestion tests
- [ ] Add rename/archive tests
- [ ] Add matching tests
- [ ] Add UI tests for invoice upload and review

---

## 11. Expand accounts and imports

### Banking
- [ ] Support manual account creation per entity workspace
- [ ] Keep multiple bank accounts per entity workspace
- [ ] Improve CSV import handling
- [ ] Add Swiss format support plan for CAMT/MT940
- [ ] Preserve import idempotency
- [ ] Preserve statement coverage logic

### Categorization
- [ ] Add first-class categories per entity workspace
- [ ] Add category assignment to transactions and invoices
- [ ] Add defaults/templates where useful

### Matching
- [ ] Improve transfer detection
- [ ] Improve duplicate detection
- [ ] Improve invoice ↔ transaction matching
- [ ] Keep evidence links explicit and reviewable

---

## 12. Add crypto support

- [ ] Add wallet model
- [ ] Add exchange-account model
- [ ] Add holdings model
- [ ] Add transaction/import adapter model
- [ ] Add cost-basis method support groundwork
- [ ] Ensure crypto is scoped per entity workspace
- [ ] Ensure crypto valuation is separated from tax export logic
- [ ] Do not overclaim chain/exchange support until adapters exist

---

## 13. Build analytics

### Data/read models
- [ ] Add analytics read models or SQL views
- [ ] Add income vs expenses aggregation
- [ ] Add monthly/yearly trend models
- [ ] Add category breakdown model
- [ ] Add cash-flow model
- [ ] Add pending invoice counts/values
- [ ] Add crypto portfolio trend groundwork

### UI
- [ ] Add analytics navigation item
- [ ] Add KPI cards
- [ ] Add date-range filters
- [ ] Add chart views
- [ ] Keep analytics scoped to the active entity workspace

### Tests
- [ ] Add read-model tests
- [ ] Add filter tests
- [ ] Add performance checks for medium datasets

---

## 14. Upgrade tax from readiness to filing artifacts

- [ ] Add first-class `TaxProfile`
- [ ] Remove hidden Zurich-only assumptions from general workflows
- [ ] Keep Zurich as the first complete adapter
- [ ] Make unsupported canton coverage explicit
- [ ] Add `FilingPackage`
- [ ] Add structured export artifacts
- [ ] Keep provenance for each tax fact
- [ ] Keep deterministic rule-pack boundaries
- [ ] Add tests for package generation and validation

---

## 15. Hardening and product quality

- [ ] Add migration smoke tests
- [ ] Add migration backfill tests
- [ ] Add entity scope leak tests
- [ ] Add performance tests on realistic fixtures
- [ ] Add backup/restore tests
- [ ] Add import replay tests
- [ ] Improve error surfaces
- [ ] Improve empty/error/recovery states
- [ ] Keep auditability intact through all write flows

---

## 16. Screenshot fidelity checks

- [ ] Preserve the launch chooser’s visual simplicity
- [ ] Preserve the Overview card layout and “needs attention” emphasis
- [ ] Preserve the Inbox split-pane inspector pattern
- [ ] Preserve the Ledger split-pane pattern while evolving it toward Accounts
- [ ] Preserve the Documents empty state quality
- [ ] Improve Tax Studio so it no longer leaks technical keys
- [ ] Rework Settings to show container-level and entity-level separation clearly

---

## 17. Final validation before calling the upgrade complete

- [ ] Personal workspace data is isolated by default
- [ ] Block Consult GmbH data is isolated by default
- [ ] VitaGrowth data is isolated by default
- [ ] Switching entity workspace updates all major screens correctly
- [ ] No default list mixes personal and business records
- [ ] Migrations run on existing workspaces
- [ ] Tests pass
- [ ] Docs match the implementation
- [ ] The app still feels like AlpenLedger, not a different product
