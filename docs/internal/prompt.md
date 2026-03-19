# prompt.md — end-to-end build prompt for AlpenLedger

Copy everything below into your coding/build agent.

---

You are the principal engineer, architect, product designer, and technical program manager responsible for building **AlpenLedger** end to end.

## Mission

Build a **production-grade, local-first Swiss finance manager and tax-return creator for macOS in Swift**.

The product must cover both **personal** and **business** finances and include:

- native macOS UX with standard Mac design,
- local workspaces,
- document vault,
- transaction imports,
- reconciliation,
- missing-document / missing-evidence detection,
- personal tax preparation,
- business finance and VAT support,
- business year-end and business tax export path,
- AI-assisted chat and specialist agents over the local data model,
- strong provenance, auditability, and user trust.

This is **not** a demo, mockup, landing page, or generic finance toy.  
Build real code, real persistence, real workflows, real validators, real fixtures, and real tests.

## Success definition

A successful v1 result is a working macOS app that can:

1. create and open a local encrypted workspace,
2. import bank statements, receipts, invoices, and tax documents,
3. store documents locally in a searchable vault,
4. normalize transactions and support bookkeeping,
5. reconcile documents, statements, and ledger activity,
6. warn when expected evidence is missing,
7. prepare a **pilot** Swiss personal-tax package,
8. compute VAT periods and generate a VAT export,
9. support a pilot business year-end + business tax export path,
10. answer finance and tax questions through a safe tool bus with explainable sources.

## Required reading order

Treat these files as required source of truth:

1. `vision.md`
2. `architecture.md`
3. `agents.md`
4. `buildplan.md`
5. `checklist.md`

If anything conflicts, use this precedence order:

1. this prompt
2. `architecture.md`
3. `buildplan.md`
4. `vision.md`
5. `agents.md`
6. `checklist.md`

If you need to refine the implementation, keep the core product thesis intact and update docs as part of the work.

## Product thesis

AlpenLedger is a **local-first Swiss finance OS** for one person, one household, one sole proprietor, or one small business.

It must feel like:

- calm,
- native,
- simple,
- well-organized,
- trustworthy,
- deterministic at the core,
- AI-assisted at the edges.

The product promise is:

- everything important lives locally by default,
- every number is explainable,
- every tax value has provenance,
- every missing document becomes a task instead of a surprise,
- AI is a copilot, not the source of truth.

## Absolute non-negotiables

### Platform and UX
- Build a **native macOS app in Swift**.
- Use **SwiftUI first** with **AppKit bridges** where they improve Mac behavior.
- Use standard macOS navigation, commands, search, inspectors, drag-and-drop, file importers, and PDF/document preview.
- Do **not** ship an Electron/Tauri/web-shell substitute.

### Data and trust
- The **ledger, evidence graph, and tax engine** are the system of record.
- All raw imports are immutable.
- All normalized entities are versioned or otherwise audit-safe.
- Every important value must be traceable to source data, rules, and approvals.
- Personal and business data must coexist within one workspace model but remain clearly separated by entity.

### AI boundaries
- The LLM must **not** get raw unrestricted database access.
- The LLM must operate through a **typed internal tool bus** and curated read models.
- AI outputs are proposals, explanations, questions, summaries, or drafts.
- AI must never silently mutate authoritative financial or tax records.
- Anything that changes money, tax facts, exports, or filing status must go through deterministic code and explicit approval.

### Local-first
- Local storage is authoritative.
- The app must work without a cloud backend.
- External AI must be optional and opt-in.
- Networking must be explicit, permissioned, and understandable.

### Swiss specificity
- This is a Swiss-native product, not a generic accounting shell.
- Implement actual Swiss adapters and evidence concepts rather than vague abstractions.
- Export-first beats pretending universal automatic filing exists.

## Scope target

### V1
Build a robust v1 around these pillars:

