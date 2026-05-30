# vision.md — AlpenLedger
## Vision for a local-first Swiss finance manager and tax return studio

**Working name:** AlpenLedger
**Platform:** macOS-first Swift app
**Positioning:** a local-first Swiss finance workspace that combines accounting, document management, reconciliation, and tax-return generation for both private and business use.

## 1. Product thesis

Swiss finance work is fragmented across bank statements, QR-bills, receipts, salary certificates, pillar 2/3a certificates, health-insurance tax certificates, VAT periods, payroll exports, and canton-specific tax workflows. Most people only discover gaps when they prepare their annual return. Small businesses and sole proprietors have an even harder problem: they must keep operational books accurate enough for VAT, year-end close, and tax reporting, while also separating personal and business finances.

**AlpenLedger exists to make “year-end panic” impossible.** It should:
1. keep money data and source documents together from day one,
2. surface missing evidence early,
3. calculate with deterministic rules,
4. let AI assist, explain, and ask good questions,
5. generate filing-ready tax packages without turning the app into a black box.

## 2. Product promise

AlpenLedger should feel like **“the local Swiss finance OS”** for one person, one household, or one small company.

### Core promise
- **Everything lives locally by default.**
- **Every number is explainable.**
- **Every tax value has provenance.**
- **Every missing document becomes a task, not a surprise.**
- **AI is a copilot, not the source of truth.**

## 3. Who the product is for

### Primary users
- **Private individuals** who want one place for transactions, receipts, annual tax documents, and return preparation.
- **Sole proprietors / freelancers** who need both personal and business workflows, plus clear separation between the two.
- **Small Swiss businesses** (especially service firms, consultancies, agencies, studios, trades, and owner-managed GmbH/AG structures) that need local bookkeeping, document control, VAT support, and tax preparation.

### Secondary users
- **Accountants / fiduciaries** who help a client review or finalize exports.
- **Power users** who want a queryable local finance database with AI assistance.
- **Multi-entity users** who need household + company + holding-style workspaces.

## 4. Swiss-specific product grounding

The app should be built around **real Swiss standards and workflows**, not generic “finance app” abstractions.

### Personal tax
Today, the natural-person filing baseline should be aligned with **eCH-0119 E-Tax Filing**, which defines the exchange format for tax declarations of natural persons and allows canton-specific adaptation.[^ech0119]

### Business tax
For business tax, the architecture should support **eCH-0276 E-Bilanz und E-Tax JP**, which defines the exchange format for E-Bilanz and E-Tax for legal entities.[^ech0276]

### VAT / MWST
For Swiss VAT, the FTA explicitly supports importing period data as **eCH-0217 XML** in “MWST abrechnen”, and only the current eCH-0217 2.0.0 format is supported.[^mwstimport][^ech0217]

### Bank and payment data
Swiss payment traffic is anchored in **SIX Swiss Payment Standards**, including ISO 20022 credit transfer and cash-management messages such as **camt.052 / camt.053 / camt.054**.[^sps]
The QR-bill guidelines are still evolving; as of March 2026, SIX lists QR-bill guideline v2.4 as the future valid version from **14 November 2026**, while v2.3 is currently valid and structured addresses are required in the QR-bill since November 2025.[^qrbill]

### Tax certificates and expected evidence
The product should treat expected annual evidence as a first-class concept:
- the **salary certificate** is a core tax document and is usually sent before the end of January; users may receive one per employer.[^salary]
- **eCH-0196** defines the electronic tax statement provided by financial institutions for private assets.[^ech0196]
- **eCH-0248** defines the certificate for pillar 2 / pillar 3a contributions.[^ech0248]
- **eCH-0275** defines the tax certificate from health insurers for deductible costs and premiums.[^ech0275]

### Filing access patterns
Many cantons use **AGOV** for online public administration access, including tax-return filing in many cantons. This means “submit automatically everywhere” should not be assumed in v1; export-first and guided submission are the safer baseline.[^agov]

### Payroll / authorities
Swissdec matters for payroll-heavy businesses, because Swissdec-certified payroll software can transmit payroll and claims data directly to authorities and insurers.[^swissdec]

## 5. Product principles

### 5.1 Local-first, not cloud-first
The default mode is:
- local database,
- local document store,
- local search index,
- local AI memory,
- local backups under user control.

