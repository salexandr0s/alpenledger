# buildplan.md — AlpenLedger
## Full build plan for a local-first Swiss finance manager and tax-return creator

## 1. Executive summary

This plan assumes you want a **serious production-grade macOS app**, not a demo:
- local-first,
- personal + business finance,
- Swiss tax workflows,
- missing-document intelligence,
- AI-assisted but deterministic at the core.

### Recommended delivery horizon
**Full track:** ~10–14 months for a robust v1  
**Fast-track narrowed MVP:** ~4–6 months if you reduce scope to:
- one pilot canton,
- personal tax only,
- one business mode,
- no payroll,
- no external integrations beyond imports.

This document describes the **full track**.

## 2. Delivery assumptions

### Product assumptions
- macOS only for v1
- local single-user workspaces
- optional accountant export/review, but not multi-user real-time collaboration
- manual/file-based data import first
- guided export/submission first, not universal auto-submission
- AI optional; core app still works without external models
- checked-in project defaults use the latest stable Apple toolchain and latest stable package releases, not beta baselines

### Standards assumptions
The product should plan around:
- personal-tax export baseline: **eCH-0119**[^ech0119]
- future personal-tax transition readiness: **eCH-0278 draft**[^ech0278draft]
- business export baseline: **eCH-0276**[^ech0276]
- VAT export baseline: **eCH-0217** with FTA import flow[^mwstimport][^ech0217]
- electronic tax statement import: **eCH-0196**[^ech0196]
- Swiss bank/payment import patterns anchored in SIX Swiss Payment Standards and QR-bill rules[^sps][^qrbill]
- optional payroll/authority direction via Swissdec[^swissdec]

### Product strategy assumptions
- pilot canton(s) first; abstract everything else
- export-first beats “automate every portal”
- local tool bus shared by UI and AI is a core platform decision

## 3. Recommended team

### Lean but serious team
- **1 product lead / founder**
- **1 UX/product designer**
- **2 macOS/Swift engineers**
- **1 finance/tax engine engineer**
- **1 AI/orchestration engineer**
- **1 QA/automation engineer** (or shared across engineering)
- **0.2–0.5 FTE Swiss tax/accounting advisor**
- **0.1–0.2 FTE security/compliance reviewer**

### If solo / very small team
If one or two people are building this, ship in slices:
1. local ledger + docs,
2. missingness engine,
3. personal tax pack,
4. business/VAT,
5. AI.

Do not start with payroll or universal canton coverage.

## 4. Delivery strategy

### 4.1 Build the platform in this order
1. **Persistence + documents + ledger**
2. **Imports + reconciliation + missingness**
3. **Personal tax**
4. **Business/VAT**
5. **AI over safe tools**
6. **Year-end + business tax**
7. **Polish, validation, beta, distribution**

### 4.2 What not to do first
Do not start with:
- OCR perfection,
- universal bank integrations,
- universal portal automation,
- full Swissdec certification,
- broad multi-user collaboration,
- fancy dashboards.

## 5. Release slices

## Slice A — Core Local Finance Workspace
Outcome:
- the app can ingest, store, search, reconcile, and explain local finance data.

## Slice B — Personal Tax Studio
Outcome:
- the app can assemble a private tax checklist and generate a reviewable export bundle.

## Slice C — Business Finance + VAT
Outcome:
- the app can support business books and VAT periods with export support.

## Slice D — AI Copilot
Outcome:
- the user can ask reliable questions and receive provenance-backed answers.

## Slice E — Business Tax / Year-End
Outcome:
- the app can prepare a business closing and business tax export workflow.

## 6. Phase-by-phase plan

## Phase 0 — Discovery, standards matrix, and product blueprint
**Duration:** 2–3 weeks

### Goals
- lock scope for v1
- choose pilot entity types
- choose pilot canton strategy
- define canonical domain model
- finalize UI information architecture
- define rules vs AI boundaries

### Deliverables
- domain glossary
- standards matrix
- issue taxonomy
- sample user journeys
- sample datasets for testing
- product risk register

### Key tasks
- map Swiss workflows:
  - private individual,
  - sole proprietor,
  - GmbH/AG-lite
