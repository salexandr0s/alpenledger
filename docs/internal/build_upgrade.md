# build_upgrade.md

# AlpenLedger Upgrade Build Plan

## Purpose

This document is the execution plan for upgrading `salexandr0s/alpenledger` into a production-grade, local-first Swiss finance management tool for both personal and business use.

It is written for a coding agent that will work directly in the existing repository.

The most important instruction is this:

**Do not rewrite the product into a web/TypeScript stack.**  
The repository is already a substantial native macOS Swift codebase with encrypted local storage, modular packages, migrations, tests, and a coherent UI shell. Upgrade the existing architecture instead of discarding it.

---

## Current repository reality

### Existing stack

AlpenLedger already ships as a **native macOS Swift app** with:

- SwiftUI app shell
- XcodeGen project generation
- Swift Package Manager module boundaries
- GRDB-backed SQLite storage
- encrypted local database opening
- encrypted blob/document storage
- Keychain/file secret stores
- FTS search
- package and app tests
- dark-mode-first macOS UI

### Existing modules

Current package modules include:

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

### Existing UI, confirmed by screenshots

The current UI already includes:

- workspace chooser
- overview
- inbox
- ledger
- documents
- tax studio
- settings

The screenshots show a strong visual baseline:

- dark minimal shell
- grouped sidebar
- card-based overview
- split-pane inbox/inspector layout
- split-pane ledger/accounts layout
- good empty states
- consistent toolbar and window chrome

These patterns should be preserved.

### Current architectural mismatch

The live app currently models:

- one physical workspace
- many legal entities inside it
- entity selection via dropdowns and mixed lists

The target product needs:

- **clean, switched entity workspaces**
- strong personal vs business separation
- one active scope at a time
- no mixing of accounts/documents/issues across entities unless explicitly requested

This mismatch is the first thing to fix.

---

## Product upgrade thesis

### Keep

Keep the following foundations:

- native macOS Swift architecture
- local-first storage
- encrypted database and blob vault
- current design language
- current package/module structure
- issue/evidence/tax-readiness orientation
- integer money storage
- deterministic rule-based tax core

### Change

Upgrade the system so that:

- the current physical `Workspace` remains the local encrypted container on disk
- a new logical **entity workspace** becomes the user-facing scope
- the app gets a top-level entity switcher
- every business/personal workspace becomes operationally separate
- accounting, documents, invoices, categories, tax, and analytics become entity-scoped by default

### Target terminology

To reduce disruption and avoid a destructive rewrite, use this naming model:

- **Workspace** = physical encrypted local container on disk
- **EntityWorkspace** = switched, user-facing finance workspace for one legal entity

This preserves the existing storage architecture while giving the user the separation they need.

---

## Non-negotiable decisions

1. **Do not rewrite to web/TypeScript.**
2. **Do not bolt more features onto `WorkspaceAppModel.swift`.**
3. **Do not keep personal and business data mixed in the same working view.**
4. **Do not claim canton-agnostic support until abstractions and rule-pack boundaries are real.**
5. **Do not invent tax facts or Swiss compliance behavior.**
6. **Do not store money as floating point.**
7. **Do not implement analytics as fragile client-side loops over ad hoc arrays.**
8. **Do not let AI or heuristics become authoritative truth.**
9. **Do not mutate raw imports in place.**
10. **Do not ship changes without migrations, tests, and updated docs.**

---

## Current problems to resolve first

### 1. Wrong scoping model

Today, the UI and storage are still built around a single workspace holding multiple entities.  
This causes:

- mixed personal/business navigation
- mixed document vault behavior
- mixed account lists
- tax studio entity dropdowns instead of top-level context switching
- future analytics confusion

### 2. Root app model is overloaded

`App/AlpenLedgerApp/Root/WorkspaceAppModel.swift` currently owns too much:

- navigation
- service orchestration
- selection state
- feature snapshots
- import flows
- link flows
- formatting
- test fixture helpers

This must be decomposed before further expansion.

### 3. Docs are stale relative to live code

Architecture docs and ADRs still read like the scaffold is not built yet.  
The repository already contains real app and storage code. Docs must be brought back in sync.

### 4. The data model is incomplete for the target product

The live repo still lacks some key first-class models for the target roadmap:

- `EntityWorkspace`
- `TaxProfile`
- `Category`
- `InvoiceRecord`
- `JournalEntry`
- `JournalLine`
- `FilingPackage`

### 5. Business support is incomplete

The repo has legal entity concepts, but the live UI and services are still closer to “natural person / sole proprietor pilot” than a full business system.

### 6. Tax support is still narrow in practice

The live app wires a Zurich personal tax adapter directly.  
The architecture must become truly rule-pack based, with Zurich as the first working implementation rather than the hidden default for everything.

---

## Target end state

The final product should support:

- Personal — Alexandros
- Block Consult GmbH
- VitaGrowth
- future businesses

Each entity workspace must own its own:

- bank accounts
- crypto wallets/exchange accounts
- transactions
- invoice store
- generic document vault
- categories
- tax profile
- tax years
- issues/requirements/proposals
- analytics dashboards
- filing/export artifacts

### Final UX direction

Keep the current visual language, but evolve the information architecture toward:

- entity workspace switcher
- dashboard
- inbox
- accounts
- invoices
- documents
- tax
- analytics
- settings

It is acceptable to keep internal domain names such as “ledger” and “tax studio”, but user-facing structure should become clearer.

---

## Recommended repo-level structure changes

Do not explode the package graph unnecessarily. The existing modules are good enough for now.

Refactor within the current structure.

### App layer

Add/reshape:

```text
App/AlpenLedgerApp
  Root/
    AppCoordinator.swift
    ActiveWorkspaceSession.swift
    WorkspaceSwitcherState.swift
  Navigation/
    WorkspaceSwitcherView.swift
    AppSection.swift
  Commands/
    ImportCommands.swift
    NavigationCommands.swift
```

### Domain additions

Add:

```text
Packages/AlpenLedgerKit/Sources/ALDomain
  EntityWorkspace.swift
  TaxProfile.swift
  Category.swift
  InvoiceRecord.swift
```

Later phases may also add:

```text
  CryptoWallet.swift
  ExchangeAccount.swift
  AssetLot.swift
  PriceSnapshot.swift
```

### Feature organization

Refactor `ALFeatures` so each feature owns its own models and state-building helpers instead of relying on one giant root model.

Suggested grouping:

```text
ALFeatures/
  Overview/
  Inbox/
  Accounts/
  Invoices/
  Documents/
  Tax/
  Analytics/
  Settings/
```

This can be done incrementally without adding more package targets yet.

---

## Storage and schema direction

## Keep

Keep the existing encrypted SQLite + encrypted blob vault approach.

## Add

### New tables / models required in early upgrade work

- `entityWorkspaces`
- `taxProfiles`
- `categories`
- `invoiceRecords`
- `journalEntries`
- `journalLines`
- `filingPackages`

### Scope enforcement rule

Every operational record must be explicitly scoped.

At minimum, the following must have an explicit owning `entityWorkspaceId` or resolvable entity scope:

- financial accounts
- transactions
- documents
- invoices
- issues
- requirements
- tax facts
- analytics queries
- filing packages

### Migration strategy

Do not drop or replace current data.

Instead:

1. add `entityWorkspaces`
2. backfill one `EntityWorkspace` per existing `LegalEntity`
3. migrate views/services to use active entity workspace scope
4. backfill records using existing entity linkage where possible
5. surface ambiguous records into a review queue rather than silently guessing

### Invoice modeling rule

Keep `Document` as the generic binary/source artifact.

Add `InvoiceRecord` as invoice-specific structured metadata linked to one `Document`.

This keeps the generic vault and the invoice workflow separate without losing provenance.

---

## Phase plan

# Phase 1 — Audit, scoping restructure, and core schema completion

## Goal

Fix the architecture before new feature growth.

## Required work

### Documentation sync

Update:

- `docs/vision.md`
- `docs/architecture.md`
- `docs/architecture-pass-v1.md`
- `docs/buildplan.md`
- `docs/adr/ADR-001-local-core-and-module-boundaries.md`
- `docs/adr/ADR-002-persistence-and-canonical-model.md`

Create:

- `docs/adr/ADR-003-entity-workspace-scoping.md`

### Root app decomposition

Refactor:

- `App/AlpenLedgerApp/Root/WorkspaceAppModel.swift`
- `App/AlpenLedgerApp/Root/RootSplitView.swift`
- `App/AlpenLedgerApp/AlpenLedgerApp.swift`
- `App/AlpenLedgerApp/DependencyContainer.swift`
- `App/AlpenLedgerApp/AppRuntimeConfiguration.swift`

Create:

- `App/AlpenLedgerApp/Root/AppCoordinator.swift`
- `App/AlpenLedgerApp/Root/ActiveWorkspaceSession.swift`
- `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherView.swift`
- `App/AlpenLedgerApp/Navigation/WorkspaceSwitcherState.swift`

### Domain additions

Create:

- `ALDomain/EntityWorkspace.swift`
- `ALDomain/TaxProfile.swift`
- `ALDomain/Category.swift`
- `ALDomain/InvoiceRecord.swift`

### Storage and migrations

Modify:

- `ALStorage/Migrations.swift`
- `ALStorage/DatabaseFoundation.swift`

Create repositories as needed for:

- entity workspace
- tax profile
- category
- invoice record
- journal entry
- journal line
- filing package

### Service refactor

Refactor the main query/mutation services so they work through an active entity workspace session:

- `ALWorkspace/WorkspaceService.swift`
- `ALWorkspace/LegalEntityService.swift`
- `ALLedger/FinancialAccountService.swift`
- `ALLedger/TransactionService.swift`
- `ALDocuments/DocumentService.swift`
- `ALDocuments/DocumentQueryService.swift`
- `ALEvidence/EvidenceRefreshService.swift`
- `ALEvidence/RequirementService.swift`
- `ALEvidence/IssueService.swift`
- `ALTaxCore/TaxComputationService.swift`
- `ALTaxCore/TaxValidationService.swift`

### UI change

Add a top-level entity workspace switcher similar to Slack’s workspace switching model.

The current launch chooser may stay, but once inside a physical workspace, the active entity workspace must be switched cleanly.

### Acceptance criteria

Phase 1 is complete only when:

- the codebase has an explicit `EntityWorkspace` model
- the root app model is materially decomposed
- all primary screens are scoped to the active entity workspace
- personal and business records are no longer co-mingled by default
- migrations pass
- UI tests cover switching and scoped visibility
- docs and ADRs match reality

---

# Phase 2 — Invoice management and filesystem intake

## Goal

Turn documents into a real invoice workflow.

## Required work

### Domain / storage

Add invoice-specific metadata and workflow states:

- date
- vendor
- amount
- currency
- category
- deductible yes/no
- VAT rate/amount
- payment status
- notes/tags
- linked transaction
- confidence/review state

### Filesystem workflow

Each entity workspace must have:

- configurable invoice inbox folder
- configurable archive folder
- file watcher
- automatic ingestion
- rename-and-archive behavior

Rename format:

```text
YYYY.MM.DD_VendorOrName_Description.pdf
```

Archive format:

```text
/{entity-workspace}/{year}/{month}/
```

### UI

Build:

- drag-and-drop invoice upload
- bulk upload
- review/confirm metadata screen
- invoice list with filters
- invoice detail inspector
- transaction matching flow

### OCR / extraction

Pipeline order:

1. native PDF text extraction
2. structured parsing
3. OCR fallback
4. optional heuristic enrichment

Do not make OCR guesses authoritative without review.

### Acceptance criteria

- invoices can be ingested from filesystem and UI
- originals are preserved
- archive and rename rules work
- metadata review exists
- linking to transactions works
- ambiguous extractions become review tasks, not silent truth

---

# Phase 3 — Accounts, banking, and crypto

## Goal

Expand from pilot banking to full finance coverage.

## Required work

### Bank accounts

Support:

- manual account creation
- CSV import
- Swiss statement formats: CSV, MT940, CAMT
- multiple accounts per entity workspace
- balances and histories

### Crypto

Add models and adapters for:

- decentralized wallets
- centralized exchange accounts
- holdings
- transfers
- cost basis
- realized/unrealized gains

Use plugin/adaptor architecture.

### Categorization

Make categories first-class and configurable per entity workspace.

### Matching

Improve:

- invoice ↔ transaction matching
- transfer detection
- duplicate detection
- statement coverage

### Acceptance criteria

