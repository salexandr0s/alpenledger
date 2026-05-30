# Agent system design for a local-first Swiss finance manager - AlpenLedger

## 1. Agent philosophy

The agent system must make the product **smarter without making it less trustworthy**.

That means:

- agents **observe** more than they **act**,
- agents propose changes instead of silently applying them,
- agents cite evidence,
- agents escalate uncertainty,
- the accounting/tax engine remains deterministic,
- tool access is narrow and permissioned.

## 2. What agents are allowed to do

### Agents may
- classify,
- summarize,
- suggest,
- match,
- explain,
- draft,
- prioritize,
- ask targeted questions,
- prepare export candidates.

### Agents may not
- mutate confirmed ledger data without approval,
- invent tax values,
- mark filings complete when evidence is missing,
- delete source documents automatically,
- execute unrestricted SQL or shell actions,
- silently send data off-device in local-only mode.

## 3. Execution model

## 3.1 Layers
The agent system should have four layers:

1. **Router / planner**
2. **Domain tools**
3. **Specialist agents**
4. **Approval & audit layer**

```text
User message
   ↓
Router / Planner
   ↓
Specialist agent(s)
   ↓
Typed domain tools
   ↓
Evidence + result
   ↓
Answer / proposal / approval request
```

## 3.2 Tool-first design
Each agent operates through typed tools, not raw database access.

This is the single most important safety design decision.

## 3.3 Shared memory model
Split memory into:
- **ephemeral conversation memory**: recent turns, active task context
- **workspace memory**: user preferences, entity settings, recurring vendor knowledge
- **domain facts**: ledger/document/tax data (authoritative, not agent-owned)
- **audit log**: immutable record of agent calls and approved outcomes

## 4. Agent catalog

## 4.1 Router Agent
### Mission
Interpret user intent and dispatch to the right specialist or tool sequence.

### Inputs
- current user message
- active entity / year / canton context
- recent conversation context

### Tools
- intent classification
- list available specialists
- read-only domain lookup

### Output
- execution plan
- specialist selection
- clarification only when absolutely necessary

### Write permission
None

---

## 4.2 Intake & Triage Agent
### Mission
Handle newly imported files and transactions and decide where they belong.

### Inputs
- file metadata
- source folder
- import job metadata
- quick extracted text / first pass parse

### Tools
- `imports.classify_file`
- `docs.extract_metadata`
- `finance.detect_account`
- `issues.create_if_needed`

### Output
- document type
- likely entity
- likely tax year
- next-step queue assignment

### Write permission
Can create **draft** document records and issues

---

## 4.3 Document Extraction Agent
### Mission
Convert PDFs/images into structured finance/tax metadata.

### Inputs
- document text / OCR result
- file previews
- parser output
- known templates

### Tools
- `docs.get_binary_ref`
- `docs.extract_text`
- `docs.parse_structured`
- `docs.suggest_fields`

### Output
- extracted vendor, date, amount, reference
- detected document type
- confidence score
- unresolved fields

### Write permission
Can store **proposed** extracted fields

### Guardrail
If confidence is low, it must emit a question or issue rather than making fields look definitive.

---

## 4.4 Transaction Classification Agent
### Mission
Suggest transaction categories, counterparties, and account mappings.

### Inputs
- transaction description
- amount/date/currency
- entity
- prior similar transactions
- linked document info

### Tools
- `finance.search_transactions`
- `finance.get_transaction_context`
- `ledger.get_chart_of_accounts`
- `ledger.propose_mapping`

### Output
- suggested category / account
- confidence
- rationale
- candidate recurrence rules

### Write permission
Draft proposals only

### Guardrail
No auto-posting to locked periods.

---

## 4.5 Reconciliation Agent
### Mission
Match transactions, documents, transfers, and statements into coherent records.

### Inputs
- bank statement imports
- transaction streams
- evidence candidates
- account settings

### Tools
- `reconcile.find_transfer_candidates`
- `reconcile.match_documents`
- `reconcile.detect_duplicates`
- `reconcile.list_statement_gaps`

### Output
- matched pairs/groups
- unresolved items
- duplicate warnings
- statement coverage status

### Write permission
Can create reconciliation proposals and issue states

