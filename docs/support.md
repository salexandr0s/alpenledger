# Support Baseline

This runbook defines the minimum support process for the AlpenLedger pilot
release. It is operational documentation for support and triage; it is not a
promise that a signed production artifact has shipped.

## Support Principles

- Treat the local workspace as the source of truth. Support staff should ask
  for sanitized diagnostics first and raw source data only through an explicit,
  private escalation workflow.
- Do not ask users to post workspace databases, source documents, exports,
  backups, or screenshots containing personal finance data in public issue
  trackers.
- Do not tell users that a filing, VAT period, or year-end package is complete
  unless the app's deterministic validation state says it is complete.
- Preserve evidence. Prefer archive, backup, restore, and retry workflows over
  delete/recreate instructions.
- Distinguish observed behavior, deterministic app output, user overrides, and
  agent suggestions in every support response.

## Intake Severity

| Severity | Use when | Target first response |
|---|---|---:|
| P0 | Data loss, workspace cannot open after backup/restore, or a signed release artifact is blocked | Same business day |
| P1 | Import, backup, tax readiness, VAT, or evidence-linking workflow is blocked | 1 business day |
| P2 | Incorrect display, confusing copy, slow workflow, or non-blocking validation warning | 2 business days |
| P3 | Documentation, enhancement, or roadmap request | Next triage batch |

## Customer-Safe Intake Checklist

Ask for only the minimum information needed:

- AlpenLedger version and build from the app bundle or release notes.
- macOS version and device class.
- Whether the workspace is personal, business, or demo data.
- The exact workflow and last user-visible message.
- Whether a current backup exists and whether backup integrity has been checked.
- A sanitized diagnostics report, exported from
  `File > Export Diagnostics...` or Settings.
- A sanitized support bundle, exported from
  `File > Export Support Bundle...` or Settings, when audit-event shape is
  needed.

Do not request raw source documents, full workspace databases, backup bundles,
filing exports, bank statements, or tax certificates during normal intake.

## Diagnostic Artifacts

Users can export local support files from two app surfaces:

- `File > Export Diagnostics...`
- `File > Export Support Bundle...`
- Settings > Support Diagnostics

Diagnostics include database health, schema table counts, and filesystem
counts. Support bundles include diagnostics plus audit-event counts, actor
summaries, object-kind summaries, and bounded recent event metadata.

These files are JSON and should be attached only to the private support issue
or local pilot review channel associated with the user.

## Privacy Boundaries

The diagnostics and support-bundle formats are intended to exclude:

- source documents
- document contents
- document filenames
- transaction descriptions
- transaction amounts
- workspace names
- absolute paths
- encryption keys
- workspace master keys
- raw audit payloads
- raw audit event IDs
- raw audit actor IDs
- raw audit object IDs

If a support response cannot be grounded from sanitized artifacts, say what is
missing and ask for one specific next artifact or reproduction step. Do not
guess amounts, tax values, filing status, or source evidence.

## Backup Safety

Backup bundles contain `workspace.key` and must be treated like live workspace
data. Support staff should ask the user to create and check a backup before any
destructive local action, but should not ask the user to send a backup bundle
through ordinary support channels.

Recommended sequence for risky recovery:

1. Export sanitized diagnostics or a support bundle.
2. Create a local backup bundle.
3. Check backup integrity.
4. Reproduce the issue in the current workspace or a restored copy.
5. Escalate only if the app's recovery path fails.

## Triage Runbooks

### Workspace does not open

- Confirm the app version/build and macOS version.
- Ask whether the workspace was moved, restored, or opened from removable
  storage.
- Request sanitized diagnostics if the app can still open another workspace.
- Ask the user to check the latest backup integrity before attempting restore.
- Escalate as P0 if the workspace and all checked backups fail to open.

### Import failed or data looks incomplete

- Ask which import path was used: CSV bank statement, CAMT bank statement,
  document import, sample data, or QA fixtures.
- Request the import job status, parse diagnostics, and support bundle.
- Check whether the period is locked, the file is unsupported, the file is a
  duplicate, or the default statement account is missing.
- Do not ask for the original bank statement or document unless sanitized
  diagnostics cannot identify the failure class.

### Missing evidence or tax readiness is blocked

- Ask for the readiness screen, entity/year/canton, and open blocker codes.
- Request the support bundle when audit and issue history are relevant.
- Treat missing values as missing, not zero.
- Route any disputed amount to deterministic fact explanation and supporting
  evidence review instead of manual arithmetic.

### Copilot or agent answer is disputed

- Ask for the answer card source references, task/proposal IDs, and support
  bundle.
- Check whether the answer cited transactions, documents, requirements, issues,
  or tax facts.
- If provenance is absent, treat the answer as unsupported and escalate as an
  AI-safety issue.
- Do not accept an agent suggestion as confirmed ledger or tax state.

### Backup or restore issue

- Ask whether the backup integrity check passed before restore.
- Request sanitized diagnostics from the source workspace and restored
  workspace if both can open.
- Escalate as P0 if a previously checked backup cannot restore or the restored
  workspace reports manifest/hash mismatches.

### Release artifact issue

- Ask for the exact release ZIP filename, version/build, and checksum.
- Verify that the artifact came from the documented release channel.
- Re-run `scripts/verify-release-artifact.sh` on the ZIP before changing the
  release status.
- Escalate as P0 if Gatekeeper, notarization, or checksum verification fails
  for a published release artifact.

## Escalation And Issue Hand-off

Every escalated issue should include:

- severity
- app version/build
- macOS version
- support artifact type received
- reproduction steps
- expected result
- observed result
- whether a checked backup exists
- privacy review status of attached artifacts
- open questions

Security, privacy, tax-rule, data-integrity, release-signing, and AI-safety
issues should be labeled explicitly so they can be reviewed against the risk
register.

## Release Support Gate

Before marking support documentation complete for a release candidate:

- `docs/support.md` exists and matches current app support surfaces.
- `scripts/verify-support-docs.sh` passes.
- `scripts/verify-readiness.sh` includes the support-doc verifier.
- Release notes link support to sanitized diagnostics and support bundles.
- The support process still defaults to local-first, evidence-preserving
  troubleshooting.