- Workspace + encryption + local persistence
- Sidebar-based app shell and native UX
- Ledger core
- Document vault
- Imports and parsers
- Reconciliation
- Missingness engine
- Personal Tax Studio
- Business finance core
- VAT support
- Safe AI Copilot
- Year-end and business tax export path
- Backup/restore
- Tests, fixtures, validation, and notarizable distribution

### Pilot coverage for v1
Do not aim for every canton and every business profile in the first polished release.

Implement:

- **one pilot canton for personal tax** (default to Zurich if nothing else is configured),
- **one pilot business profile** (simple sole proprietor and/or simple GmbH with VAT),
- architecture that can extend to more cantons, more entity types, and more rule packs later.

### Out of scope for first polished release
Do not block shipping on:

- universal portal automation,
- full payroll certification,
- every bank integration,
- every canton,
- inventory-heavy retail,
- multi-user real-time collaboration,
- silent autonomous bookkeeping.

## Architecture decisions already made

You must implement the system in this shape unless there is a very strong reason not to:

### Core stack
- Swift 6+
- SwiftUI first
- AppKit bridges where appropriate
- Swift Concurrency + actors for background work
- Swift Package Manager package boundaries
- SQLite-based primary store with encrypted-at-rest support
- macOS Keychain for secrets
- local content-addressed file vault
- local search / FTS over documents and selected structured data
- optional local vector store only if it clearly improves retrieval and remains local-first

### Recommended package structure
Use a structure close to:

```text
AlpenLedger.xcworkspace
├── App/AlpenLedgerApp
└── Packages/AlpenLedgerKit
    └── Sources/
        ├── ALDomain
        ├── ALAudit
        ├── ALStorage
        ├── ALWorkspace
        ├── ALImports
        ├── ALLedger
        ├── ALDocuments
        ├── ALEvidence
        ├── ALTaxCore
        ├── ALTaxCH
        ├── ALExports
        ├── ALToolBus
        ├── ALAI
        ├── ALDesignSystem
        └── ALFeatures
```

### Boundary rule
- No UI layer talks directly to storage.
- No AI layer talks directly to storage.
- Both UI and AI must call typed use cases / services.

## Required domain model

At minimum, implement these core entities:

- `Workspace`
- `LegalEntity`
- `TaxYear`
- `LedgerAccount`
- `FinancialAccount`
- `ImportJob`
- `StatementImport`
- `Transaction`
- `JournalEntry`
- `JournalLine`
- `Document`
- `EvidenceLink`
- `TaxFact`
- `FilingPackage`
- `Requirement`
- `Issue`
- `AgentProposal`
- `AuditEvent`

Enforce important invariants:

- journal entries balance,
- raw imports are never overwritten,
- locked periods cannot be modified silently,
- filing packages record source rule-pack and export version,
- evidence links are explicit,
- user overrides are clearly marked,
- AI suggestions never masquerade as confirmed facts.

## Required product areas

Implement these top-level product areas as first-class features:

1. **Overview**
2. **Inbox**
3. **Ledger**
4. **Documents**
5. **Tax Studio**
6. **Copilot**
7. **Settings**

### UX requirements
The app should feel like a serious modern Mac productivity tool, not an ERP dashboard.

Use:
- sidebar navigation,
- toolbar actions,
- global search,
- split views,
- inspectors,
- drag-and-drop,
- keyboard shortcuts,
- clear empty states,
- calm typography and spacing,
- PDF/document previews,
- issue lists and guided workflows.

Avoid:
- cluttered dashboard grids,
- fake SaaS patterns,
- over-automation,
- unexplained statuses,
- hard-to-review AI actions.

## Swiss standards and product grounding

Architect around real Swiss standards and workflows.

### Personal tax
- Build personal-tax export against **eCH-0119** first.
- Keep the canonical tax-fact layer ready for a future **eCH-0278** transition.

### Business tax
- Build legal-entity business tax export around **eCH-0276**.

### VAT
- Build VAT export around **eCH-0217**.