Networking is optional and explicit.

### 5.2 Deterministic core, AI edge
Anything that affects money, tax values, or filing output must come from:
- parsers,
- rules engines,
- versioned mappings,
- validations,
- explicit user approvals.

AI may:
- classify,
- summarize,
- explain,
- propose,
- ask clarifying questions,
- draft correspondence,
- search semantically.

AI must **not** silently invent tax facts.

### 5.3 Provenance everywhere
Every important value should answer:
- where it came from,
- which documents support it,
- which rule produced it,
- which user or agent approved it.

### 5.4 Swiss-native UX, not ERP UX
The app should feel like a modern macOS productivity tool, not a dense enterprise accounting screen:
- calm layout,
- sidebar navigation,
- strong search,
- document inspector,
- clear issue lists,
- guided workflows,
- keyboard shortcuts.

### 5.5 Missingness is a feature
The app should not only store what is present. It should also model what is **expected but missing**:
- missing invoice for a transaction,
- missing monthly statement for an account,
- missing salary certificate for an employer,
- missing health-insurance certificate,
- missing tax statement from a broker,
- missing attachment required for a filing package.

### 5.6 Multi-entity by design
Personal and business data must coexist inside one workspace model, but remain clearly separated:
- natural person,
- household/joint filing context,
- sole proprietorship,
- GmbH / AG / association / foundation later.

## 6. Experience vision

## The user experience should revolve around five hubs

### 6.1 Inbox
A single review inbox for:
- newly imported statements,
- newly imported PDFs,
- unmatched receipts,
- uncategorized transactions,
- low-confidence AI suggestions,
- missing-document alerts.

### 6.2 Ledger
The authoritative transaction and journal area:
- accounts,
- transactions,
- categories / chart of accounts,
- splits,
- reconciliations,
- transfers,
- accrual and depreciation drafts.

### 6.3 Document Vault
A searchable vault for:
- receipts,
- invoices,
- QR-bills,
- bank extracts,
- salary certificates,
- tax statements,
- insurance documents,
- contracts,
- tax-office correspondence.

### 6.4 Tax Studio
A guided workflow for:
- pre-year checklist,
- open issues,
- required evidence,
- tax facts,
- return preview,
- filing pack generation,
- export validation,
- submission checklist.

### 6.5 Copilot
A local-first finance assistant that can answer:
- “What am I missing for my 2025 Zurich return?”
- “Which business expenses lack invoices?”
- “Why is my VAT due so high this quarter?”
- “Show all subscriptions paid from my personal account but tagged as business.”
- “Which accounts still miss monthly extracts?”

## 7. Scope

## v1 scope
- macOS native app in Swift.
- Local workspace with one or more entities.
- Manual and file-based imports.
- Bank statement imports (CSV + Swiss ISO 20022 cash-management formats).
- Document vault with OCR/text extraction.
- Reconciliation and document matching.
- Missing-evidence engine.
- Personal tax pack generation.
- VAT period support and eCH-0217 export.
- Business finance core: journal, AP/AR-lite, year-end adjustments, E-Bilanz / E-Tax export path.
- AI chat and assistant workflows with local-first provider abstraction.

## v1.5 / v2 scope
- Corporate tax workflows beyond the initial pilot set.
- Payroll import and Swissdec-compatible workflows.
- Rule-pack updater and standards-pack updater.
- Assistant-generated request letters/emails for missing documents.
- Accountant review mode.
- Optional external Codex / MCP integration.

## 8. Non-goals

These are explicitly **not** the first-release target:
- a neobank,
- a payment execution platform,
- universal automatic cantonal submission,
- full bank API aggregation across all Swiss institutions,
- replacing fiduciary judgement for edge-case tax law,
- silent autonomous bookkeeping,
- “AI-only accounting”.

## 9. Trust model

Users should trust AlpenLedger for the same reasons they trust good bookkeeping:
- it is consistent,
- it is reviewable,
- it keeps evidence attached,
- it highlights uncertainty instead of hiding it,
- it preserves an audit trail,
- it separates suggestions from facts.

### User-facing trust rules
1. Never show a calculated amount without explaining where it came from.
2. Never mark a filing as complete if required evidence is missing.
3. Never auto-post journal entries without approval.
4. Never overwrite raw imports.
5. Never send user data to external AI providers without an explicit opt-in mode.
6. Never call something “filed” until the user explicitly confirms that filing happened.

