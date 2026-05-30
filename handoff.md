# AlpenLedger Handoff

Date: 2026-05-30
Repository: `/Users/nationalbank/GitHub/alpenledger`
Branch at handoff time: `main`
Remote: `salexandr0s` (`https://github.com/salexandr0s/alpenledger.git` for push)

## Active Goal

Make AlpenLedger production-ready by auditing the current codebase, identifying
readiness gaps, implementing prioritized fixes, and verifying the app against
functionality, safety, tests, documentation, and release criteria.

Do not mark this goal complete until current evidence proves every release
requirement. The default readiness gate is strong, but true production release
still needs release-machine UI evidence, Apple Developer signing/notary
credentials, and a signed/notarized/stapled artifact.

## Product Constraints To Preserve

- AlpenLedger is a local-first Swiss finance manager.
- Agents should observe, classify, suggest, explain, and prepare proposals.
- Agents must not silently mutate confirmed ledger/tax data.
- Numeric tax/accounting facts must come from deterministic services, not model
  inference.
- Agent tools must be typed, scoped, provenance-returning, and approval-aware.
- Local-only mode must not silently send user data off-device.

## Current Verification Baseline

The following commands were run successfully on 2026-05-30 before this handoff:

- `/bin/bash scripts/verify-readiness.sh`
- `/bin/bash scripts/verify-fresh-checkout.sh`
- `/bin/bash scripts/verify-project-structure.sh`
- `/bin/bash scripts/verify-source-style.sh`
- `/bin/bash scripts/verify-doc-alignment.sh`
- `/bin/bash scripts/verify-release-packaging.sh`
- `/bin/bash scripts/verify-release-notes.sh`
- `/bin/bash scripts/verify-ui-smoke-evidence.sh --allow-missing-evidence`
- `/bin/bash scripts/verify-release-evidence.sh --allow-missing-evidence`

Default readiness currently passes with:

- 247 Swift package tests.
- 53 app CI unit tests.
- UI automation skipped by default.

`RUN_UI_TESTS=full scripts/verify-readiness.sh` has not been proven on the
current machine after the latest UI additions because local macOS automation
mode/Accessibility state blocked UI test execution before test bodies ran.

## Important Recent Hardening

- `scripts/verify-fresh-checkout.sh` creates a disposable source copy from
  tracked and non-ignored untracked files, regenerates the Xcode project with
  XcodeGen 2.45.2, and runs the readiness gate from that copy.
- `scripts/verify-project-structure.sh` now statically checks package-test
  `@testable import AL...` usage against declared `Package.swift` test-target
  dependencies. This fixed cold-build-only drift in:
  - `ALDocumentsTests` requiring `ALEvidence` and `ALImports`
  - `ALStorageTests` requiring `ALAudit`
  - `ALImportsTests` requiring `ALDomain`
- `scripts/verify-grdb-vendor.sh` supports `--offline`, and the default
  readiness gate uses offline GRDB vendor invariants.
- `scripts/verify-source-style.sh` works in disposable source copies without
  `.git` and rejects Bash 4-only features in release scripts so macOS system
  Bash 3.2 remains supported.
- `scripts/verify-ui-smoke-evidence.sh` now rejects placeholder refs, absolute
  paths, URLs, missing supporting files, refs outside `docs/release-evidence/`,
  and refs pointing back to the UI smoke manifest itself.
- `scripts/verify-release-evidence.sh` now applies the same archived-ref checks,
  rejects placeholder manifest commands, requires actual release artifact paths,
  and verifies `artifact.sha256` against the ZIP and checksum sidecar.

## Remaining Release Blockers

These are still real blockers for a production-ready release:

- Full UI automation and manual smoke evidence on a machine with macOS
  Accessibility/UI scripting enabled.
- Strict UI smoke evidence JSON:
  `docs/release-evidence/ui-smoke-v0.1.0.json`.
- Strict final release evidence JSON:
  `docs/release-evidence/release-v0.1.0.json`.
- Strict release preflight with real Apple Developer credentials:
  - `ALPENLEDGER_DEVELOPER_ID_APPLICATION`
  - `ALPENLEDGER_RELEASE_TEAM_ID`
  - `ALPENLEDGER_NOTARY_KEYCHAIN_PROFILE` or App Store Connect API key trio
- Signed, notarized, stapled release artifact verified by:
  `scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip`.
- Strict release notes, after final release evidence exists:
  `scripts/verify-release-notes.sh --strict`.
- A true clean-machine/no-cache bootstrap remains unproven. The disposable
  fresh-checkout verifier has passed with local SwiftPM cache available.

## Next-Machine Checklist

1. Clone or pull the pushed branch.
2. Confirm toolchain:
   - Xcode 26.3 build 17C529
   - Swift 6.2.4
   - XcodeGen 2.45.2
3. Run:
   ```sh
   scripts/verify-readiness.sh
   scripts/verify-fresh-checkout.sh
   ```
4. Enable macOS Accessibility/UI scripting for the runner, then run:
   ```sh
   RUN_UI_TESTS=full scripts/verify-readiness.sh
   ```
5. Capture sanitized UI smoke evidence under `docs/release-evidence/` and
   validate:
   ```sh
   scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json
   ```
6. Configure Apple Developer ID/notary credentials and run:
   ```sh
   scripts/verify-release-preflight.sh
   ```
7. Build/archive/sign/notarize/staple the app, package it, and verify:
   ```sh
   scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases
   scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip
   ```
8. Capture sanitized release command logs/artifacts under
   `docs/release-evidence/`, then validate:
   ```sh
   scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v0.1.0.json
   scripts/verify-release-notes.sh --strict
   ```

## Suggested Continuation Prompt

Continue the active goal to make AlpenLedger production-ready. Use the current
worktree as authoritative. Start by reading `handoff.md`,
`docs/readiness-audit-2026-05-29.md`, `docs/checklist.md`, and `docs/release.md`.
Then run the default readiness and fresh-checkout gates, inspect any failures,
and continue closing production-readiness gaps. Do not mark the goal complete
until full UI automation/manual smoke evidence, strict release evidence, strict
Developer ID/notary preflight, and signed/notarized/stapled artifact
verification are all present and passing.
