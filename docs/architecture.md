# architecture.md — AlpenLedger
## System architecture for a local-first Swiss finance manager and tax-return creator

## 1. Architecture goals

The architecture must satisfy seven constraints at once:

1. **Local-first**: authoritative data stays on device.
2. **Swiss-specific**: filing/export adapters map to real Swiss standards.
3. **Deterministic core**: accounting, reconciliation, tax mapping, and validation are code/rules driven.
4. **AI-assisted**: natural-language workflows exist, but only on top of governed tools.
5. **Mac-native**: standard macOS UX, fast search, drag-and-drop, document inspection.
6. **Multi-entity**: personal + business in one workspace, clearly separated.
7. **Evolvable**: standards, cantonal rules, and filing formats change yearly.

## 2. Architectural stance

### 2.1 Core principle
**The ledger, evidence graph, and tax engine are the system of record.  
The LLM is a consumer of system state, not the owner of system truth.**

### 2.2 Design consequence
- All raw imports are immutable.
- All normalized entities are versioned.
- All AI outputs are proposals, annotations, or explanations.
- All filing outputs are generated from deterministic mappings.
- All external standards live behind adapter boundaries.

## 3. High-level system view

```text
┌──────────────────────────────────────────────────────────────────────┐
│                           macOS Swift App                           │
│   SwiftUI shell + AppKit bridges + PDF/document viewers + search    │
└───────────────┬─────────────────────┬────────────────────────────────┘
                │                     │
                ▼                     ▼
┌──────────────────────────┐   ┌──────────────────────────────────────┐
│   Application Services   │   │           AI Orchestration           │
│  - Workspace             │   │ - Internal tool bus                  │
│  - Ledger                │   │ - Chat/session manager               │
│  - Documents             │   │ - Model provider abstraction         │
│  - Reconciliation        │   │ - Safety / approval policies         │
│  - Tax / Filing          │   │ - Optional MCP exposure              │
└───────────────┬──────────┘   └────────────────┬─────────────────────┘
                │                               │
                ├──────────────┬────────────────┤
                ▼              ▼                ▼
┌────────────────────┐ ┌────────────────┐ ┌───────────────────────────┐
│ Persistence Layer  │ │ Import Layer   │ │ Rules / Validation Layer  │
│ - SQLite/SQLCipher │ │ - camt/CSV     │ │ - Tax rules               │
│ - FTS indexes      │ │ - PDFs / OCR   │ │ - Missingness rules       │
│ - File vault       │ │ - QR-bill      │ │ - Reconciliation rules    │
│ - Keychain         │ │ - eCH docs     │ │ - XSD/schema validation   │
└────────────────────┘ └────────────────┘ └───────────────────────────┘
```

## 4. Recommended macOS stack

This document stays high level. The dated toolchain baseline, dependency pins, and canonical module map live in [`architecture-pass-v1.md`](./architecture-pass-v1.md).

### UI
- **SwiftUI first** for navigation, lists, inspectors, forms, commands, search, settings, and most screens.
- **AppKit bridges** where needed for:
  - advanced document previews,
  - PDFKit integration,
  - drag-and-drop heavy workflows,
  - more specialized table behavior,
  - file import/open panels,
  - menu bar / services integration if later needed.

### State and composition
- Feature-oriented modules with unidirectional state flow.
- Swift Concurrency + actors for background imports and AI jobs.
- `NavigationSplitView` as the default shell layout.
- Swift Package Manager for internal package boundaries.

### Why not a web shell
The product should feel local, fast, and native. It needs:
- security-scoped file access,
- deep PDF integration,
- stable offline behavior,
- local database performance,
- native search,
- keyboard-heavy workflows.

A pure web shell would create unnecessary friction.

## 5. Module boundaries

Recommended workspace and package layout:

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

### Entity-scoping pattern
Scoping is enforced at the session layer (`ActiveWorkspaceSession`), which filters data by `activeEntityId` before it reaches the UI. Individual services remain workspace-wide; `ActiveWorkspaceSession.refreshCoreData()` filters `financialAccounts`, `documents`, and `issues` by the active entity. This keeps the scoping logic in one place rather than scattered across service classes, while still allowing cross-entity operations (e.g., deletion checks, evidence refresh) without special "unscoped" overloads.