- define import sources
- define filing outputs
- define “missing evidence” rules at a domain level
- define entity separation model

### Exit criteria
- architecture direction approved
- pilot scope frozen
- sample datasets collected
- product “definition of truth” written

---

## Phase 1 — Foundation: workspace, persistence, shell UI
**Duration:** 4–5 weeks

### Goals
- create the native app shell
- implement encrypted local persistence
- implement document vault foundation
- create navigation and workspace lifecycle

### Deliverables
- Swift app shell
- workspace creation/opening
- encrypted database
- file vault
- audit log skeleton
- app settings and preferences
- basic sidebar/navigation layout

### Technical tasks
- project/module structure
- persistence migrations
- keychain integration
- content-addressed blob storage
- basic search index
- feature-flag system
- logging/error pipeline

### UX tasks
- sidebar IA
- toolbar/global search
- inspector pattern
- empty states
- first-run onboarding

### Exit criteria
- user can create/open a workspace
- files can be imported and stored locally
- database migrations are stable
- audit events and recovery path exist

---

## Phase 2 — Ledger core and document pipeline
**Duration:** 5–6 weeks

### Goals
- create authoritative finance and document models
- support raw imports and normalized transaction records
- support document classification and text extraction

### Deliverables
- account model
- transaction model
- journal model
- document model
- import job framework
- basic OCR/text extraction pipeline
- document search

### Technical tasks
- immutable raw import storage
- normalized transaction storage
- chart of accounts structure
- document type classifier
- metadata extraction
- basic evidence links
- previewable PDFs/images

### Exit criteria
- imported files become searchable documents
- transactions can be stored and reviewed
- journal entries can be represented
- source file → normalized object lineage is visible

---

## Phase 3 — Import adapters, reconciliation, and missingness engine
**Duration:** 6–8 weeks

### Goals
- make the product operational for real data
- detect missing statements and missing receipts
- reduce manual cleanup

### Deliverables
- CSV importers
- camt importer(s)
- QR-bill parser
- duplicate detection
- transfer matching
- document-to-transaction matching
- statement coverage engine
- issue list / task list

### Technical tasks
- parser plugin architecture
- fuzzy and deterministic matching
- official statement coverage model
- issue severity model
- manual override flows
- recurring vendor hints

### UX tasks
- inbox review queue
- accept/reject suggestion controls
- “why flagged” explanations
- bulk review workflows

### Exit criteria
- user can import statements and receipts
- system detects missing monthly extracts
- system flags transactions with missing evidence
- reconciliation accuracy is acceptable on sample datasets

---

## Phase 4 — Personal Tax Studio MVP
**Duration:** 7–9 weeks

### Goals
- deliver private-tax readiness for a pilot canton/federal path
- make missing personal-tax evidence visible early
- generate a reviewable personal filing package

### Deliverables
- personal tax fact model
- requirement checklist
- import path for:
  - salary certificates,
  - eCH-0196 tax statements,
  - pillar 2/3a certificates,
  - health-insurance certificates
- eCH-0119-based export path
- validation report
- tax review UI

### Technical tasks
- canonical tax-fact store
- eCH-0119 mapping adapter
- canton extension framework
- evidence requirement engine
- filing completeness rules
- export packaging and validation

### UX tasks
- Tax Studio nav
- filing status summary
- missing-document grouping
- field-by-field explanation inspector
- export review screen

### Exit criteria
- user can prepare a pilot personal return package
- required evidence gaps are surfaced
- export validates against target schema/business rules
- every tax fact is traceable back to evidence

---

## Phase 5 — Business finance core + VAT
**Duration:** 7–9 weeks

### Goals
- support small-company/sole-proprietor bookkeeping needs
- prepare VAT periods and exports
- create stronger business issue detection

### Deliverables
- business chart of accounts templates
- AP/AR-lite
- VAT codes and period model
- VAT reconciliation report
- eCH-0217 export path
- asset register and depreciation basics
- owner-draw / personal-vs-business separation flows

### Technical tasks
- entity-linked posting rules
- tax code mapping
- VAT period lock
- business receipt requirement policy
- invoice/expense linking
- year-end pre-close checks

