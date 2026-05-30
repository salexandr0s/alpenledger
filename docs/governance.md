# Documentation And Governance Rules

Status: Active
Last reviewed: 2026-05-30

## Source Of Truth

- `docs/vision.md` owns the long-form product thesis and product promise.
- `docs/architecture.md` owns high-level system architecture.
- `docs/architecture-pass-v1.md` owns the dated v1 architecture/toolchain pass.
- `agents.md` owns the agent-system safety model and typed-tool philosophy.
- `docs/buildplan.md` owns delivery sequencing and roadmap assumptions.
- `docs/internal/prompt.md` owns the end-to-end build prompt used to bootstrap
  or re-run implementation work.
- `docs/product-scope.md` owns v0.1 scope, target users, pilot canton, pilot
  business profile, and non-goals.
- `docs/risk-register.md` owns release-impacting legal, tax, security,
  data-integrity, AI-safety, release, and UI risks.
- `docs/adr/` owns durable architecture decisions.
- `docs/checklist.md` owns build-readiness status and evidence notes.
- `docs/readiness-audit-2026-05-29.md` owns the current audit trail for this
  readiness push.
- `docs/release.md` and `docs/release-notes/` own release evidence and
  user-facing release notes.

## Maintenance Rules

- Update `docs/checklist.md` only when an item has implementation, tests or a
  verifier, documentation, and reviewable evidence.
- Update the readiness audit when a new gate is added, when a gate fails for an
  environmental reason, or when a release blocker changes state.
- Add or update an ADR when changing storage, module boundaries, entity
  scoping, AI/tool permissions, release trust boundaries, or external
  integration posture.
- Update the risk register when a change touches ledger truth, tax facts,
  document handling, model-provider policy, export generation, backup/restore,
  release signing, or UI release gates.
- Keep release notes in draft until strict evidence has been captured.
- Prefer verifiable scripts over prose-only assertions for release gates.
- Keep cross-links and required-reading paths on canonical checked-in paths
  under `docs/` where the canonical file lives.

## Verification

`scripts/verify-product-governance.sh` checks that scope, risk, ADR, and
documentation-maintenance artifacts exist and contain the required release
governance anchors. The verifier is part of `scripts/verify-readiness.sh`.
`scripts/verify-doc-alignment.sh` checks the required source-of-truth map,
canonical cross-links, prompt reading order, and core thesis boundaries across
the vision, architecture, agent, build-plan, prompt, scope, and checklist docs.