### App layer decomposition
`WorkspaceAppModel` delegates to `ActiveWorkspaceSession` for services, data caching, and refresh. Snapshot computation lives in `WorkspaceAppModel+Snapshots`, and presentation helpers (labels, symbols, formatters) in `PresentationHelpers`. `WorkspaceAppModel` itself is a thin facade with navigation state and action dispatch.

### Boundary rule
No UI layer talks directly to storage or models.
The AI layer also talks to the system only through the same typed use-case / tool interfaces.

## 6. Data architecture

## 6.1 Authoritative storage

### Recommended stores
1. **Primary relational store**: SQLite-based database with encrypted-at-rest support.
2. **Document blob store**: content-addressed files in the app’s local application-support directory.
3. **Search index**: SQLite FTS index over extracted document text, counterparty names, descriptions, and structured tax labels.
4. **Secrets store**: macOS Keychain.
5. **Optional vector index**: local embedding store if semantic retrieval is used.

### Recommendation
Use **SQLite + GRDB-style relational control** rather than a higher-level opaque persistence layer.  
Reasons:
- precise migrations,
- raw SQL views,
- deterministic performance,
- FTS,
- validation/reporting queries,
- explicit control of import idempotency,
- better fit for analytics and tool-facing read views.

## 6.2 Core entities

### Workspace
Top-level container for one user’s local data universe.

### LegalEntity
Represents:
- natural person,
- household/joint context,
- sole proprietorship,
- legal entity (GmbH/AG/association).

### EntityWorkspace
User-facing scope that ties a `LegalEntity` to its workspace presentation. Enables entity switching — the "which entity am I working as" anchor. Not a replacement for `Workspace` or `LegalEntity`.

### TaxProfile
Consolidated tax configuration per entity: taxationType, canton, municipality, marital status, number of dependents, and optional ruleset version override.

### TransactionCategory
Entity-scoped transaction/expense categorization with hierarchical codes (`parentId`), tax roles, and system-defined vs user-created distinction.

### InvoiceRecord
Invoice-specific structured metadata linked to a `Document`: counterparty, amounts, direction (receivable/payable), payment status, and optional linked transaction.

### TaxYear
Represents an entity/year/jurisdiction scope for filings, rulesets, issues, and exports.

### LedgerAccount
Represents the canonical chart-of-accounts node used by `JournalLine` and linked control accounts.

### FinancialAccount
Represents:
- bank account,
- card account,
- cash,
- receivable/payable control,
- loan,
- tax account,
- portfolio / custody account later.

### ImportJob
Represents a batch/run record for import orchestration, parser version capture, replay, and issue correlation.

### StatementImport
Represents an imported bank statement, card statement, or official account extract with:
- coverage period,
- source format,
- source hash,
- parse result,
- validation state.

### Transaction
Immutable normalized bank or card transaction.

### JournalEntry / JournalLine
Authoritative bookkeeping layer. Journal entries must balance.

### Document
A stored file with:
- source hash,
- origin,
- extracted text,
- detected type,
- issue date,
- tax year,
- counterparties,
- amount hints,
- confidence.

Document has an authoritative `entityId` FK (nullable, backfilled from `detectedEntityId` during migration v5), separate from the heuristic `detectedEntityId`.

### EvidenceLink
Explicit relationship between documents and transactions, journal entries, tax facts, or filing fields.

### TaxFact
Canonical normalized fact used by the tax engine, with:
- jurisdiction,
- tax year,
- entity,
- value,
- origin(s),
- calculation method,
- confidence,
- override status.

### FilingPackage
Generated output for:
- personal tax,
- business tax,
- VAT,
- annual closing pack,
- accountant export.

### Requirement
Represents something expected:
- monthly statement,
- certificate,
- attachment,
- annual closing task,
- VAT period task.