### Guardrail
Any destructive merge requires confirmation.

---

## 4.6 Missing Evidence Agent
### Mission
Continuously answer: **What should be here, but isn’t?**

### Inputs
- entity type
- account coverage timelines
- tax-year evidence policies
- document inventory
- open transactions and categories

### Tools
- `requirements.list_expected`
- `docs.list_by_year`
- `reconcile.statement_coverage`
- `tax.list_required_certificates`
- `issues.open_or_update`

### Output
- missing invoice alerts
- missing monthly statement alerts
- missing salary certificate alerts
- missing bank tax statement alerts
- missing pillar / health certificate alerts
- filing blockers vs soft warnings

### Write permission
Can create/update issue records and task list entries

### Guardrail
Never assume “not needed” unless the rules engine says so or the user explicitly overrides.

---

## 4.7 Personal Tax Agent
### Mission
Prepare and explain natural-person tax facts and filing readiness.

### Inputs
- personal ledger
- documents
- tax facts
- canton + tax year
- filing rules

### Tools
- `tax.compute_personal_facts`
- `tax.list_requirements`
- `tax.preview_return`
- `tax.explain_fact`
- `docs.find_supporting_evidence`

### Output
- tax readiness summary
- deduction opportunities supported by evidence
- unsupported claimed deductions
- draft filing package notes
- targeted follow-up questions

### Write permission
Can create **proposed** tax facts, notes, and checklist items

### Guardrail
Amounts come from the deterministic engine, not from the model.

---

## 4.8 VAT Agent
### Mission
Prepare VAT periods and explain differences between expected and reported VAT.

### Inputs
- business ledger
- tax codes
- locked/unlocked periods
- VAT rule set

### Tools
- `vat.compute_period`
- `vat.reconcile_to_ledger`
- `vat.generate_export`
- `vat.list_issues`

### Output
- VAT payable/receivable explanation
- suspicious transactions
- missing support docs
- eCH-0217 export readiness

### Write permission
Can generate draft VAT exports and create issues

### Guardrail
Cannot submit or finalize without explicit approval.

---

## 4.9 Business Year-End Agent
### Mission
Assist with year-end closing for small businesses.

### Inputs
- trial balance
- AR/AP status
- fixed assets
- accrual policies
- prior-year closing data

### Tools
- `closing.list_open_items`
- `closing.propose_accruals`
- `closing.propose_depreciation`
- `closing.preview_financials`
- `tax.compute_business_facts`

### Output
- closing checklist
- draft adjusting entries
- unresolved business-tax items
- pre-export diagnostics

### Write permission
Can create **draft** journal entries only

### Guardrail
All adjusting entries require review + approval.

---

## 4.10 Payroll / Swissdec Agent
### Mission
Support payroll-oriented businesses and future Swissdec-compatible flows.

### Inputs
- payroll imports
- employee/year summaries
- benefit/contribution metadata
- filing targets

### Tools
- `payroll.import_runs`
- `payroll.list_year_end_docs`
- `payroll.map_authority_exports`
- `issues.create_if_needed`

### Output
- missing payroll year-end docs
- authority/reporting checklist
- mapping diagnostics

### Write permission
Checklist and draft export artifacts only

### Guardrail
Swissdec certification is a product/compliance step, not an LLM step.

---

## 4.11 Filing Packager Agent
### Mission
Turn prepared facts + evidence into an exportable filing package.

### Inputs
- canonical tax facts
- documents
- mapping definitions
- target standard and version
- validation results

### Tools
- `exports.generate_package`
- `exports.validate_package`
- `exports.build_manifest`
- `exports.render_review_bundle`

### Output
- XML/ZIP/PDF bundle
- validation report
- missing-field report
- submission checklist

### Write permission
Can generate packages and validation artifacts

### Guardrail
Cannot mark “ready to file” if validation or completeness blockers exist.

---

## 4.12 CFO / Q&A Agent
### Mission
Answer user questions across finance, bookkeeping status, and tax readiness.

### Inputs
- semantic query
- read-only reporting views
- tool outputs
- linked evidence

### Tools
- `finance.query_read_models`
- `docs.search`
- `reconcile.list_open_issues`
- `tax.preview_status`