- one entity workspace can independently manage multiple bank accounts
- one entity workspace can independently manage crypto holdings
- imports are idempotent
- categories are not shared across entity workspaces unless intentionally copied
- mixed personal/business contamination is impossible by default

---

# Phase 4 — Analytics dashboard

## Goal

Build rich, entity-scoped analytics without corrupting the canonical model.

## Required work

### Read model strategy

Create read models / SQL views for:

- spend by month
- income vs expenses
- category breakdown
- net result trend
- cash flow
- pending invoices
- crypto portfolio value
- year-over-year comparison

### UI

Add an analytics section with:

- KPI cards
- charts
- filters
- date ranges
- entity-scoped summaries

Use the existing visual language.

### Performance rule

Analytics should query read models or SQL views, not reconstruct everything in memory from root arrays.

### Acceptance criteria

- analytics are entity-scoped
- filters are deterministic and tested
- dashboards do not slow the app materially
- charts use stable read models, not ad hoc calculations in view code

---

# Phase 5 — Tax reporting and filing artifacts

## Goal

Move from readiness into real filing outputs.

## Required work

### Tax profile

Each entity workspace needs a real tax profile including:

- canton
- legal form
- tax identifiers
- fiscal year
- tax mode/settings

### Rule-pack architecture

Keep Zurich personal as the first complete adapter, but make the system genuinely adapter-driven.

### Exports

Add first-class `FilingPackage` support for:

- CSV
- PDF summary packs
- XML/export stubs where applicable

### Business coverage

Support:

- personal tax
- sole proprietor workflows
- GmbH/business tax groundwork
- VAT exports

### Acceptance criteria

- filing packages are versioned artifacts
- every tax fact has provenance
- unsupported cantons are clearly marked unsupported, not implied
- the app can generate reviewable tax outputs without hiding uncertainty

---

# Phase 6 — Hardening, release quality, and productization

## Goal

Make the system safe for real users.

## Required work

- migration safety
- data repair tools
- backup/restore verification
- better test fixtures
- performance tests
- UI tests for major flows
- clearer error handling
- portable workspace export/import
- documentation for real users

### Acceptance criteria

- migrations are reversible or recoverable
- backups restore correctly
- major workflows have automated coverage
- the app can handle real multi-entity data without scope leaks

---

## Screenshot-driven UI guidance

Use the screenshots as a design anchor.

### Launch screen

Keep:

- workspace chooser
- recent workspaces
- clean centered layout

### Overview

Keep:

- summary cards
- “needs attention” emphasis
- recent activity panel

Change:

- the screen must reflect only the active entity workspace, not mixed entity counts

### Inbox

Keep:

- issue/proposal/import triage
- inspector split

Change:

- group and filter by active entity workspace first

### Ledger

Keep:

- split-pane pattern
- account list and detail relationship

Change:

- evolve toward user-facing “Accounts”
- add stronger account metadata and import workflows

### Documents

Keep:

- empty state
- preview/search pattern

Change:

- split generic documents from invoice workflow
- make active entity scope obvious

### Tax Studio

Keep:

- readiness checklist pattern

Change:

- remove raw concept-code leakage
- use the active entity workspace instead of a clumsy dropdown-driven workflow

### Settings

Change the most here:

- replace the current “many entities under one workspace” posture with a container + entity workspace model
- surface switcher and scoped settings clearly

---

## PR / milestone strategy

Recommended execution order:

1. docs + ADR sync
2. entity workspace schema + migrations
3. root app/session refactor
4. scoped UI switcher
5. category/tax profile/invoice schema
6. invoice intake and review flows
7. bank import expansion
8. crypto adapters
9. analytics read models and UI
10. filing packages and tax exports
11. hardening and polish

Prefer smaller coherent PRs over one massive refactor.

Each PR must include:

- summary
- changed files
- migration notes
- test notes
- data compatibility notes
- next-step note

---

## Definition of done

A feature is done only when:

- the domain model is correct
- storage and migrations are present
- scoping is explicit
- UI exists
- tests exist
- docs are updated
- error cases are handled
- provenance is preserved
- no personal/business scope leak is possible by default

---

## Final instruction to the coding agent

Upgrade this repository as a **serious native local-first finance product**, not as a demo and not as a rewrite.

Preserve what is already strong.  
Refactor what is currently wrong.  
Make entity separation real before adding more surface area.