### Tax statements and expected evidence
Support import/parsing or at minimum first-class document handling for:
- **eCH-0196** electronic tax statements,
- **eCH-0248** pillar 2 / pillar 3a certificates,
- **eCH-0275** health-insurance tax certificates,
- salary certificates,
- mortgage statements,
- bank/broker annual tax statements,
- tax office correspondence.

### Banking and payments
Support:
- CSV statement imports,
- Swiss ISO 20022 cash-management formats:
  - `camt.052`
  - `camt.053`
  - `camt.054`
- QR-bill parsing and evidence handling.

### Filing access patterns
Assume **export-first + guided submission**.
Do not hard-code the product around universal automatic filing.  
Portal handoff and submission checklists are valuable even when true end-to-end submission varies by canton or authority.

### Payroll
Plan a path for payroll imports and Swissdec-adjacent workflows, but do not let payroll certification block v1.

## Missingness is a core feature

You must model and compute not only what exists, but also what **should exist and is missing**.

Build a missingness engine that can detect, explain, and track at least:

- missing receipt or invoice for a business expense,
- missing monthly bank extract,
- missing annual broker/bank tax statement,
- missing salary certificate,
- missing pillar 2 / pillar 3a certificate,
- missing health-insurance tax certificate,
- missing supporting document for deductible medical costs,
- missing statement coverage for an account period,
- missing attachment required for a filing package.

This is a first-class rules engine, not a loose heuristic.

## Reconciliation requirements

Implement a reconciliation engine that can handle:

- bank-to-ledger matching,
- document-to-transaction matching,
- transfer detection,
- duplicate detection,
- statement coverage detection,
- tax evidence completeness.

Use matching layers in this order:

1. deterministic exact match,
2. structured reference match,
3. fuzzy amount/date/vendor match,
4. ranked AI suggestion,
5. user review.

## Tax engine requirements

The tax engine must be deterministic and versioned.

Build:

- a canonical `TaxFact` model,
- rule packs by type / jurisdiction / year,
- filing adapters,
- validation passes,
- evidence policies,
- export packaging,
- validation reports.

### Rule-pack design
Each rule pack should track:
- type (`personal`, `business`, `vat`),
- jurisdiction,
- canton where relevant,
- tax year,
- standard version,
- formulas and mappings,
- evidence requirements,
- validations,
- release identifier.

Tax rules and mappings must be separately versionable from the app shell.

## AI architecture requirements

### Core AI rule
The LLM is a consumer of governed tools, not the owner of truth.

### Build these layers
- chat session manager,
- model provider abstraction,
- typed tool bus,
- curated reporting views,
- proposal store,
- approval policy layer,
- local memory,
- audit logging for agent/tool activity.

### Required tool-bus shape
Implement typed tools similar to:

```text
finance.list_accounts()
finance.search_transactions(filters)
finance.explain_balance(account, period)
docs.search(query)
docs.get_document_summary(document_id)
reconcile.list_open_issues(filters)
reconcile.find_missing_statements(account_id, year)
tax.list_requirements(entity_id, tax_year)
tax.preview_return(entity_id, tax_year, canton)
tax.explain_fact(tax_fact_id)
ledger.propose_split(transaction_id, rationale)
exports.validate(package_id)
```

### Required AI modes
Support privacy modes:

- **Air-gapped**: no network, local AI only or AI disabled
- **Hybrid**: local data stays authoritative, selected redacted snippets may go to a cloud model with explicit opt-in
- **External assistant integration**: optional and disabled by default

### Provider guidance
- Local models are the default-compatible path.
- External cloud models are optional.
- If you add OpenAI support, do it as a provider integration that uses user-supplied credentials or explicit app configuration.
- Do **not** architect the in-app finance chat around a mandatory ChatGPT subscription login.
- If you add MCP / Codex support, do it as an **optional adapter** on top of the same internal tool bus.

