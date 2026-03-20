# ADR-003: Entity-Workspace Scoping

**Status:** Accepted
**Date:** 2026-03-20

## Context

AlpenLedger supports multiple legal entities within a single workspace (e.g., a natural person and a sole proprietorship). Swiss tax filing requires per-entity submissions, and users need clear entity-level isolation when reviewing financial data.

Before this change, most screens treated data as workspace-wide. Documents, transactions, and issues were displayed without filtering by entity, making multi-entity workspaces confusing. The `detectedEntityId` on documents provided a heuristic link but was not authoritative.

Additionally, the app's central `WorkspaceAppModel` had grown to 2,144 lines, combining navigation state, service orchestration, data caching, snapshot computation, and presentation helpers in a single file.

## Decision

### Entity-Workspace model
Introduce `EntityWorkspace` as the user-facing context that ties a `LegalEntity` to its workspace presentation. This is not a replacement for `Workspace` or `LegalEntity` - it's the "which entity am I working as" anchor.

### Document entity-scoping
Add an authoritative `entityId` column to `documents` (nullable FK to `legalEntities`). Backfill from `detectedEntityId` where non-null. Keep `detectedEntityId` as the heuristic source.

### Entity switcher
Add a compact entity picker in the sidebar header. Switching entity refreshes data for the visible section, scoping ledger/documents/inbox to the active entity.

### God object decomposition
Split `WorkspaceAppModel` into focused components:
- `ActiveWorkspaceSession` - services, data cache, entity switching, refresh logic
- `WorkspaceAppModel+Snapshots` - view model snapshot computation
- `PresentationHelpers` - labels, symbols, formatters
- `WorkspaceAppModel` - thin facade with navigation state and action dispatch

### New domain models
Add `TaxProfile`, `TransactionCategory`, `InvoiceRecord`, `FilingPackage` to complete the domain model layer for future features.

## Alternatives Rejected

1. **Separate databases per entity** - Would prevent cross-entity queries and complicate workspace-level operations (backup, export). Entity-scoping within a single DB is simpler.

2. **Implicit entity from detection only** - `detectedEntityId` is unreliable for many document types. An explicit, user-confirmable `entityId` provides a trustworthy FK.

3. **Full rewrite of WorkspaceAppModel** - Too risky. Incremental decomposition via delegation and extensions preserves all existing behavior while reducing the main file from 2,144 to ~900 lines.

## Consequences

- All data-fetching paths support optional entity filtering
- Migration v5 adds 5 new tables and 1 new column with backfill
- Existing single-entity workspaces work unchanged (entity switcher hidden when only one entity exists)
- Future features (invoicing, tax filing, categorization) have their domain models ready
- God object decomposition makes the codebase more navigable and testable

## Implementation Deviations

### AppCoordinator not extracted

The plan called for extracting navigation state into a separate `AppCoordinator` type. In practice, SwiftUI's `@Bindable` property wrapper requires two-way-bindable properties to live on the observed object itself (`WorkspaceAppModel`). Extracting navigation state to a sub-object would require either `Binding(get:set:)` wrappers at every call site or `@Bindable` on the sub-object in every view — both adding complexity without reducing the model's responsibilities in a meaningful way. Navigation state remains on `WorkspaceAppModel`; action dispatch methods remain there as thin wrappers that delegate data work to the session.

### Session-level scoping vs per-service scoping

The plan listed 11 services for entity-scoping refactor. Instead, scoping is enforced at a single point — `ActiveWorkspaceSession.refreshCoreData()` — which filters `financialAccounts`, `documents`, and `issues` by `activeEntityId` before the UI sees them. Individual services remain workspace-wide, which is cleaner: the scoping logic lives in one place rather than being scattered across 11 service classes, and services can still be used for cross-entity operations (e.g., deletion checks, evidence refresh) without special "unscoped" overloads.
