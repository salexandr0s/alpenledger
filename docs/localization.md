# Localization

Status: English-first framework baseline complete for the v0.1 local pilot.
Last reviewed: 2026-05-30.

This file defines how AlpenLedger tracks language readiness. It does not claim
that German or French localization is complete.

## Current Boundary

- Default language: English (`en`).
- App development region: English (`CFBundleDevelopmentRegion=en`).
- Package default localization: English (`defaultLocalization: "en"`).
- v0.1 release claim: English-first pilot.
- German (`de`) and French (`fr`) are planned readiness languages, not shipped
  localizations.

## Source Of Truth

`config/localization-catalog.json` records:

- default language and development region,
- release boundary,
- language readiness status,
- required Swiss finance/tax glossary terms.

`LocalizationPolicy` in `ALDomain` mirrors the release claim in code so tests
can prevent accidental German or French availability claims before translation
and layout evidence exist.

## Resource Layout

App-owned strings live under:

```text
App/AlpenLedgerApp/Resources/<language>.lproj/Localizable.strings
```

Package-owned UI strings should use Swift Package localization resources under
the owning target when they are migrated from literals:

```text
Packages/AlpenLedgerKit/Sources/<Target>/Resources/<language>.lproj/Localizable.strings
```

New user-facing strings should be written so they can move into localized
resources without changing domain behavior. Financial and tax calculations must
stay independent of display language.

## Release Rules

- Do not claim German or French availability until their status is
  `release-ready` in the localization catalog and code policy.
- Do not mark a language release-ready until app/package UI strings, help copy,
  error/recovery copy, release notes, and support copy have been reviewed in
  that language.
- Keep "prepared", "filed", "locked", "missing", "draft", "reviewed", and
  "submitted" terms consistent across UI, support, and release copy.
- Keep privacy wording consistent with `docs/ai-privacy-controls.md` and
  `docs/support.md`.
- Use pseudo-localization or equivalent layout review before adding a new
  release-ready language.

## Minimum Readiness Evidence

Before changing a planned language to release-ready, capture:

- translation review for the glossary terms in
  `config/localization-catalog.json`,
- screenshots or UI automation evidence for the core workspace, import, Inbox,
  Tax Studio, Settings, Help Center, and alert flows,
- copy review for error and recovery text,
- release-note and support-runbook review in the target language,
- default readiness and focused localization verification output.

## Verification

Run:

```sh
scripts/verify-localization.sh
```

The verifier checks the app/package localization baseline, localization catalog,
English resource file, checklist evidence, release-note boundary, and focused
`LocalizationPolicy` tests.