### Exit criteria
- VAT period can be computed and exported
- business expenses can be matched to evidence
- mixed personal/business flows are reviewable
- unresolved business bookkeeping issues are visible

---

## Phase 6 — AI Copilot and safe finance chat
**Duration:** 5–7 weeks

### Goals
- add a genuinely useful AI layer
- keep AI bounded by domain tools and approvals
- expose value in Q&A, triage, and guidance

### Deliverables
- internal tool bus
- router agent
- intake/triage agent
- CFO/Q&A agent
- missing evidence agent
- explanation agent
- local model provider integration
- optional cloud provider integration

### Technical tasks
- tool registry
- chat session store
- read-only reporting views
- proposal persistence
- confidence schema
- provenance/citation rendering
- privacy modes

### UX tasks
- Copilot view
- inline answers with source refs
- one-click “turn answer into task”
- proposal review surfaces

### Exit criteria
- user can ask trusted questions about finance data
- AI answers cite sources
- AI does not mutate authoritative state directly
- AI can explain missingness and tax readiness

---

## Phase 7 — Business tax, year-end close, and export hardening
**Duration:** 7–9 weeks

### Goals
- support business tax export path
- support year-end closing workflow
- improve reviewability for accountants/fiduciaries

### Deliverables
- year-end closing checklist
- draft adjusting-entry workflow
- business-tax canonical facts
- eCH-0276-based export path
- accountant review bundle
- export manifests and diagnostics

### Technical tasks
- financial statement mapping
- business tax mapping
- draft closing journal pipeline
- export diffing
- per-standard versioning
- signed rule-pack handling groundwork

### Exit criteria
- business year-end checklist works on pilot datasets
- E-Bilanz / E-Tax package can be generated
- blockers are visible and explainable
- accountant review pack is usable

---

## Phase 8 — Beta hardening, QA, localization, and distribution
**Duration:** 6–8 weeks

### Goals
- stabilize for real users
- reduce support burden
- prepare rollout and update process

### Deliverables
- beta onboarding
- diagnostics/report export
- migration tests
- crash handling polish
- local backup/restore
- notarized distribution pipeline
- documentation/help center baseline
- localization framework

### QA tasks
- golden-file imports
- regression suite
- export validation suite
- performance suite for large workspaces
- AI evaluation set
- migration/restore drills

### Exit criteria
- beta users can complete full core workflows
- supportable logging exists
- restore works
- upgrade path is safe
- validation pass rates are strong

---

## Phase 9 — Post-v1 expansion
**Duration:** ongoing

### Recommended next items
1. additional cantons
2. broader business entity support
3. payroll imports
4. Swissdec-compatible roadmap
5. optional Codex/MCP integration
6. standards/rules updater
7. accountant review mode and collaboration packs
8. more advanced analytics and forecasting

## 7. Backlog by workstream

## Workstream A — Foundation
- workspace lifecycle
- encryption
- file vault
- migrations
- search index
- backup/export
- logging

## Workstream B — Finance domain
- accounts
- transactions
- journal
- categories
- tax codes
- assets
- period locking
- close flows

## Workstream C — Documents
- document classification
- OCR/text extraction
- evidence links
- search
- duplicate detection
- request/missingness logic

## Workstream D — Swiss import/export standards
- camt imports
- QR-bill parsing
- eCH-0196 import
- eCH-0119 export
- eCH-0217 export
- eCH-0276 export
- schema validation fixtures

## Workstream E — AI / agents
- tool bus
- read models
- router
- specialist agents
- proposal store
- provenance rendering
- privacy controls

## Workstream F — UX
- inbox
- ledger views
- document inspector
- tax studio
- business screens
- copilot
- settings/help

## Workstream G — QA / compliance
- standards tests
- import regression packs
- sample datasets
- rule-pack tests
- AI evaluation harness
- backup/restore tests
- release checklists

## 8. Acceptance criteria by product slice

## Slice A acceptance
- imported files persist locally
- transactions are reviewable
- document search works
- reconciliation and issue queues exist