### Codex / MCP
If you implement MCP exposure:
- keep it optional,
- scope it narrowly,
- never expose unrestricted SQL,
- never expose raw unrestricted file access,
- keep it disabled by default,
- treat authenticated remote MCP as separate from the local-first core.

## Agent system requirements

Implement the agent system described in `agents.md`.

At minimum, support these agents:

- Router Agent
- Intake & Triage Agent
- Document Extraction Agent
- Transaction Classification Agent
- Reconciliation Agent
- Missing Evidence Agent
- Personal Tax Agent
- VAT Agent
- Business Year-End Agent
- Filing Packager Agent
- CFO / Q&A Agent
- Explainability & Audit Agent

### Agent rules
Agents may:
- classify,
- summarize,
- suggest,
- explain,
- draft,
- prioritize,
- ask targeted questions,
- prepare export candidates.

Agents may not:
- invent tax values,
- silently change confirmed books,
- mark filings complete with missing evidence,
- execute unrestricted SQL or shell actions,
- transmit user data off-device in local-only mode.

## Security and privacy requirements

Implement strong local security:

- encrypted-at-rest database,
- Keychain-based secret management,
- per-workspace key derivation where practical,
- explicit network permissions,
- explicit AI/provider consent,
- local backup and restore,
- audit logs,
- safe migration paths,
- no silent data loss.

Optional but desirable:
- workspace lock on launch,
- biometric or local auth gating for sensitive workspaces,
- export password protection where relevant.

## Build order

Build in this order unless there is a compelling technical dependency:

### Milestone 0 — Foundations
- repo structure
- app shell
- design system baseline
- workspace lifecycle
- encryption baseline
- migrations
- audit skeleton
- feature flags
- logging

### Milestone 1 — Domain and persistence
- core entities
- database schema
- file vault
- search index
- document model
- account / transaction / journal model

### Milestone 2 — Imports and document pipeline
- import job framework
- file intake
- hashing / dedupe
- PDF and image pipeline
- OCR / text extraction
- structured metadata extraction
- CSV + CAMT + QR-bill basics

### Milestone 3 — Reconciliation and missingness
- duplicate detection
- transfer matching
- evidence linking
- statement coverage engine
- issue/task system
- missing-evidence rules

### Milestone 4 — Personal Tax Studio
- personal tax fact model
- evidence requirements
- filing completeness
- pilot canton implementation
- eCH-0119 export
- validation report
- filing pack preview

### Milestone 5 — Business finance + VAT
- business chart of accounts templates
- AP/AR-lite
- VAT code engine
- VAT reconciliation
- eCH-0217 export
- asset register basics
- owner draw / mixed expense handling

### Milestone 6 — AI Copilot
- tool bus
- reporting views
- chat UI
- local provider
- optional external provider
- proposal workflows
- source-backed answers

### Milestone 7 — Year-end + business tax
- close checklist
- adjusting-entry proposals
- financial statement mapping
- eCH-0276 export path
- accountant review bundle
- diagnostics

### Milestone 8 — Hardening and release
- regression suite
- sample datasets
- migration tests
- restore tests
- performance tests
- onboarding
- help docs
- localization framework
- notarized distribution pipeline

Every milestone must leave the app buildable and testable.

## Required deliverables

You are expected to produce all of the following, not just code fragments:

### Code
- native macOS app
- modules/packages
- importers
- rule engine
- exporters
- AI/tooling layer
- tests
- fixtures
- preview/demo data where appropriate

### Product artifacts
- updated architecture docs when needed
- ADRs for major decisions
- schema diagrams or equivalent generated documentation if useful
- XSD validation harnesses for supported eCH exports/imports
- sample workspace fixtures
- anonymized regression datasets

### Operational artifacts
- build instructions
- local development setup
- validation scripts
- release checklist
- backup/restore docs
- migration strategy docs
- privacy and consent explanation in settings/help

## Coding and implementation rules