### Issue
Represents an open problem:
- missing invoice,
- statement gap,
- unmatched transfer,
- invalid export field,
- low-confidence extraction,
- contradictory evidence.

### AgentProposal
Represents an agent-created suggestion:
- transaction category,
- counterparty merge,
- document match,
- question to user,
- journal draft,
- filing-note suggestion.

### AuditEvent
Append-only history of user actions, agent actions, and export actions.

## 6.3 Domain invariants

These should be enforced centrally:

1. **Journal entries balance.**
2. **Raw imports are immutable.**
3. **Import jobs are idempotent.**
4. **One document blob is stored once, even if imported multiple ways.**
5. **Every export declares its standard version and tax year.**
6. **Every agent proposal has confidence + provenance.**
7. **No filing can reach “ready” while critical blocking issues remain open.**
8. **No transaction can be silently deleted once imported; only reversed, archived, or superseded.**
9. **No journal posting, truth-affecting evidence confirmation, or filing finalization happens without approval.**
10. **Every operational query path supports optional entity-scoping via `activeEntityId`.**

## 7. File and document architecture

## 7.1 Content-addressed vault
Store every imported binary once, addressed by SHA-256 hash:

```text
Application Support/
  Workspaces/<workspace-id>/
    blobs/ab/cd/<sha256>
    exports/
    temp/
```

Benefits:
- deduplication,
- stable provenance,
- fast integrity checks,
- resilient re-indexing,
- easier backup/export.

## 7.2 Document pipeline
Each document import should pass through:

1. **File intake**
2. **Hash + dedupe**
3. **Type detection**
4. **Text extraction**
5. **Structured extraction**
6. **Entity matching**
7. **Evidence suggestions**
8. **Issue generation**
9. **Search indexing**

### Typical document types
- receipt
- supplier invoice
- customer invoice
- QR-bill
- salary certificate
- bank statement / extract
- eCH tax statement
- health-insurance certificate
- pillar 2 / 3a certificate
- mortgage statement
- tax-office notice
- contract / lease
- payroll export
- annual financial statement

## 7.3 OCR and parsing
Use a layered approach:
- native PDF text extraction first,
- OCR only when needed,
- structured parsers for predictable formats,
- AI extraction only when deterministic parsing fails or to enrich metadata.

The app should never treat AI OCR cleanup as authoritative without confidence scoring.

## 8. Import architecture

## 8.1 Import sources

### Phase 1
- CSV bank exports
- PDF statements
- drag-and-drop receipts/invoices
- manual transaction entry
- manual balance opening

### Phase 2
- Swiss ISO 20022 cash-management messages:
  - camt.052
  - camt.053
  - camt.054[^sps]
- QR-bill parsing from PDF/image[^qrbill]
- eCH-0196 private tax statement imports[^ech0196]
- salary certificate PDFs[^salary]
- eCH-0248 and eCH-0275 document imports[^ech0248][^ech0275]

### Phase 3
- payroll imports
- Swissdec-adjacent flows[^swissdec]
- additional accounting/export formats
- accountant roundtrip bundles

## 8.2 Import job model
Every import should create:
- source metadata,
- parser version,
- parse log,
- extracted entities,
- normalized entities,
- detected warnings,
- duplicate indicators,
- issue list.

That makes debugging and reprocessing tractable.

## 8.3 Parser plugin model
Each importer should be a versioned adapter:

```text
Importer
  - canRecognize(file)
  - parse(file)
  - normalize(parseResult)
  - validate(normalizedData)
  - emitIssues()
```

This is critical because Swiss formats and vendor exports evolve.

## 9. Reconciliation architecture

## 9.1 Matching model
Reconciliation must cover:
- bank-to-ledger matching,
- document-to-transaction matching,
- transfer detection,
- duplicate detection,
- statement coverage detection,
- tax-evidence completeness.

## 9.2 Matching layers
1. deterministic exact match,
2. fuzzy amount/date/vendor match,
3. QR reference / creditor reference / document number match,
4. learned ranking or AI suggestions,
5. human review.

