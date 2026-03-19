# architecture-pass-v1.md — AlpenLedger
## Architecture pass v1 for a durable local-core macOS app

Date: 2026-03-19
Status: Proposed working baseline

## 1. Executive summary

Decision: build AlpenLedger as a durable local-core macOS app:
- Xcode app target + local Swift package modules,
- deterministic ledger/evidence/tax/export core,
- AI only through typed tool interfaces,
- approvals and audit as first-class architecture boundaries.

### Architecture choice

| Option | Shape | Tradeoff |
|---|---|---|
| Lean | App + one large Core module | Faster start, but weak boundary enforcement around auditability, provenance, and deterministic rules |
| Recommended | App + multi-module local Swift package | Slightly more upfront structure, but safer for provenance, approvals, Swiss adapters, and future MCP/tool exposure |

### Pass outcome

- Do not reuse TaxHacker production code as AlpenLedger’s foundation.
- Do reuse TaxHacker as workflow and UX inspiration for intake, review, filtering, and export expectations.
- Add three supporting v1 entities beyond the original minimum: `LedgerAccount`, `Requirement`, and `ImportJob`.
- Treat `AgentProposal` as the canonical proposal object name instead of `AIProposal`.
- Scaffold target: SwiftUI macOS app with `NavigationSplitView`, native PDF/document preview, GRDB-style relational control over SQLite, encrypted blob vault, and `Testing` + `XCUITest`.

### Verification