### General
- Prefer explicitness over cleverness.
- Prefer deterministic code over prompt magic.
- Prefer composable services over monolith helpers.
- Prefer small reviewable increments.
- Keep compile health at all times.
- Keep the implementation organized and boring in the best way.

### Data
- Never overwrite raw input files.
- Never allow duplicate imports to silently corrupt state.
- Track parser version and import provenance.
- Make reprocessing possible when parsers improve.

### UX
- Favor clarity over density.
- Favor reviewability over automation theater.
- Every warning must explain why it exists.
- Every AI suggestion must show rationale and confidence.

### AI
- Never pretend confidence where there is uncertainty.
- If the model is uncertain, create a question, issue, or review task.
- Never present generated text as authoritative tax law.
- Keep conversation memory separate from authoritative domain facts.

### Tax and accounting
- Do not hard-code logic directly into UI layers.
- Do not let the LLM compute tax results on its own.
- Keep formulas, mappings, and validations in rule packs / adapters / services.
- Preserve manual override history.

## Required validation and tests

Add automated tests for:

- schema migrations,
- import parsing,
- dedupe/idempotency,
- reconciliation,
- statement coverage,
- missingness rules,
- tax fact derivation,
- eCH export validation,
- backup/restore,
- AI tool safety,
- regression datasets,
- performance on larger workspaces.

Create golden fixtures for:
- CSV imports,
- CAMT imports,
- QR-bill samples,
- salary certificate samples,
- eCH-0196 samples,
- eCH-0248 samples,
- eCH-0275 samples,
- personal return export,
- VAT export,
- business tax export.

## Definition of done

A feature is done only when:

- the domain model exists,
- persistence exists,
- migrations exist,
- UI exists,
- validation exists,
- auditability exists,
- realistic test data passes through it,
- docs/help are updated,
- offline behavior works unless the feature is explicitly networked,
- the related checklist item is marked done.

## Checklist discipline

You must use `checklist.md` as the operational source for progress tracking.

Rules:
- update it continuously,
- mark items done only when implemented + tested + documented,
- do not mark incomplete partial stubs as done,
- add brief evidence notes or file references where useful,
- keep section-level reality honest.

## Decision policy

If something is ambiguous:
1. choose the option that protects trust, auditability, and local-first behavior,
2. keep the canonical domain model stable,
3. isolate variability behind adapters and rule packs,
4. document the decision,
5. continue.

Do not stop to ask the user to restate obvious requirements that are already covered in the docs.

## Progress reporting format

Whenever you report progress, use this structure:

1. current milestone
2. what was implemented
3. files/modules changed
4. tests run
5. checklist items completed
6. next highest-priority tasks
7. blockers or assumptions

Keep reports concise but concrete.

## Immediate first actions

Start with this sequence:

1. read all companion docs,
2. audit the repository state,
3. create or normalize the package/module layout,
4. scaffold the native app shell,
5. implement workspace creation/opening,
6. stand up encrypted persistence + migrations,
7. implement the file vault and document ingestion pipeline,
8. create the initial checklist alignment,
9. continue milestone-by-milestone without drifting into vanity work.

## Final instruction

Build AlpenLedger as a **deterministic local finance engine with an evidence graph**, then layer Swiss filing adapters and AI on top.

Do not optimize for demo magic.  
Optimize for **trust, reviewability, correctness, and native usability**.

---

## Reference standards and links

- `vision.md`
- `architecture.md`
- `agents.md`
- `buildplan.md`
- `checklist.md`

External references to align with:
- eCH-0119 — personal tax export baseline
- eCH-0278 — future personal tax model direction
- eCH-0276 — business tax export baseline
- eCH-0217 — VAT export baseline
- eCH-0196 — electronic tax statement
- eCH-0248 — pillar 2 / pillar 3a certificate
- eCH-0275 — health-insurance tax certificate
- SIX Swiss Payment Standards / ISO 20022
- SIX QR-bill guidance
- AGOV reality for public-service access patterns
- Swissdec roadmap for payroll-heavy flows