## 9.3 Statement coverage engine
Model each account with an expected coverage cadence:
- monthly,
- quarterly,
- annual,
- ad hoc.

The engine should build a timeline of required periods and mark them:
- satisfied,
- partially covered,
- imported but unverified,
- missing.

This directly enables alerts like:
- “UBS CHF account: February 2026 official monthly extract missing.”
- “Credit card: April statement imported, May missing.”
- “Brokerage: annual tax statement missing for 2025.”

## 9.4 Missing-evidence engine
A separate rules layer should determine required supporting evidence by:
- account type,
- entity type,
- transaction class,
- amount band,
- tax year,
- filing mode,
- user-configured policy.

Examples:
- business expense without receipt,
- asset purchase missing invoice,
- salary income missing salary certificate,
- securities income missing bank tax statement,
- 3a deduction missing certificate,
- deductible medical costs unsupported.

The key design choice: **missingness is computed, not manually curated.**

## 10. Tax engine architecture

## 10.1 Tax engine principles
The tax engine is **not** an LLM prompt. It is a versioned deterministic mapping engine.

It should consist of:
- a canonical tax-fact model,
- jurisdiction + year rule packs,
- filing adapters,
- validation passes,
- evidence requirements,
- export packagers.

## 10.2 Canonical tax-fact model
All filing adapters should map from a shared canonical representation:

```text
TaxFact
  - id
  - entity_id
  - tax_year
  - jurisdiction
  - concept_code
  - value_type (money, quantity, boolean, text, date)
  - value
  - currency
  - provenance[]
  - confidence
  - user_override
  - derived_from_ruleset
```

This isolates core business logic from filing-format churn.

## 10.3 Personal tax adapter
### Current recommendation
Implement personal-tax export against **eCH-0119** first.[^ech0119]

### Future-proofing
Abstract the export layer so that **eCH-0278 E-Tax NP** can be added later without rewriting the whole domain model. eCH-0278 is in draft as of February 2026 and aims to provide a more unified nationwide personal-tax format; the architecture should be ready for that transition.[^ech0278draft]

### Personal tax responsibilities
- household / spouse context
- income categories
- deductions
- assets / liabilities
- attachment manifest
- completeness checks
- filing pack preview
- canton-specific extensions

## 10.4 Business tax adapter
### Current recommendation
Use **eCH-0276 E-Bilanz und E-Tax JP** as the primary target for legal-entity export.[^ech0276]

Responsibilities:
- trial balance and balance sheet mapping,
- P&L mapping,
- attachments,
- tax adjustments,
- carryforward handling later,
- canton-specific extension points.

## 10.5 VAT adapter
Use **eCH-0217** for VAT exports where supported by the FTA portal workflow.[^mwstimport][^ech0217]

Responsibilities:
- tax code mapping,
- period lock,
- net/gross consistency checks,
- supporting ledger reconciliations,
- export generation,
- portal handoff.

## 10.6 Tax evidence graph
Each filing field or tax fact should point back to:
- transaction IDs,
- document IDs,
- statement imports,
- rule IDs,
- manual overrides.

This enables:
- explainability,
- accountant review,
- audit trail,
- issue pinpointing.

## 10.7 Rule-pack architecture
Tax rules and mappings should be shipped as versioned packs:

```text
RulePack
  - type: personal | business | vat
  - jurisdiction: federal | canton-code
  - tax_year
  - standard_version
  - formula_set
  - field_mapping
  - evidence_policy
  - validation_rules
  - release_signature
```

### Why this matters
Tax rules change more often than app shells.  
The architecture should allow shipping rule-pack updates independently.

## 11. AI architecture

## 11.1 Internal tool bus
The internal chat must not get raw unrestricted database access.

Instead, create a typed tool layer such as:

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

The same tool contracts can later back:
- the internal chat,
- local automation,
- optional external MCP exposure.

## 11.2 Query strategy
Preferred sequence:
1. interpret intent,
2. call typed tools,
3. if needed, generate SQL only against **read-only reporting views**,
4. convert results into a provenance-rich answer.