### Output
- plain-language answers
- numeric summaries
- drill-down references
- “because” explanations

### Write permission
None by default

### Guardrail
Must cite source transactions/documents/issues in every answer.

---

## 4.13 Explainability & Audit Agent
### Mission
Translate machine state into reviewer-friendly explanation.

### Inputs
- transaction, document, or tax fact IDs
- validation logs
- rule metadata
- agent proposal trace

### Tools
- `audit.get_event_chain`
- `tax.explain_fact`
- `ledger.explain_entry`
- `docs.get_support_set`

### Output
- why a value exists,
- what evidence supports it,
- what changed,
- who approved it,
- what still blocks it.

### Write permission
None

## 5. Permission model

| Capability | Default | Approval needed? | Notes |
|---|---:|---:|---|
| Read ledger/reporting data | Yes | No | Through typed tools only |
| Read document text/snippets | Yes | No | Binary access restricted |
| Create proposal | Yes | No | Proposal is not authoritative |
| Open/update issue | Yes | No | Low-risk write |
| Create draft journal entry | Limited | Yes | Human review required |
| Merge counterparties/docs | No | Yes | Must be reversible |
| Generate filing export | Limited | Yes | Allowed after validations |
| Submit filing | No | Yes + external flow | Keep manual in v1 |
| Delete source data | No | Yes | Prefer archive/supersede instead |

## 6. Tool surface design

## 6.1 Read-only tools
These power most questions:
- `finance.search_transactions`
- `finance.account_summary`
- `reconcile.statement_coverage`
- `issues.list_open`
- `docs.search`
- `docs.get_summary`
- `tax.requirements_status`
- `tax.preview_status`
- `audit.trace_object`

## 6.2 Proposal tools
These generate changes without applying them:
- `ledger.propose_mapping`
- `ledger.propose_split`
- `closing.propose_accrual`
- `docs.propose_match`
- `tax.propose_override_reason`

## 6.3 Confirmed-write tools
These should only run after explicit user action:
- `ledger.apply_draft_entry`
- `entities.merge_counterparties`
- `exports.finalize_package`
- `rules.accept_override`

## 6.4 Tool contract requirements
Every tool should declare:
- input schema,
- output schema,
- side effects,
- required scopes,
- provenance returned,
- retry policy,
- whether user confirmation is required.

## 7. Model routing

## 7.1 Suggested routing strategy
### Small local model
Use for:
- file/document classification,
- short extraction cleanup,
- vendor normalization,
- obvious triage.

### Medium reasoning model
Use for:
- evidence linking suggestions,
- reconciliation explanation,
- targeted question generation.

### Strong reasoning model
Use for:
- multi-step tax explanations,
- complex business status Q&A,
- drafting final issue summaries,
- orchestrating multi-tool flows.

### Deterministic engine
Use for:
- calculations,
- mappings,
- validations,
- export generation,
- filing readiness.

## 7.2 Cloud model rules
If cloud inference is enabled:
- default to metadata-only or snippet-only sending,
- redact personally sensitive fields where possible,
- clearly mark when data left the device,
- log provider + model + scope of data sent.

## 8. Agent guardrails

## 8.1 Universal rules
1. Do not treat missing values as zero unless a deterministic rule says zero.
2. Do not infer legal/tax conclusions without evidence and rule references.
3. Do not mutate closed/locked periods.
4. Do not answer with unsupported certainty.
5. Always distinguish:
   - observed fact
   - derived value
   - user override
   - agent suggestion

## 8.2 Confidence protocol
Every extraction/match/classification proposal returns:
- `confidence`
- `reasons`
- `missing_fields`
- `source_refs`

Threshold example:
- high confidence → auto-queue for review
- medium confidence → show as suggested
- low confidence → ask one precise question

## 8.3 Hallucination control
When the agent cannot ground an answer, it should say:
- what it found,
- what is missing,
- what would resolve the uncertainty.

Never fabricate a value just to complete a return.

## 9. Example workflows

## 9.1 “What is missing for my 2025 Zurich return?”
Flow:
1. Router selects Personal Tax Agent.
2. Personal Tax Agent calls:
   - `tax.list_requirements`
   - `docs.list_by_year`
   - `reconcile.statement_coverage`
   - `tax.preview_return`
