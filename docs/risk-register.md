# Risk Register

Status: Active
Last reviewed: 2026-05-30

## Review Cadence

Review this register before every release candidate and whenever a feature
changes ledger truth, tax facts, source-document handling, model-provider
policy, export generation, backup/restore, or release signing.

## Register

| ID | Category | Risk | Impact | Mitigation | Evidence | Status |
|---|---|---|---|---|---|---|
| R-LEGAL-001 | Legal | Users may treat draft filing artifacts or Copilot summaries as official filing completion. | Incorrect or incomplete filing behavior. | Keep prepared-vs-filed states separate, require validation evidence, avoid automatic submission in v0.1, and label Tax Studio package review states as not filed unless an external submitted/accepted status is recorded. | `docs/release.md`, `docs/product-scope.md`, filing package status tests, `testTaxStudioSnapshotSeparatesPreparedFilingPackagesFromFiledReturns`. | Mitigated |
| R-TAX-001 | Tax | Tax values could be inferred without evidence or deterministic rule support. | False deductions or missing taxable facts. | Tax facts come from rule services, evidence refs, manual overrides, and audited user approval; agent answers must cite grounded sources. | `TaxFactService`, `TaxFactExplanationService`, agent answer composer tests. | Mitigated |
| R-SEC-001 | Security | Local finance data or document contents could leave the device unexpectedly. | Privacy breach and loss of trust. | Default local-only runtime, source checks for network APIs, explicit cloud provider policy, and sanitized diagnostics. | `scripts/verify-local-only.sh`, `docs/ai-privacy-controls.md`, model-provider policy tests. | Mitigated |
| R-DATA-001 | Data Integrity | Imported source files could be mutated, lost, or deduplicated incorrectly. | Unreliable audit trail and broken reconciliation. | Store immutable raw source blobs, hash imports, keep replay metadata, and test source persistence after original files change. | Raw import immutability tests, fixture catalog verification. | Mitigated |
| R-AI-001 | AI Safety | Agent or Copilot write paths could mutate authoritative ledger/tax data without review. | Corrupted financial truth. | Tool bus separates read/proposal/confirmed writes; confirmed writes require input-bound explicit approval; Copilot task writes only issues. | Agent tool policy tests, pending approval storage tests, Copilot task audit test. | Mitigated |
| R-RELEASE-001 | Release | A release artifact could be distributed without Developer ID signing, notarization, or matching release evidence. | Gatekeeper failures and untrusted distribution. | Preflight, artifact, and release-evidence verifiers check signing/notary configuration, metadata, stapled ticket, Gatekeeper, checksum sidecars, and archived command evidence before release. | `scripts/verify-release-preflight.sh`, `scripts/verify-release-artifact.sh`, `scripts/verify-release-evidence.sh`, `docs/release.md`. | Open |
| R-UI-001 | Quality | Native UI automation or manual smoke evidence may be missing on the release machine. | Regressions in navigation, import, Copilot, backup/restore, or visual polish. | Keep UI automation opt-in but documented; fail fast when macOS Accessibility UI scripting is unavailable; require a strict UI smoke evidence JSON before release candidates; keep backup/check/restore panel paths deterministic for app-model and UI tests; run full UI automation and manual smoke before release candidate. | `scripts/verify-ui-automation-preflight.sh`, `scripts/verify-ui-smoke-evidence.sh`, `docs/ui-smoke-pass-macos.md`, UI test suite, `testBackupPanelActionsUseConfiguredSelectionsThroughWorkspaceAppModel`, readiness audit notes. | Open |
