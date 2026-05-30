# ADR-001 — Local core and module boundaries

## Title
Local-core macOS app with multi-module Swift package boundaries

## Status
Accepted

## Context

AlpenLedger is a local-first Swiss finance manager and tax-return studio for
macOS. The system must preserve auditability, deterministic financial truth,
explicit approvals, and future compatibility with typed tool exposure for AI
and MCP-style integrations.

The repo now contains a checked-in Xcode workspace, macOS app target, and local
Swift package. This ADR records the boundary decision that those artifacts must
continue to follow as the product moves from scaffold to production-readiness.

## Decision Drivers

- Local-first trust and offline operation
- Deterministic accounting/tax core
- Strong provenance and audit boundaries
- Native macOS workflows and document handling
- Future typed tool bus exposure without direct storage access
- Testability for imports, rules, and exports
- Low risk of “one big module” boundary erosion over time

## Considered Options

### Option 1
App target plus one large `Core` module

Pros:
- Fastest initial scaffold
- Lowest short-term package overhead
- Easier for a solo engineer to start moving quickly

Cons:
- Weak compile-time boundaries
- High risk that storage, tax logic, UI orchestration, and AI concerns bleed together
- Harder to expose clean typed tools later
- Harder to audit ownership of deterministic vs proposal logic

### Option 2
App target plus a multi-module local Swift package

Pros:
- Clear boundaries for domain, storage, ledger, documents, evidence, tax, exports, tool bus, and AI
- Better long-term testability and change isolation
- Makes approval-gated writes and provenance boundaries explicit
- Creates a clean path for future MCP/tool exposure

Cons:
- More upfront structure
- More targets to manage
- Slightly higher coordination cost while the codebase is small

### Option 3
Web-style runtime or hybrid local/server architecture

Pros:
- Easier future remote collaboration and hosted sync
- Potentially simpler cross-platform story later

Cons:
- Conflicts with local-first product promise
- Adds auth, sync, and remote state complexity immediately
- Weakens the macOS-native experience
- Adds avoidable data-governance and compliance scope

## Decision

Choose option 2: a native macOS app target backed by a multi-module local Swift package.

The workspace should follow the `AlpenLedgerApp` + `AlpenLedgerKit` structure
described in [`architecture-pass-v1.md`](../architecture-pass-v1.md). The
current implementation keeps domain, storage, audit, workspace, ledger,
documents, evidence, tax, design-system, and feature concerns in separate local
package targets where they exist, and new production surfaces should preserve
that boundary discipline.

## Consequences

Positive:
- Compile-time boundaries support the trust model instead of relying on team discipline alone
- Deterministic rules, storage, and AI proposal flows stay separable
- Testing can focus on modules with clear ownership
- Future Swiss adapters and tool exposures have stable homes

Negative:
- The first scaffold takes longer than a single-module prototype
- Some module boundaries may need adjustment as real workflows land
- Small-team ergonomics can feel heavier early on

## Revisit Triggers

- The product adds cross-platform clients that need a different packaging strategy
- Multi-user sync becomes a near-term requirement
- The module graph becomes too granular for the actual team size and delivery speed
- Build times or package-management friction materially slow development

## Follow-ups

- Keep the checked-in workspace and package graph aligned with the architecture
  pass
- Add or preserve dependency-graph checks so UI and AI targets cannot import
  storage directly
- Keep the first UI screens inside one `ALFeatures` target until the team or surface area justifies splitting them further
- Document exact package pins and toolchain selection when `Package.swift` and the Xcode workspace are added