## 10. Product strategy

### Strategy statement
**Win on trust, locality, Swiss fit, and evidence completeness.**
Do not try to win on generic dashboards or mass-market personal-finance gimmicks.

### Why this can be differentiated
Most tools do only one of these well:
- budgeting,
- bookkeeping,
- document storage,
- tax filing,
- AI chat.

The product opportunity is the **combination**:
1. finance ledger,
2. document evidence graph,
3. Swiss filing adapters,
4. AI over a governed local data model.

That combination is much harder to copy than a simple expense tracker.

## 11. Success metrics

### User-value metrics
- % of transactions matched to evidence
- % of months with full statement coverage per account
- time from “tax season start” to “filing-ready package”
- number of missing items discovered **before** filing week
- % of AI answers with complete provenance
- reduction in manual recategorization over time

### Product-quality metrics
- import idempotency rate
- schema-validation pass rate for generated exports
- reconciliation accuracy
- document-link suggestion precision / recall
- false-positive rate in missingness detection
- AI hallucination rate in benchmark tasks
- crash-free sessions and migration success rate

## 12. Vision for the AI layer

The AI in AlpenLedger should feel like a **disciplined analyst**:
- it can explore,
- it can explain,
- it can summarize,
- it can find anomalies,
- it can draft recommendations,
- it can guide the user through missing items.

But it should always operate inside a constrained system:
- read-only by default,
- write actions become proposals,
- all proposals have confidence + provenance,
- high-impact actions require human review.

## 13. Vision for OpenAI / Codex integration

The product should **not** make undocumented third-party OAuth flows a hard dependency.

Recommended stance:
- **Core product:** works fully offline / local without any external model.
- **Optional cloud model mode:** user provides an API credential stored locally.
- **Optional Codex integration:** expose the same typed finance tools through an MCP-compatible surface for power users or developer workflows.
- **Do not** bind the app’s primary auth or data access model to an unstable external assistant login.

This is the cleanest way to satisfy both:
- the “fully local” requirement,
- the desire for AI assistance,
- and future extensibility toward Codex / ChatGPT tooling.

## 14. One-sentence vision

**Build the most trustworthy local Swiss finance workspace: a macOS app that keeps books, keeps evidence, prepares taxes, and uses AI to clarify reality rather than invent it.**

---

## Cross-links
- [architecture.md](architecture.md)
- [agents.md](agents.md)
- [buildplan.md](buildplan.md)

---

## References
[^ech0119]: eCH-0119 E-Tax Filing V4.0.0 — https://www.ech.ch/de/ech/ech-0119/4.0.0
[^ech0276]: eCH-0276 E-Bilanz und E-Tax JP V1.0.0 — https://www.ech.ch/de/ech/ech-0276/1.0.0
[^mwstimport]: Federal Tax Administration, “Mehrwertsteuer online abrechnen” — https://www.estv.admin.ch/de/mwst-online-abrechnen
[^ech0217]: eCH-0217 Spezifikation E-MWST V2.0.0 — https://www.ech.ch/de/ech/ech-0217/2.0.0
[^sps]: SIX, “ISO 20022 – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/iso-20022.html
[^qrbill]: SIX, “QR-bill – Swiss Payment Standards” — https://www.six-group.com/en/products-services/banking-services/payment-standardization/standards/qr-bill.html
[^salary]: ch.ch, “Swiss salary certificate” — https://www.ch.ch/en/documents-and-register-extracts/salary-certificate/
[^ech0196]: eCH-0196 E-Steuerauszug V2.2.0 — https://www.ech.ch/de/ech/ech-0196/2.2.0
[^ech0248]: eCH-0248 Bescheinigung über Vorsorgebeiträge an die 2. und 3. Säule V1.0.0 — https://www.ech.ch/de/ech/ech-0248/1.0.0
[^ech0275]: eCH-0275 Steuerbescheinigung der Krankenkassen V1.0.0 — https://www.ech.ch/de/ech/ech-0275/1.0.0
[^agov]: ch.ch, “Online access to Swiss public administration via AGOV” — https://www.ch.ch/en/safety-and-justice/addresses-of-administrative-authorities/
[^swissdec]: Swissdec — https://swissdec.ch/
