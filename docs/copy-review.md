# Copy Review

Status: Baseline complete for the v0.1 local pilot.
Last reviewed: 2026-05-30.

This file records the release-critical copy rules for AlpenLedger. It covers
error alerts, recovery suggestions, first-run/help copy, privacy/support copy,
and release-note limitations. It is not a claim that the app is fully
localized.

## Principles

- State what happened before suggesting what to do next.
- Keep alert titles short and specific.
- Give every recoverable domain error an actionable recovery suggestion.
- Do not imply that a filing is submitted or complete unless the filing state
  proves it.
- Do not ask users to send raw workspace databases, source documents,
  encryption keys, or unsanitized finance exports to support.
- Distinguish prepared, draft, reviewed, locked, filed, blocked, and missing
  states in user-facing copy.

## Reviewed Surfaces

| Surface | Rule | Evidence |
|---|---|---|
| Domain errors | Every `DomainError` has a short title, localized description, and recovery suggestion. | `domainErrorCopyIsSpecificAndActionableForReleaseReview` |
| App alerts | Domain errors render title, message, and recovery separately. | `testDomainErrorsProduceActionableAlertPresentation` |
| Help Center | First-run, evidence, tax-readiness, and support sections are available without opening a workspace. | `testHelpCenterAndFirstRunOnboardingAreAvailableWithoutWorkspace` |
| Support copy | Support runbooks require sanitized diagnostics/support bundles and forbid raw source documents in normal support intake. | `docs/support.md`, `scripts/verify-support-docs.sh` |
| Release notes | The release draft states known limitations and does not claim signed/notarized release evidence before it exists. | `docs/release-notes/v0.1.0.md`, `scripts/verify-release-notes.sh` |

## Domain Error Copy Rules

Release-reviewed `DomainError` copy must satisfy all of these constraints:

- title is present, specific, and no longer than 52 characters,
- title is not a generic "Error",
- description is present and matches the localized description,
- description ends with a sentence terminator,
- recovery suggestion is present and actionable,
- recovery suggestion does not use vague fallbacks such as "try again later",
- recovery suggestion does not send users to support before a concrete local
  remediation step.

These rules are enforced by
`domainErrorCopyIsSpecificAndActionableForReleaseReview`.

## Help Copy Rules

Help and onboarding copy must:

- reinforce local-first operation,
- direct document/evidence work into review queues,
- distinguish prepared/readiness states from filed/submitted states,
- direct support exports through sanitized diagnostics or support bundles,
- avoid legal or tax certainty beyond deterministic rule-engine evidence.

The current Help Center baseline is intentionally compact and work-oriented.
Expanded help content can be added after the same rules are covered by tests or
copy-review evidence.

## Localization Strategy Boundary

The v0.1 pilot UI is English-first. `docs/localization.md` defines the
localization framework and keeps German/French language availability planned
until translation, glossary, and layout evidence exist.

Before marking localization complete:

- add a real localization resource strategy for app and package UI strings,
- define term glossaries for English, German, and French Swiss finance/tax
  language,
- run pseudo-localization or equivalent layout review for core screens,
- verify English, German, and French release notes/support copy boundaries,
- keep app-store, help, error, and support copy aligned with the same terms.

## Release Gate

Run this gate before release-candidate packaging:

```sh
scripts/verify-copy-review.sh
```

The gate verifies this document, the checklist evidence, release-note anchors,
and focused domain-error copy tests.
