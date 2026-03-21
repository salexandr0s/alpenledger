# prompt_upgrade.md

You are upgrading the repository `https://github.com/salexandr0s/alpenledger`.

Your job is to turn the existing codebase into a production-grade, local-first Swiss finance management application for both personal and business use.

This is **not** a greenfield project.  
This is **not** a web rewrite.  
This is **not** a demo polish pass.

You must work inside the current native macOS Swift architecture and upgrade it correctly.

---

## 1. Core instructions

### Non-negotiable

1. **Do not rewrite this into TypeScript/web.**
2. **Preserve the current native macOS Swift/local-first architecture.**
3. **Do not bolt more features onto the existing root god object.**
4. **Fix entity separation before expanding features.**
5. **Keep the current dark, minimal visual language shown in the screenshots.**
6. **Use deterministic logic for money/tax truth.**
7. **Use migrations, tests, and docs updates for every structural change.**
8. **Do not pretend unsupported Swiss tax coverage exists.**
9. **Do not silently guess ambiguous data during migration.**
10. **Do not stop after surface-level UI changes.**

---

## 2. What the repository already is

The repo is already a serious macOS Swift project with:

- SwiftUI app shell
- XcodeGen
- Swift Package Manager modules
- GRDB-backed SQLite storage
- encrypted local database opening
- encrypted blob/document storage
- Keychain/file secret handling
- tests
- a coherent feature shell

Existing modules include:

- `ALDomain`
- `ALAudit`
- `ALStorage`
- `ALWorkspace`
- `ALImports`
- `ALLedger`
- `ALDocuments`
- `ALEvidence`
- `ALTaxCore`
- `ALTaxCH`
- `ALDesignSystem`
- `ALFeatures`

Do not discard this structure unless there is a compelling reason, and if you do change it, explain exactly why.

---

## 3. What you must do first

Before making major code changes:

1. clone/open the repository
2. read every first-party file in the repo
3. inspect the current package graph and storage layer
4. inspect the main app shell and feature views
5. study all provided screenshots
6. map what the screenshots show to the live code
7. identify where the current implementation conflicts with the target product vision

You must specifically inspect these files early:

- `project.yml`
- `Packages/AlpenLedgerKit/Package.swift`
- `App/AlpenLedgerApp/AlpenLedgerApp.swift`
- `App/AlpenLedgerApp/Root/RootSplitView.swift`
- `App/AlpenLedgerApp/Root/WorkspaceAppModel.swift`
- `App/AlpenLedgerApp/DependencyContainer.swift`
- `App/AlpenLedgerApp/AppRuntimeConfiguration.swift`
- `App/AlpenLedgerApp/Navigation/AppSection.swift`
- `Packages/AlpenLedgerKit/Sources/ALStorage/Migrations.swift`
- `Packages/AlpenLedgerKit/Sources/ALStorage/DatabaseFoundation.swift`
- `Packages/AlpenLedgerKit/Sources/ALWorkspace/WorkspaceService.swift`
- `Packages/AlpenLedgerKit/Sources/ALWorkspace/LegalEntityService.swift`
- `Packages/AlpenLedgerKit/Sources/ALLedger/FinancialAccountService.swift`
- `Packages/AlpenLedgerKit/Sources/ALLedger/TransactionService.swift`
- `Packages/AlpenLedgerKit/Sources/ALDocuments/DocumentService.swift`
- `Packages/AlpenLedgerKit/Sources/ALDocuments/DocumentQueryService.swift`
- `Packages/AlpenLedgerKit/Sources/ALEvidence/EvidenceRefreshService.swift`
- `Packages/AlpenLedgerKit/Sources/ALEvidence/IssueService.swift`
- `Packages/AlpenLedgerKit/Sources/ALEvidence/RequirementService.swift`
- `Packages/AlpenLedgerKit/Sources/ALTaxCore/TaxComputationService.swift`
- `Packages/AlpenLedgerKit/Sources/ALTaxCore/TaxValidationService.swift`
- docs under `docs/`

---

## 4. Current screenshot-based reality

The screenshots show that the app already has:

- a workspace chooser
- Overview
- Inbox
- Ledger
- Documents
- Tax Studio
- Settings

They also show the main architectural problem:

- one workspace contains multiple entities
- personal and business are separated only weakly
- Tax Studio uses entity dropdowns
- Settings treats multiple entities as nested workspace members
- Ledger and documents are still effectively shared inside one workspace shell

This is not good enough for the target product.

---

## 5. The most important architecture change

You must introduce a **two-level model**:

### Physical container

Keep the existing `Workspace` concept as the physical encrypted container on disk.

### User-facing scope

Add a new **`EntityWorkspace`** concept that becomes the real switched context in the UI.

The app must behave like:

- open one physical local workspace
- switch between entity workspaces inside it
- each entity workspace is isolated by default

Examples of entity workspaces:

- Personal — Alexandros
- Block Consult GmbH
- VitaGrowth

Each entity workspace must own its own:

- accounts
- transactions
- categories
- invoices
- documents
- tax profile
- tax years
- analytics
- issues / requirements / proposals

Cross-entity views can exist later, but they must be explicit, not the default.

---

## 6. Product target

Build AlpenLedger into a serious local-first Swiss finance workspace that supports:

- personal finances
- multiple businesses
- banking imports
- invoices
- generic documents
- tax readiness and filing artifacts
- analytics
- crypto support
- deterministic tax logic with provenance

