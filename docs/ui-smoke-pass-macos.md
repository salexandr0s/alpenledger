# UI Smoke Pass: macOS Native Polish

Use this checklist after any shell, Ledger, Documents, Overview, or design-system pass.

## Setup

- Build and run a Debug app build.
- Run the pass twice:
  - default macOS motion settings
  - macOS `System Settings > Accessibility > Display > Reduce Motion` enabled
- Check each scenario at these window sizes:
  - `1200x720`
  - `1440x900`
  - `1720x1100`

## Fixture Setup

- Create a fresh workspace.
- Import the built-in sample CSV and sample PDF from Overview.
- In a Debug build launched with `ALPENLEDGER_FEATURE_FLAGS=qa-validation-fixtures`,
  use the File menu command `Import QA Validation Fixtures` to load the larger
  CSV and mixed long-name documents set.

## First Run and Shell

- Verify the workspace chooser still shows `Create Workspace`, `Open Existing Workspace`, recent workspaces, and local-first reassurance copy.
- Verify a recently opened workspace appears in the chooser and can be reopened successfully after relaunch.
- Verify the sidebar remains unclipped and readable at all three window sizes.
- Verify keyboard navigation works in the sidebar with arrow keys and section changes update the detail pane correctly.
- Verify the `Go` menu still navigates between Overview, Inbox, Ledger, Documents, Tax Studio, and Settings.
- Verify `View > Toggle Inspector` with `Option-Command-0` only affects Ledger/Documents and updates its title correctly.

## Ledger

- Verify the transaction table receives focus when Ledger becomes active and arrow-key selection updates the inspector without clicking a row first.
- Verify tab order is stable: sidebar, accounts list, transaction table, inspector action.
- Verify the table columns remain readable at all three widths:
  - date stays compact
  - counterparty truncates cleanly
  - amount stays right-aligned with monospaced digits
  - review badge does not clip
- Verify the inspector can be hidden and shown from both the toolbar and the View menu.
- Verify inspector visibility persists after app relaunch for the current workspace.
- Verify empty states:
  - no accounts
  - account with no transactions
  - filtered-empty via Ledger scope
  - no transaction selected

## Documents

- Verify the documents table receives focus when Documents becomes active and arrow-key selection updates preview and inspector without pointer input.
- Verify search works from the toolbar search field and scope changes use native search scopes.
- Verify filtered-empty states show the right corrective actions:
  - `Clear Search`
  - `Show All Types`
  - `Import Document`
- Verify text fixtures show `Preview Unavailable` rather than a broken preview.
- Verify the documents inspector can be hidden and shown from both the toolbar and the View menu.
- Verify inspector visibility persists after app relaunch for the current workspace.
- Verify long filenames truncate cleanly and do not force unstable row heights.

## Overview and General Motion

- Verify Overview metric changes animate with restrained numeric transitions rather than large movement.
- Verify sidebar and inspector transitions fall back to opacity-only behavior when Reduce Motion is enabled.
- Verify there is no clipped content in Overview, Ledger, or Documents at `1200x720`.

## Exit Criteria

- No clipped or overlapping chrome at the three target window sizes.
- Ledger and Documents are fully usable with keyboard-only selection and tab navigation.
- Inspector visibility persists across relaunch per workspace section.
- Default-motion and Reduce Motion runs both feel native and stable.

## Evidence Record

For release candidates, archive a JSON evidence record at
`docs/release-evidence/ui-smoke-v0.1.0.json` and verify it with:

```sh
scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json
```

The record must include:

- `schemaVersion`: `1`
- `verifiedAt`: ISO-8601 timestamp
- `verifier`: reviewer or release-machine identifier
- `app.version`, `app.build`, and `app.gitRevision`
- `automation.command`: `RUN_UI_TESTS=full scripts/verify-readiness.sh`
- `automation.status`: `passed`
- `automation.artifactRefs`: repo-relative archived `xcresult`, summary, or log
  references under `docs/release-evidence/`
- `manualPasses`: one `default` and one `reduceMotion` pass, both marked
  `passed`, each covering `1200x720`, `1440x900`, and `1720x1100`
- `manualPasses[].scenarios`: `firstRunAndShell`, `ledger`, `documents`, and
  `overviewAndMotion`
- `manualPasses[].artifactRefs`: repo-relative archived screenshot or
  review-note references under `docs/release-evidence/`
- `exitCriteria`: all checklist exit criteria marked `true`
- `blockers`: empty array

The strict verifier rejects absolute paths, URLs, `path/to/...` placeholders,
missing files, and refs that point back to the UI smoke evidence JSON instead of
supporting evidence.
