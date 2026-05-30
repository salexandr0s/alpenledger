# Product Scope Lock

Status: Locked for v0.1 pilot readiness
Last reviewed: 2026-05-30

## Locked V1 Thesis

AlpenLedger is a local-first macOS finance workspace for Swiss personal and
small-business finance. The deterministic ledger, evidence graph, tax rules,
and export validators own financial truth; AI assists by explaining,
classifying, proposing, and asking questions through typed tools.

The first production-readiness line should prove trust, locality, evidence
completeness, and review-first workflows before broadening canton, entity,
payroll, or filing-submission coverage.

## Target Users

- Swiss natural persons who want transactions, annual tax documents, evidence
  gaps, and return readiness in one local workspace.
- Swiss sole proprietors and freelancers who need a clear personal/business
  split, expense evidence, statement coverage, VAT readiness, and year-end
  review support.
- Fiduciaries or accountants who review a local support bundle or filing
  package prepared by the user.

## Pilot Canton

The v0.1 personal-tax pilot canton is Zurich for tax year 2026.

Evidence in the current implementation:
- `ZurichPersonalTaxAdapter2026` is the registered personal-tax adapter.
- `config/rule-pack-catalog.json` declares the Zurich 2026 ruleset metadata.
- `config/fixture-catalog.json` includes the synthetic Zurich 2026
  personal-tax fixture pack.

Non-Zurich cantons remain future scope until they have rule packs, fixtures,
schema/export evidence, and UI copy reviewed with the same standard.

## Pilot Business Profile

The v0.1 business pilot profile is a Swiss sole proprietor / freelancer service
business with:
- CHF bank/card activity,
- receipts and supplier invoices as evidence,
- statement coverage checks,
- simple VAT period preparation and eCH-0217 export validation,
- year-end readiness diagnostics.

Out of scope for this pilot:
- payroll-heavy businesses,
- inventory and manufacturing,
- multi-currency accounting,
- consolidated groups,
- broad GmbH/AG tax filing completion,
- automatic authority submission.

## V1 Non-Goals

- Universal canton support.
- Automatic filing submission.
- Swissdec certification.
- Full payroll processing.
- Hosted multi-user collaboration.
- Cloud inference by default.
- Silent AI-driven ledger or tax mutation.

## Scope Review Rules

- Any broadening of canton, entity, submission, payroll, or cloud scope needs a
  new ADR or an update to this file.
- The checklist can only mark scope items complete when this file and the
  implementation evidence agree.
- Release notes must state whether the current artifact is pilot, release
  candidate, or production-ready.