## Slice B acceptance
- personal tax checklist is produced
- evidence gaps are identified
- return export bundle can be generated and validated

## Slice C acceptance
- VAT periods reconcile to ledger
- business expenses can be evidence-linked
- VAT export works

## Slice D acceptance
- chat answers are provenance-backed
- tool access is safe
- proposals are reviewable and reversible

## Slice E acceptance
- year-end checklist works
- business-tax export package exists
- accountant review bundle is practical

## 9. Key risks and mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| Cantonal variability | “Swiss tax” is not one UI/flow | pilot one canton, abstract adapters |
| Standards churn | filing formats and rules change | versioned rule packs and adapter layer |
| eCH-0278 transition | personal-tax standard is evolving | implement canonical tax facts + adapter abstraction |
| Bank format diversity | imports are messy | plugin parsers + golden datasets |
| AI hallucinations | destroys trust | tool-first design + deterministic engine |
| No universal auto submission | many cantons/AGOV flows vary | export-first, guided submission |
| Payroll complexity | Swissdec/certification is real work | phase later, do not block v1 |
| Security expectations | finance + tax data is sensitive | local-first, encryption, audit log |
| Small-team overload | product is broad | release slices; avoid payroll early |
| Over-automation | risky in accounting | suggestions + approvals, no silent writes |

## 10. Pilot strategy recommendation

### Personal pilot
Choose **one canton** for end-to-end polish first.  
Recommendation: start with a high-usage canton such as Zurich unless you already have a better anchor customer elsewhere.

### Business pilot
Choose **one business profile** first:
- sole proprietor consultant/freelancer, or
- small GmbH with simple VAT.

Do not try to perfect:
- retail + inventory,
- payroll-heavy business,
- construction-specific workflows,
- multi-company consolidation
in the first release.

## 11. Quality gates

At the end of every phase, require:
1. migration tests green,
2. sample dataset regression green,
3. no silent data-loss path,
4. issue list accuracy review,
5. rule/adapter version pinned,
6. UX walkthrough on real workflows,
7. support notes updated.

## 12. Definition of done

A feature is done only when:
- domain model exists,
- persistence/migration exists,
- UI path exists,
- validation exists,
- auditability exists,
- errors are user-visible,
- at least one realistic dataset passes through it,
- docs/help text exist,
- it works offline unless explicitly a network feature.

## 13. Recommended founder priorities

If you are driving this personally, spend your attention in this order:
1. **domain correctness**
2. **import quality**
3. **missingness engine**
4. **filing adapter validation**
5. **AI safety/provenance**
6. **UI polish**
7. **growth features**

That order matters. A beautiful finance app with untrustworthy tax data will fail.

## 14. Final recommendation

Build AlpenLedger as a **deterministic local finance engine with an evidence graph**, then layer Swiss filing adapters and AI on top.  
That path gives you the highest chance of shipping something that users can trust with real personal and business taxes.

---

## Cross-links
- [vision.md](vision.md)
- [architecture.md](architecture.md)
- [agents.md](agents.md)

---

## References
[^ech0119]: eCH-0119 E-Tax Filing V4.0.0 — https://www.ech.ch/de/ech/ech-0119/4.0.0
[^ech0278draft]: eCH-0278 E-Tax NP V1.0.0 (draft) — https://www.ech.ch/de/ech/ech-0278/1.0.0
[^ech0276]: eCH-0276 E-Bilanz und E-Tax JP V1.0.0 — https://www.ech.ch/de/ech/ech-0276/1.0.0
[^mwstimport]: Federal Tax Administration, “Mehrwertsteuer online abrechnen” — https://www.estv.admin.ch/de/mwst-online-abrechnen
[^ech0217]: eCH-0217 Spezifikation E-MWST V2.0.0 — https://www.ech.ch/de/ech/ech-0217/2.0.0
[^ech0196]: eCH-0196 E-Steuerauszug V2.2.0 — https://www.ech.ch/de/ech/ech-0196/2.2.0
[^sps]: SIX, “ISO 20022 – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/iso-20022.html
[^qrbill]: SIX, “QR-bill – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/qr-bill.html
[^swissdec]: Swissdec — https://swissdec.ch/