However, do this in phases.

Do not build everything at once.

---

## 7. Phase order

### Phase 1 — audit, restructure, and scoping
This is mandatory before new features.

You must:

- sync docs with live code
- add `EntityWorkspace`
- reduce the root app god object
- add top-level entity switching
- make all major screens active-entity scoped
- complete missing foundational models:
  - `TaxProfile`
  - `Category`
  - `InvoiceRecord`
  - `JournalEntry`
  - `JournalLine`
  - `FilingPackage`

### Phase 2 — invoice management
Build:

- filesystem watcher
- invoice upload
- rename/archive rules
- metadata review
- invoice ↔ transaction matching

### Phase 3 — accounts and crypto
Build:

- stronger bank account support
- improved imports
- entity-scoped categories
- crypto wallets and exchange accounts

### Phase 4 — analytics
Build:

- entity-scoped dashboards
- query/read models
- charts and KPI cards

### Phase 5 — tax reporting
Build:

- proper tax profiles
- filing packages
- adapter-driven exports
- Zurich personal as first complete implementation
- explicit unsupported-state handling for other cantons until implemented

### Phase 6 — hardening
Add:

- migration safety
- backup/restore verification
- realistic fixtures
- UI tests
- performance checks
- documentation cleanup

---

## 8. Technical rules

### Architecture

- Keep package boundaries meaningful
- Prefer refactoring within current modules over adding lots of new package targets
- Move orchestration out of `WorkspaceAppModel.swift`
- Add coordinators/session state objects where needed
- Do not let features talk directly to storage

### Storage

- Keep SQLite + encrypted blob storage
- Store money as integer minor units
- Use migrations
- Preserve import immutability
- Preserve auditability
- Use explicit scoping
- Use read models / views for analytics where helpful

### Tax

- Keep tax deterministic
- Use rule-pack style boundaries
- Do not hardcode hidden Zurich assumptions in generic workflows
- Do not claim all cantons are supported unless they are

### OCR / extraction

- PDF text first
- OCR second
- human review for low-confidence results
- no silent truth from OCR guesses

### UX

- Keep the existing dark minimal design
- Keep split views and inspectors where they already work
- preserve the current visual identity
- improve structure, not gimmicks

---

## 9. Required files to create or modify early

### Create

- `docs/adr/ADR-003-entity-workspace-scoping.md`
- `App/AlpenLedgerApp/Root/AppCoordinator.swift`
- `App/AlpenLedgerApp/Root/ActiveWorkspaceSession.swift`
- `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherView.swift`
- `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherState.swift`
- `Packages/AlpenLedgerKit/Sources/ALDomain/EntityWorkspace.swift`
- `Packages/AlpenLedgerKit/Sources/ALDomain/TaxProfile.swift`
- `Packages/AlpenLedgerKit/Sources/ALDomain/Category.swift`
- `Packages/AlpenLedgerKit/Sources/ALDomain/InvoiceRecord.swift`

### Modify

- `App/AlpenLedgerApp/Root/WorkspaceAppModel.swift`
- `App/AlpenLedgerApp/Root/RootSplitView.swift`
- `App/AlpenLedgerApp/AlpenLedgerApp.swift`
- `App/AlpenLedgerApp/DependencyContainer.swift`
- `App/AlpenLedgerApp/AppRuntimeConfiguration.swift`
- `Packages/AlpenLedgerKit/Sources/ALStorage/Migrations.swift`
- `Packages/AlpenLedgerKit/Sources/ALStorage/DatabaseFoundation.swift`
- services under `ALWorkspace`, `ALLedger`, `ALDocuments`, `ALEvidence`, `ALTaxCore`
- feature-state code under `ALFeatures`
- docs under `docs/`

---

## 10. How to work

### Do the work in small, coherent increments

For each increment:

1. explain the goal
2. list the files to change
3. implement
4. run relevant tests
5. summarize what changed
6. identify next step

### Always keep docs in sync

If the live code changes architecture, update docs in the same branch/PR.

### Always protect real data

Do not destroy or silently reinterpret existing workspace data.  
If migration/backfill is ambiguous, surface it as a review state or migration issue.

### Always keep design continuity

The upgraded app should still look and feel like AlpenLedger.  
Do not introduce a new visual system unless explicitly required.

---

## 11. What “done” means

A phase is not done because the UI looks plausible.

A phase is done only when:

- domain model is right
- storage model is right
- migrations exist
- services are scoped correctly
- UI works
- tests pass
- docs match implementation
- there is no default personal/business cross-contamination

---

## 12. Output format expected from you

At the end of each working session, provide:

### Summary
What you changed and why.

### Files changed
Exact file list.

### Schema / migration notes
What changed in persistence and how compatibility is handled.

### Tests run
What you executed and what passed.

### Risks / blockers
Anything ambiguous or dangerous.

### Next recommended step
What should be done next.

---

## 13. Final behavioral instruction

Be conservative about truth, aggressive about cleanup, and disciplined about scope.

Preserve what is already strong in this repository:
- local-first architecture
- encrypted storage
- good visual shell
- modular Swift packages
- issue/evidence orientation

Fix what is currently wrong:
- weak entity separation
- overloaded root state model
- stale docs
- incomplete canonical models

Build AlpenLedger into a trustworthy multi-entity Swiss finance product by upgrading the existing native foundation, not by replacing it.