Do **not** let the model write arbitrary SQL against the operational schema.

## 11.3 Read-only analytics views
Create curated reporting views like:
- `vw_spend_by_month`
- `vw_cashflow_by_entity`
- `vw_missing_evidence`
- `vw_statement_coverage`
- `vw_tax_fact_status`
- `vw_unmatched_transactions`
- `vw_vat_reconciliation`

These views:
- make AI query answers safer,
- reduce prompt/schema size,
- improve explainability,
- avoid exposing internal normalized complexity.

## 11.4 Model provider abstraction
Define a `ModelProvider` protocol:

- `localSmall`
- `localReasoning`
- `cloudReasoning`
- `embeddingProvider`
- `rerankerProvider`

Possible concrete providers:
- local models (MLX / llama.cpp / Ollama-style service),
- OpenAI API,
- Azure/OpenAI-compatible endpoints,
- optional developer-facing Codex integration later.

## 11.5 Privacy modes
### Mode A — Air-gapped
- no network,
- local AI only or AI disabled.

### Mode B — Hybrid
- data remains local,
- selected snippets may be sent to a cloud model,
- explicit consent and redaction settings required.

### Mode C — External assistant integration
- optional MCP / Codex style access,
- permission-scoped,
- disabled by default.

## 11.6 AI memory
Persist conversation state locally:
- conversation history,
- tool outputs,
- user preferences,
- unresolved questions,
- pending approvals.

But separate:
- ephemeral chat state,
- durable domain facts.

## 12. Optional Codex / MCP architecture

## 12.1 Why support it
OpenAI’s Codex supports MCP servers in the CLI and IDE extension, including local stdio servers and streamable HTTP servers; OAuth is supported for compatible HTTP MCP servers.[^codexmcp]
This makes a local finance MCP surface attractive for:
- developer tooling,
- power-user queries,
- controlled external assistant access.

## 12.2 Recommended design
Expose a **separate optional MCP adapter** on top of the same internal tool bus.

```text
Internal Tool Bus  <-->  MCP Adapter  <-->  Codex / other MCP client
```

### Scope model
- `finance.read`
- `documents.read`
- `tax.read`
- `ledger.propose`
- `exports.generate`
- `admin.none` by default

### Rule
Never expose full raw file access or unrestricted SQL as MCP tools.

## 12.3 OAuth stance
For authenticated MCP servers in OpenAI’s Apps/MCP ecosystem, OpenAI expects OAuth 2.1 with your own authorization server.[^openauth]
That is useful for remote app integrations.

However, for a **fully local** product:
- a remote ChatGPT app path would break the local-only promise,
- therefore it should be optional and not core architecture.

Use cases split cleanly:
- **local app chat**: local provider or user-supplied API credential,
- **local Codex power-user integration**: optional local MCP,
- **remote ChatGPT app integration**: future/optional only.

## 13. Security architecture

## 13.1 Local storage security
- Use encrypted-at-rest database.
- Keep master secrets in Keychain.
- Prefer per-workspace derived encryption keys.
- Optionally gate workspace opening with biometric/local auth for sensitive workspaces.

## 13.2 Permission model
Permissions must be explicit for:
- folder watches,
- network usage,
- model-provider usage,
- export destinations,
- accountant-sharing bundles.

## 13.3 Auditability
Every sensitive event should be logged:
- import,
- edit,
- approval,
- export,
- model call,
- external share,
- schema validation outcome.

## 13.4 Data-loss resilience
Implement:
- crash-safe transactions,
- periodic local snapshots,
- encrypted backup export,
- restore verification,
- migration rollback path.

## 14. UX architecture

## 14.1 Navigation
Use a standard macOS multi-column structure:
- sidebar for primary areas,
- content list in the main column,
- detail pane / inspector on the right.

Suggested sidebar:
- Overview
- Inbox
- Ledger
- Documents
- Tax Studio
- Copilot
- Settings

## 14.2 Primary workflows
The UI should optimize for:
- drag file in,
- review what the system inferred,
- fix what is wrong,
- approve proposals,
- move on.

