# ADR-002 — Persistence and canonical model

## Title
SQLite/SQLCipher canonical store with append-only import truth and explicit support entities

## Status
Proposed

## Context

AlpenLedger needs a local authoritative store for ledger data, documents, evidence links, tax facts, exports, and audit events. The product also needs replayable imports, explainable provenance, encrypted-at-rest storage, and deterministic export generation for Swiss standards.

The storage choice is inseparable from the canonical data model. Raw imports must remain immutable, approvals must be auditable, and derived or proposed values must stay distinguishable from confirmed truth.

## Decision Drivers

- Precise migration control
- Encrypted local storage
- Import idempotency and replay
- Explicit provenance and auditability
- Strong querying for validation, search, and reporting
- Deterministic handling of financial and tax facts
- Low tolerance for silent mutation or opaque ORM behavior

## Considered Options

### Option 1
SwiftData or another opaque high-level persistence layer as the system of record

Pros:
- Apple-native ergonomics
- Lower initial model boilerplate
- Faster first prototype for simple CRUD

Cons:
- Less explicit migration and query control
- Weaker fit for append-only import truth and complex validation views
- Higher risk of accidental model mutation semantics leaking into authoritative data
- Not ideal for FTS-heavy and provenance-heavy workflows

### Option 2
SQLite with SQLCipher, explicit migrations, and a content-addressed blob vault

Pros:
- Strong control over schema, migrations, foreign keys, and FTS
- Good fit for append-only import records and read-model queries
- Encryption and blob-vault boundaries can be isolated in storage services
- Supports deterministic exports, validation queries, and audit reconstruction well

Cons:
- More infrastructure work
- Manual repository and migration discipline required
- More explicit storage code than a higher-level framework

### Option 3
Flat files / JSON documents plus ad hoc indexes

Pros:
- Simple to understand at very small scale
- Potentially human-inspectable storage

Cons:
- Poor fit for relational validation and reconciliation workloads
- Hard to maintain integrity rules and migrations
- Weak performance and query ergonomics for large document/transaction sets
- FTS, foreign keys, and idempotent replay become custom infrastructure

## Decision

Choose option 2: SQLite with SQLCipher behind `ALStorage`, backed by a content-addressed blob vault and explicit migrations.

The canonical model should distinguish:
- authoritative facts,
- derived values,
- proposed values,
- immutable audit history.

The first canonical entity set must include:
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
- `Requirement`
- `Issue`
- `TaxFact`
- `FilingPackage`
- `AuditEvent`
- `AgentProposal`

The explicit addition of `LedgerAccount`, `Requirement`, and `ImportJob` is required in v1 because journal posting, missingness, and importer replay remain underspecified without them.

## Consequences

Positive:
- Import truth can remain append-only and replayable
- Query-heavy workflows like statement coverage, filing completeness, and export validation are easier to implement correctly
- Audit trails and provenance can be reconstructed from stable relational state
- Encryption, secrets, and blob storage remain isolated from UI and AI layers

Negative:
- More storage engineering is required up front
- Database migrations become a core maintenance responsibility
- The team must be disciplined about repository boundaries and supersession semantics

## Revisit Triggers

- A future sync architecture requires a different replication strategy
- Apple-native persistence materially improves control over migrations and queryability
- The blob-vault design proves too rigid for required sharing or backup workflows
- Swiss export standards force a different storage partitioning model

## Follow-ups

- Define the first migration set for workspace, audit, import, ledger, document, and tax tables
- Write repository contracts that enforce raw-import immutability and approval-gated writes
- Document on-disk workspace layout, including DB file, blob vault, and export artifacts
- Add migration smoke tests, import replay tests, and integrity checks before adding AI features