- Repo docs inspected locally: `agents.md`, [`docs/vision.md`](./vision.md), [`docs/architecture.md`](./architecture.md), [`docs/buildplan.md`](./buildplan.md)
- Local toolchain verified on this machine: `xcodebuild -version` reports `Xcode 26.3 (17C529)` and `xcrun swift --version` reports `Apple Swift 6.2.4`
- TaxHacker inspected as a comparison source:
  - [README](https://github.com/vas3k/TaxHacker/blob/main/README.md)
  - [schema.prisma](https://github.com/vas3k/TaxHacker/blob/main/prisma/schema.prisma)
  - [app tree](https://github.com/vas3k/TaxHacker/tree/main/app)
  - [components tree](https://github.com/vas3k/TaxHacker/tree/main/components)

## 2. Toolchain and dependency baseline

Interpret “latest” as “latest stable versions suitable for a checked-in production scaffold,” not “latest beta.”

### Stable baseline for the first scaffold

- Apple currently lists `Xcode 26.3` as the latest stable Xcode and `Xcode 26.4 beta` separately on the Xcode support matrix.[^xcode]
- Swift.org currently publishes `Swift 6.2.4` on the install page.[^swift]
- The built-in `Testing` framework should come from the selected Swift 6 toolchain instead of being added as a separate package dependency.
- `XCUITest` should come from the selected Xcode installation.

### Initial external dependency policy

Keep third-party dependencies minimal and current:

| Dependency | Baseline | Why |
|---|---:|---|
| `GRDB.swift` | `7.10.0` | Explicit migrations, query control, SQLite/FTS ergonomics, strong fit for deterministic local persistence[^grdb] |
| `SQLCipher` | `4.14.0` | Encrypted-at-rest SQLite baseline, current upstream SQLite fixes, WAL-safe recommendation from release notes[^sqlcipher] |

### Versioning rule

- Pin exact versions in `Package.swift` once the scaffold exists.
- Default project settings and CI to the selected stable Xcode release.
- Treat beta toolchains as opt-in evaluation spikes only.
- Re-run dependency version checks before each scaffold or dependency bump PR.

## 3. Assumptions and open questions

### Assumptions

- v1 is single-user and single-machine, with no sync.
- First real entity coverage is natural person, sole proprietor, and simple GmbH/AG baseline.
- Imported financial source facts are append-only; corrections happen through supersession or reversal, not silent mutation.
- Core types stay canton-agnostic; sample tax fixtures may default to Zurich.
- AI ships behind a feature flag after `ALToolBus` and proposal storage exist.

### Open questions

- Encryption day 1 vs milestone 2:
  Recommend day-1 APIs for encrypted DB and blob storage, even if fixture and test workspaces use relaxed dev configuration.
- Feature module granularity:
  Split core service modules now, but keep UI screens inside one `ALFeatures` umbrella until milestone 3 if the team size is 1–2 engineers.
- Toolchain pin:
  Once the scaffold exists, decide whether CI and local scripts key off Xcode alone or allow standalone Swift patch bumps; document one source of truth.

## 4. AlpenLedger module map

### Recommended package shape

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

### Module table

| Module | Responsibility | Key public interfaces | Must not own | Depends on |
|---|---|---|---|---|
| `AlpenLedgerApp` | macOS entry point, windowing, app lifecycle, dependency wiring | `AppBootstrap`, `RootSplitView`, `DependencyContainer` | Domain rules, persistence logic, AI logic | `ALFeatures`, `ALDesignSystem`, service modules |
| `ALDesignSystem` | Shared UI components, tokens, inspector primitives, document preview host | `AppTheme`, `StatusBadge`, `InspectorPane`, `DocumentPreviewHost` | Navigation, business state, persistence | none |
| `ALDomain` | Pure value types, IDs, enums, money/date types, entity structs, invariants | `Money`, `ObjectRef`, `ApprovalState`, domain errors | DB, file I/O, SwiftUI, network | none |
| `ALAudit` | Append-only audit logging and provenance reconstruction | `AuditLogger`, `ProvenanceTraceService`, `AuditEventWriter` | Approval UI, business calculations | `ALDomain`, `ALStorage` |
| `ALStorage` | SQLite/SQLCipher, migrations, blob vault, FTS, Keychain-backed secrets, repository implementations | `DatabasePoolProvider`, `BlobStore`, `SearchIndex`, `SecretStore` | Tax rules, reconciliation logic, AI routing | `ALDomain` |
| `ALWorkspace` | Workspace lifecycle, legal entities, tax years, settings, recent workspaces | `WorkspaceService`, `LegalEntityService`, `TaxYearService`, `WorkspacePolicyService` | Imports, journal posting, export building | `ALDomain`, `ALStorage`, `ALAudit` |
| `ALImports` | Import job orchestration and plugin contracts for CSV/CAMT/PDF/eCH/QR | `ImportJobService`, `Importer`, `ImportPipeline`, `ParseLog` | Ledger truth, issue policy, AI prompts | `ALDomain`, `ALStorage`, `ALAudit`, `ALDocuments`, `ALLedger` |
| `ALLedger` | Chart of accounts, financial accounts, transactions, journal posting, period locking | `LedgerAccountService`, `FinancialAccountService`, `TransactionService`, `PostingEngine`, `PeriodLockService` | OCR, evidence matching, XML export, AI chat | `ALDomain`, `ALStorage`, `ALAudit`, `ALWorkspace` |
| `ALDocuments` | Document records, text extraction orchestration, metadata confirmation, preview/query APIs | `DocumentService`, `DocumentExtractionPipeline`, `DocumentQueryService` | File hashing storage internals, reconciliation truth, tax computation | `ALDomain`, `ALStorage`, `ALAudit`, `ALWorkspace` |
| `ALEvidence` | Evidence graph, reconciliation, requirement computation, issue creation/update | `EvidenceGraphService`, `ReconciliationService`, `RequirementService`, `IssueService` | Tax calculations, raw import parsing, LLM calls | `ALDomain`, `ALStorage`, `ALAudit`, `ALLedger`, `ALDocuments`, `ALWorkspace` |
| `ALTaxCore` | Canonical `TaxFact` model, rule-pack execution, deterministic tax derivation | `TaxFactService`, `TaxComputationService`, `RulePackRegistry`, `TaxValidationService` | XML serialization, portal submission, AI-generated numbers | `ALDomain`, `ALStorage`, `ALAudit`, `ALLedger`, `ALEvidence`, `ALWorkspace` |
| `ALTaxCH` | Swiss-specific adapters for personal tax, VAT, and later business tax | `PersonalTaxAdapter`, `VATAdapter`, `BusinessTaxAdapter` | Canonical fact ownership, DB, chat UI | `ALTaxCore`, `ALEvidence`, `ALLedger`, `ALWorkspace` |
| `ALExports` | Filing package assembly, manifests, XSD/schema validation, review bundles | `FilingPackageService`, `ExportValidator`, `ManifestBuilder`, `ReviewBundleBuilder` | Tax logic ownership, portal submission state | `ALDomain`, `ALStorage`, `ALAudit`, `ALTaxCore`, `ALTaxCH`, `ALDocuments` |
| `ALToolBus` | Typed tool registry shared by UI actions and AI agents | `ToolRegistry`, `ToolExecutor`, `ToolPolicy`, `ToolContext` | LLM provider logic, direct SQL, direct shell | `ALDomain`, `ALAudit`, service-module interfaces |
| `ALAI` | Router/specialists, proposal creation, chat sessions, provider abstraction, approval gates | `AgentRouter`, `ProposalService`, `ChatSessionService`, `LLMProvider` | Deterministic calculations, authoritative writes without approvals | `ALDomain`, `ALStorage`, `ALAudit`, `ALToolBus` |
| `ALFeatures` | Screen and view-model layer for Overview, Inbox, Ledger, Documents, Tax Studio, Settings, Copilot | `OverviewFeature`, `InboxFeature`, `LedgerFeature`, `DocumentsFeature`, `TaxStudioFeature`, `SettingsFeature`, `CopilotFeature` | DB access, file vault internals, domain ownership | service modules + `ALDesignSystem` |

### Recommended initial implementation order

1. `ALDomain` → `ALStorage` → `ALAudit`
2. `ALWorkspace` + app shell + `ALDesignSystem`
3. `ALLedger`
4. `ALDocuments`
5. `ALImports`
6. `ALEvidence`
7. `ALTaxCore`
8. `ALTaxCH`
9. `ALExports`
10. `ALToolBus`
11. `ALAI`
12. Expand `ALFeatures` as each service becomes real

## 5. Canonical data model

### Model rules

- Authoritative: confirmed workspace/entity/account config, raw imports, imported transactions, posted journal entries, confirmed evidence links, finalized filing artifacts, audit log
- Derived: issues, deterministic tax facts, requirement rows, read models
- Proposed: agent outputs, draft journal entries, suggested links, unapproved overrides

### Workspace and ledger

| Entity | Purpose | Key fields | Relationships | Truth / lifecycle |
|---|---|---|---|---|
| `Workspace` | Top-level local container | `id`, `name`, `storageVersion`, `createdAt`, `defaultCurrency`, `privacyMode`, `encryptionSaltRef` | 1→N `LegalEntity`, `Document`, `Issue`, `AuditEvent`, `AgentProposal` | Authoritative; metadata mutable + audited |
| `LegalEntity` | Natural person, joint filing, sole prop, or legal entity | `id`, `workspaceId`, `kind`, `legalName`, `displayName`, `country`, `canton`, `taxIdOrUID`, `fiscalYearStart`, `parentEntityId` | N→1 `Workspace`; 1→N `FinancialAccount`, `TaxYear`, `JournalEntry`, `TaxFact`, `FilingPackage` | Authoritative config; mutable with audit |
| `TaxYear` | Entity/year/jurisdiction scope | `id`, `entityId`, `year`, `periodStart`, `periodEnd`, `canton`, `filingMode`, `rulesetVersion`, `status` | N→1 `LegalEntity`; 1→N `TaxFact`, `Issue`, `FilingPackage` | Authoritative config; lock/file state approval-gated |
| `LedgerAccount` | Canonical chart-of-accounts node for postings | `id`, `entityId`, `code`, `name`, `category`, `normalBalance`, `parentId`, `taxRole`, `isControlAccount` | N→1 `LegalEntity`; 1→N `JournalLine`; linked from `FinancialAccount` | Authoritative; config changes versioned |
| `FinancialAccount` | Real-world bank, card, cash, loan, or other source account | `id`, `entityId`, `accountType`, `institutionName`, `displayName`, `currency`, `ibanMask`, `statementCadence`, `ledgerControlAccountId`, `openedAt`, `closedAt` | N→1 `LegalEntity`; 1→N `StatementImport`, `Transaction` | Authoritative metadata; audited |
| `ImportJob` | Batch/run record for import and replay | `id`, `workspaceId`, `kind`, `source`, `parserKey`, `parserVersion`, `status`, `startedAt`, `completedAt`, `warningCount`, `counters` | N→1 `Workspace`; 1→N `StatementImport`, `Document`, `Issue`, `AuditEvent` | Operational authoritative; append-only status history preferred |
| `StatementImport` | Immutable imported statement or extract record | `id`, `accountId`, `importJobId`, `sourceBlobHash`, `sourceFormat`, `sourceFingerprint`, `coverageStart`, `coverageEnd`, `openingBalanceMinor`, `closingBalanceMinor`, `parserVersion`, `status` | N→1 `FinancialAccount`; N→1 `ImportJob`; 1→N `Transaction`; optional N→1 `Document` | Authoritative source record; supersede, do not overwrite |
| `Transaction` | Normalized bank/card/manual movement | `id`, `accountId`, `statementImportId`, `originKind`, `sourceLineRef`, `bookingDate`, `valueDate`, `amountMinor`, `currency`, `counterpartyName`, `memo`, `referenceSet`, `balanceAfterMinor`, `reviewState` | N→1 `FinancialAccount`; optional N→1 `StatementImport`; linked to `JournalEntry`, `Document`, `Issue`, `AgentProposal` via refs | Authoritative source fact; imported source slice immutable |
| `JournalEntry` | Double-entry posting unit | `id`, `entityId`, `taxYearId`, `entryNumber`, `effectiveDate`, `kind`, `status`, `memo`, `reversalOfId`, `createdBy`, `approvedBy`, `approvedAt` | N→1 `LegalEntity`; 1→N `JournalLine` | Draft until approved; posted entries authoritative |
| `JournalLine` | Debit/credit line item | `id`, `journalEntryId`, `ledgerAccountId`, `debitMinor`, `creditMinor`, `currency`, `taxCode`, `sourceObjectRef`, `memo` | N→1 `JournalEntry`; N→1 `LedgerAccount` | Authoritative only when parent entry is posted |

### Documents, evidence, and operations

| Entity | Purpose | Key fields | Relationships | Truth / lifecycle |
|---|---|---|---|---|
| `Document` | Stored file plus confirmed metadata shell | `id`, `workspaceId`, `importJobId`, `blobHash`, `originalFilename`, `mediaType`, `origin`, `documentType`, `issueDate`, `detectedEntityId`, `detectedTaxYearId`, `extractedTextRef`, `metadataStatus`, `parseVersion` | N→1 `Workspace`; optional N→1 `ImportJob`; linked to `StatementImport`, `Transaction`, `TaxFact`, `FilingPackage` via `EvidenceLink` | Blob/hash authoritative; extracted metadata derived or proposed until confirmed |
| `EvidenceLink` | Typed edge between finance/doc/tax objects | `id`, `sourceRef`, `targetRef`, `linkType`, `status`, `confidence`, `createdByKind`, `approvalRequired`, `proposalId`, `reason` | Polymorphic links across `Document`, `Transaction`, `JournalEntry`, `TaxFact`, `FilingPackage`, `Issue` | Proposed or confirmed; destructive links approval-gated |
| `Requirement` | Computed “what should exist” record for missingness | `id`, `entityId`, `taxYearId`, `requirementCode`, `coverageStart`, `coverageEnd`, `severity`, `status`, `satisfiedByRefs`, `rulesetVersion` | N→1 `LegalEntity`; optional N→1 `TaxYear`; feeds `Issue` generation | Derived; recomputable and ruleset-versioned |
| `Issue` | Operational problem, blocker, or warning | `id`, `workspaceId`, `entityId`, `taxYearId`, `issueCode`, `severity`, `status`, `title`, `summary`, `ruleRef`, `objectRefs`, `firstDetectedAt`, `lastDetectedAt`, `resolutionKind` | N→1 `Workspace`; optional N→1 `LegalEntity`; optional N→1 `TaxYear` | Detection is derived; resolution state authoritative and audited |

### Tax, export, audit, and AI

| Entity | Purpose | Key fields | Relationships | Truth / lifecycle |
|---|---|---|---|---|
| `TaxFact` | Canonical normalized tax fact | `id`, `entityId`, `taxYearId`, `conceptCode`, `valueType`, `moneyMinor`, `textValue`, `boolValue`, `dateValue`, `currency`, `factStatus`, `rulesetVersion`, `provenanceRefs`, `confidence`, `supersedesFactId`, `overrideReason` | N→1 `LegalEntity`; N→1 `TaxYear`; supported by `EvidenceLink`; consumed by `FilingPackage` | Deterministic facts can be authoritative; overrides require review |
| `FilingPackage` | Generated export artifact and validation state | `id`, `entityId`, `taxYearId`, `packageType`, `standardCode`, `standardVersion`, `status`, `manifestRef`, `outputBlobHash`, `validationReportRef`, `generatedAt`, `finalizedAt`, `finalizedBy` | N→1 `LegalEntity`; N→1 `TaxYear`; references `TaxFact` and `Document` support set | Drafts mutable; each finalized artifact immutable |
| `AuditEvent` | Immutable event history | `id`, `workspaceId`, `actorType`, `actorId`, `eventType`, `objectRef`, `payload`, `beforeHash`, `afterHash`, `sessionId`, `correlationId`, `occurredAt` | N→1 `Workspace`; references any object | Immutable authoritative append-only |
| `AgentProposal` | AI-created suggestion awaiting review | `id`, `workspaceId`, `agentKind`, `proposalType`, `targetRef`, `payload`, `confidence`, `rationale`, `sourceRefs`, `toolTraceRefs`, `status`, `requiresApproval`, `decidedBy`, `decidedAt`, `appliedObjectRef` | N→1 `Workspace`; references `Transaction`, `Document`, `EvidenceLink`, `JournalEntry`, `Issue`, `TaxFact` | Proposed only; immutable payload, status transitions only |

### Lifecycle callouts

- Immutable: `StatementImport` raw source fields, `Document.blobHash` content, imported `Transaction` source slice, finalized `FilingPackage`, `AuditEvent`
- Versioned or superseded: `TaxFact`, document extraction metadata, `LegalEntity` settings, `FinancialAccount` settings, ruleset-driven `Requirement`
- Draft-only: `JournalEntry(status = draft)`, draft `FilingPackage`, `AgentProposal`, proposed `EvidenceLink`
- Approval-gated: posting or reversing `JournalEntry`, confirming truth-affecting `EvidenceLink`, overriding `TaxFact`, finalizing or exporting `FilingPackage`

## 6. TaxHacker → AlpenLedger feature mapping

Bottom line: no TaxHacker production code area should be reused as AlpenLedger’s foundation.

| TaxHacker area | Decision | AlpenLedger replacement | Rationale |
|---|---|---|---|
| Product flow and screenshot story in `README.md` | Adapt conceptually | Overview + Inbox + Documents + Tax Studio flow | Useful for user expectations, not for truth model |
| `app/(app)/unsorted/*`, `components/unsorted/*`, `models/files.ts` | Adapt conceptually | `InboxFeature` + `ALDocuments` + proposal review queue | Intake workflow is valuable, but AlpenLedger must separate raw intake from authoritative truth |
| `ai/*`, `components/agents/*` | Adapt conceptually | `ALToolBus` + `ALAI` + `AgentProposal` + audit traces | Prompt/provider ideas help; direct AI-to-record mutation does not |
| `prisma/schema.prisma` flat user/file/transaction model | Discard | Canonical ledger/evidence/tax schema in `ALDomain` | Incompatible with multi-entity double-entry provenance model |
| Transactions UI areas | Adapt conceptually | `LedgerFeature` over immutable `Transaction` + approval-gated `JournalEntry` | UX patterns useful; mutation semantics are not |
| CSV import and export helpers | Adapt conceptually | `ALImports` with versioned importers and parse logs | Need replay, idempotency, and raw-source preservation |
| Settings and flexible metadata areas | Adapt conceptually | Workspace/entity settings, tags/reporting dimensions, importer presets, mapping rules | Flexible metadata is fine, but must not define canonical tax facts |
| Backup areas | Adapt conceptually | Workspace backup/restore with schema version + blob manifest | Portability matters, but restore must preserve audit/import provenance |
| Dashboard/stats areas | Adapt conceptually | Overview status board focused on blockers, missing evidence, open issues, filing readiness | Trust and completeness outrank generic dashboards |
| Invoices app area | Discard / defer | Later AR/invoicing module | Not core to v1 architecture |
| Auth, Stripe, Docker, web runtime | Discard | None in core product | Incompatible with macOS-first local-first baseline |

## 7. Swift scaffold plan

### Suggested folder and package layout

```text
AlpenLedger.xcworkspace
├── App/
│   └── AlpenLedgerApp/
│       ├── AlpenLedgerApp.swift
│       ├── Root/
│       ├── Navigation/
│       └── DependencyContainer.swift
├── Packages/
│   └── AlpenLedgerKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── ALDomain/
│       │   ├── ALAudit/
│       │   ├── ALStorage/
│       │   ├── ALWorkspace/
│       │   ├── ALLedger/
│       │   ├── ALDocuments/
│       │   ├── ALImports/
│       │   ├── ALEvidence/
│       │   ├── ALTaxCore/
│       │   ├── ALTaxCH/
│       │   ├── ALExports/
│       │   ├── ALToolBus/
│       │   ├── ALAI/
│       │   ├── ALDesignSystem/
│       │   └── ALFeatures/
│       └── Tests/
│           ├── ALDomainTests/
│           ├── ALStorageTests/
│           ├── ALImportsTests/
│           ├── ALLedgerTests/
│           ├── ALEvidenceTests/
│           └── ALTaxCoreTests/
└── Fixtures/
    ├── Bank/
    ├── Documents/
    └── Tax/
```

### Initial app screens

| Screen | Purpose | First pass |
|---|---|---|
| Workspace chooser / create | Open/create local workspace, recent list, recovery | Milestone 1 |
| Overview | Open issues, recent imports, entity/year status, quick actions | Milestone 1 |
| Inbox | Unreviewed documents, statement imports, low-confidence proposals | Milestone 2 |
| Ledger | Accounts sidebar, transaction table, transaction inspector | Milestone 2 |
| Documents | Vault list/grid, PDF/image preview, metadata inspector, linked evidence | Milestone 2 |
| Tax Studio | Tax years, blockers, readiness cards, package stub | Milestone 3 |
| Settings | Workspace, entities, accounts, privacy, importer presets | Milestone 1 |
| Copilot | Feature-flagged; read-only Q&A first | After `ALToolBus` |

### Persistence choices

- Primary store: SQLite via GRDB-style control; use WAL mode, foreign keys, FTS5, and explicit migrations
- Encryption shape: SQLCipher-backed DB + per-workspace blob encryption behind `ALStorage`
- Blob store: content-addressed vault under Application Support, keyed by SHA-256
- Secrets: Keychain only
- Search: SQLite FTS for document text, counterparty, memo, and references
- Do not use: SwiftData as the authoritative core, raw file-path references as truth, or direct DB access from UI/AI

### First test targets

- `ALDomainTests`: money math, journal balancing, object state transitions, approval invariants
- `ALStorageTests`: migration smoke tests, foreign-key integrity, FTS indexing, repository round-trips
- `ALImportsTests`: CSV/CAMT fixture parsing, idempotent replay, parser-version capture
- `ALLedgerTests`: posting engine, lock-period rejection, transaction supersession/reversal behavior
- `ALEvidenceTests`: statement coverage, missing receipt detection, evidence-link approval rules
- `ALTaxCoreTests`: deterministic fact derivation from fixtures
- `AlpenLedgerAppUITests`: launch, create workspace, import fixture, open ledger/documents screens

### First three milestones

| Milestone | Outcome | Exit criteria |
|---|---|---|
| M1 — Foundation shell | App launches into a real workspace with DB, vault, audit, settings | Create/open workspace; migrations run; audit events persist; settings and entity screens work |
| M2 — Ledger + Documents vertical slice | Real accounts, transactions, documents, preview, search | Import a fixture document and a CSV; view transactions; open PDF preview; create manual evidence link |
| M3 — Inbox + evidence engine | Review queue and missingness begin to feel product-real | Import jobs visible; low-confidence proposals stored; statement coverage + missing invoice issues computed |

### Minimal UI/state approach

- Use SwiftUI + Observation for feature state
- Use actors for import, extraction, and background jobs
- Use `NavigationSplitView` as the shell
- Keep feature view models thin; orchestration lives in service modules
- If the team is small, keep all screens inside one `ALFeatures` target first, but do not collapse core service/storage boundaries

## 8. Recommended immediate next actions

1. Keep this file as the current pass-level decision source until the scaffold exists.
2. Add ADRs for the app/module boundary decision and the persistence/canonical-model decision.
3. Scaffold in this order: app shell → `ALDomain` / `ALStorage` / `ALAudit` → `ALWorkspace` → `ALLedger` → `ALDocuments`.
4. Collect fixture sets before coding import logic: CSV, CAMT, receipt/invoice PDFs, QR-bill, salary certificate, and one tax-year sample bundle.
5. Treat the first coding slice as a vertical proof: create workspace → import file → persist document/transaction → show in Inbox/Ledger/Documents → audit every step.

## Cross-links

- [architecture.md](./architecture.md)
- [buildplan.md](./buildplan.md)
- [vision.md](./vision.md)
- [ADR-001](./adr/ADR-001-local-core-and-module-boundaries.md)
- [ADR-002](./adr/ADR-002-persistence-and-canonical-model.md)

## References

[^xcode]: Apple Developer, [Xcode support matrix](https://developer.apple.com/support/xcode)
[^swift]: Swift.org, [Install Swift](https://www.swift.org/install/)
[^grdb]: GRDB.swift, [latest releases](https://github.com/groue/GRDB.swift/releases)
[^sqlcipher]: SQLCipher, [latest releases](https://github.com/sqlcipher/sqlcipher/releases)