## 14.3 Screen patterns
- tables/lists for facts,
- inspectors for evidence and explanations,
- step-based wizards only for filing/export,
- global search in toolbar,
- quick-add / quick-fix commands,
- keyboard shortcuts for inbox triage.

## 15. Testing strategy

## 15.1 Core automated testing
- unit tests for rules and mappings,
- import contract tests,
- golden-file import tests,
- journal-balance invariant tests,
- migration tests,
- XSD validation tests,
- export regression tests.

## 15.2 Standards conformance
For Swiss filing/export standards, maintain:
- schema validation fixtures,
- reference example fixtures,
- round-trip tests,
- per-year/per-canton acceptance packs.

## 15.3 AI evaluation
Benchmark:
- document classification,
- evidence linking,
- missingness suggestions,
- tax Q&A with provenance,
- refusal to invent unsupported facts.

## 16. Release and update architecture

## 16.1 App updates
Decide early whether the app is:
- direct-distributed + notarized updater,
- Mac App Store,
- or both.

For this type of product, direct distribution may be easier initially because of:
- watched folders,
- local helper processes,
- optional local model integrations,
- faster release cadence.

## 16.2 Standards / rules updates
Separate:
- shell releases,
- rule-pack updates,
- parser-pack updates,
- localization updates.

## 17. Recommended decision summary

### Hard decisions
- **Use SwiftUI + AppKit bridges**
- **Use SQLite-centered persistence**
- **Make deterministic tax/rules engine the core**
- **Add AI through a constrained internal tool bus**
- **Make MCP/Codex integration optional, not foundational**
- **Treat missing evidence as a modeled domain problem**
- **Abstract filing formats behind versioned adapters**
- **Build export-first, guided submission second**

### Why this is the right shape
This is the simplest architecture that can still handle:
- local-first trust,
- Swiss complexity,
- personal + business coexistence,
- AI Q&A over real data,
- yearly filing-format churn.

---

## Cross-links
- [vision.md](vision.md)
- [agents.md](agents.md)
- [buildplan.md](buildplan.md)

---

## References
[^salary]: ch.ch, “Swiss salary certificate” — https://www.ch.ch/en/documents-and-register-extracts/salary-certificate/
[^mwstimport]: Federal Tax Administration, “Mehrwertsteuer online abrechnen” — https://www.estv.admin.ch/de/mwst-online-abrechnen
[^ech0217]: eCH-0217 Spezifikation E-MWST V2.0.0 — https://www.ech.ch/de/ech/ech-0217/2.0.0
[^ech0119]: eCH-0119 E-Tax Filing V4.0.0 — https://www.ech.ch/de/ech/ech-0119/4.0.0
[^ech0278draft]: eCH-0278 E-Tax NP V1.0.0 (draft) — https://www.ech.ch/de/ech/ech-0278/1.0.0
[^ech0276]: eCH-0276 E-Bilanz und E-Tax JP V1.0.0 — https://www.ech.ch/de/ech/ech-0276/1.0.0
[^ech0196]: eCH-0196 E-Steuerauszug V2.2.0 — https://www.ech.ch/de/ech/ech-0196/2.2.0
[^ech0248]: eCH-0248 Bescheinigung über Vorsorgebeiträge an die 2. und 3. Säule V1.0.0 — https://www.ech.ch/de/ech/ech-0248/1.0.0
[^ech0275]: eCH-0275 Steuerbescheinigung der Krankenkassen V1.0.0 — https://www.ech.ch/de/ech/ech-0275/1.0.0
[^sps]: SIX, “ISO 20022 – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/iso-20022.html
[^qrbill]: SIX, “QR-bill – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/qr-bill.html
[^swissdec]: Swissdec — https://swissdec.ch/
[^codexmcp]: OpenAI, “Model Context Protocol” for Codex — https://developers.openai.com/codex/mcp/
[^openauth]: OpenAI, “Authenticate your users” (Apps SDK / OAuth 2.1 for authenticated MCP servers) — https://developers.openai.com/apps-sdk/build/auth