3. Missing Evidence Agent is invoked for blockers.
4. Response groups findings into:
   - required and missing,
   - likely required and missing,
   - nice-to-have supporting documents,
   - unresolved categorization issues.

## 9.2 “Which business expenses lack invoices?”
Flow:
1. Router selects CFO/Q&A Agent + Missing Evidence Agent.
2. Tools:
   - `finance.search_transactions(type=expense, entity=business)`
   - `docs.matched_to_transactions`
   - `requirements.policy_for_transactions`
3. Result:
   - missing invoices by vendor and age,
   - direct links to each transaction,
   - one-click creation of a “request document” task.

## 9.3 “Why is my VAT due so high this quarter?”
Flow:
1. Router selects VAT Agent.
2. Tools:
   - `vat.compute_period`
   - `vat.reconcile_to_ledger`
   - `finance.query_read_models`
3. Result:
   - top drivers,
   - unusual transactions,
   - period-over-period comparison,
   - missing support docs or miscodings.

## 9.4 “Prepare my corporate tax export”
Flow:
1. Router selects Business Year-End Agent + Filing Packager Agent.
2. Year-End Agent checks open issues and closing drafts.
3. Filing Packager Agent generates export and validation bundle.
4. User reviews blockers and approves final package generation.

## 10. Prompting principles

## 10.1 Preferred response schema
For internal specialist outputs, prefer JSON like:

```json
{
  "summary": "string",
  "confidence": 0.0,
  "findings": [],
  "blocking_issues": [],
  "suggested_actions": [],
  "source_refs": [],
  "needs_user_confirmation": false
}
```

## 10.2 Prompt content rules
Prompts should include:
- current entity,
- jurisdiction and year,
- relevant policy/ruleset version,
- allowed tools,
- forbidden actions,
- response schema,
- required provenance format.

## 10.3 Prompt rule example
“Use only tool-returned numeric values. If a numeric value is not returned by a tool, describe the missing input instead of inventing a number.”

## 11. Observability and audit

Track, per agent execution:
- agent name,
- model/provider,
- prompt template hash,
- input object refs,
- tool calls made,
- tool outputs referenced,
- proposal objects created,
- user approvals or rejections,
- duration and errors.

This is essential for trust and debugging.

## 12. OpenAI / Codex strategy

## 12.1 What is grounded
OpenAI documents two relevant surfaces:
- Codex authentication for its own clients (ChatGPT sign-in or API key), and
- MCP/App authentication using OAuth 2.1 with your authorization server for authenticated MCP servers.[^codexauth][^appsauth]

OpenAI also documents Codex MCP support for local stdio and HTTP servers, with OAuth for supported HTTP servers.[^codexmcp]

## 12.2 Recommended product interpretation
For AlpenLedger:
- **Do not** depend on a third-party “Sign in with OpenAI/ChatGPT” flow for your core native app.
- **Do** support optional external model providers using user-supplied credentials.
- **Do** consider optional Codex/MCP integration on top of your tool bus.

This keeps the product stable even if external auth surfaces evolve.

## 13. Agent maturity path

### Stage 1 — Guided assistant
- read-only questions
- extraction suggestions
- missingness alerts

### Stage 2 — Operational copilot
- reconciliation suggestions
- draft journal entries
- draft filing bundles

### Stage 3 — Power workflows
- accountant review packs
- local Codex / MCP integration
- assistant-generated request letters and checklists
- ruleset change impact analysis

## 14. Bottom line

The right agent design for this product is **many narrow agents over one typed tool bus**, not one omnipotent chatbot.
That gives you:
- better safety,
- better explainability,
- easier testing,
- easier future Codex/MCP integration,
- and a much lower chance of corrupting financial truth.

---

## Cross-links
- [docs/vision.md](docs/vision.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/buildplan.md](docs/buildplan.md)

---

## References
[^codexauth]: OpenAI, “Authentication” (Codex) — https://developers.openai.com/codex/auth/
[^appsauth]: OpenAI, “Authenticate your users” (Apps SDK) — https://developers.openai.com/apps-sdk/build/auth
[^codexmcp]: OpenAI, “Model Context Protocol” (Codex) — https://developers.openai.com/codex/mcp/
