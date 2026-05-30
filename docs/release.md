# Release Readiness

This file records the current release-signing and notarization path. It is not
evidence that a signed production artifact has already shipped.

## Status

- The app target enables hardened runtime through `project.yml`, which is
  required for Developer ID notarization.
- Release names use `v<CFBundleShortVersionString>`, where
  `CFBundleShortVersionString` follows `MAJOR.MINOR.PATCH` and
  `CFBundleVersion` is the monotonically increasing build number recorded in
  `App/AlpenLedgerApp/Info.plist`.
- Each app marketing version must have a matching
  `docs/release-notes/v<version>.md` draft. `scripts/verify-release-notes.sh`
  checks that the current draft exists, matches the bundle version/build, and
  contains the required user-facing sections and release evidence commands.
- `scripts/verify-release-preflight.sh` verifies release configuration,
  packaging prerequisites, version metadata, Apple notarization tooling, and
  the required signing/notary credential environment.
- `scripts/package-release.sh` creates the versioned release ZIP and checksum
  from a prepared `AlpenLedgerApp.app` bundle, verifies the staged artifacts,
  then publishes them to the release directory by default.
- `scripts/verify-release-packaging.sh` keeps the packaging command, dry-run
  metadata, and documentation references covered in the default readiness gate.
- `scripts/verify-ui-smoke-evidence.sh` validates the release-candidate UI
  smoke evidence record. The default readiness gate allows the evidence file to
  be missing, but release candidates must provide the strict evidence JSON.
- `scripts/verify-release-evidence.sh` validates the final release evidence
  manifest tying command logs, UI evidence, strict preflight, packaging, and
  artifact verification to the current app version/build. The default readiness
  gate allows this manifest to be missing until a release candidate exists. In
  strict mode, evidence refs must be existing repo-relative files under
  `docs/release-evidence/`, and final artifact paths/checksums must point to
  real release-machine files rather than placeholders.
- `docs/support.md` defines the private support-intake, sanitized diagnostics,
  backup-safety, and triage baseline. `scripts/verify-support-docs.sh` keeps
  those support anchors in the default readiness gate.
- `docs/copy-review.md` defines the error/help copy review baseline and
  English-first localization boundary. `scripts/verify-copy-review.sh` keeps
  those copy anchors and focused domain-error copy tests in the default
  readiness gate.
- `docs/localization.md` and `config/localization-catalog.json` define the
  English-first localization framework, planned German/French boundaries, and
  glossary-readiness rules. `scripts/verify-localization.sh` keeps those
  language-claim anchors in the default readiness gate.
- `scripts/verify-release-artifact.sh` verifies the final release ZIP after a
  signed app has been notarized and stapled, including bundle metadata,
  Developer ID signature, hardened runtime, trusted timestamp, Gatekeeper
  assessment, stapled ticket validation, matching checksum sidecar validation,
  and SHA-256 checksum output.
- CI runs the preflight in configuration-only mode with
  `--allow-missing-secrets`.
- The production gate remains open until strict preflight passes with real
  Apple Developer credentials and a signed, notarized, stapled artifact is
  archived as release evidence.

## Required Secrets

Set these values in the local release shell or the protected release CI
environment:

- `ALPENLEDGER_DEVELOPER_ID_APPLICATION`: full Developer ID Application signing
  identity name as shown by `security find-identity -v -p codesigning`.
- `ALPENLEDGER_RELEASE_TEAM_ID`: Apple Developer Team ID.
- `ALPENLEDGER_NOTARY_KEYCHAIN_PROFILE`: notarytool keychain profile name.

Instead of `ALPENLEDGER_NOTARY_KEYCHAIN_PROFILE`, the release environment may
provide the App Store Connect API key trio:

- `ALPENLEDGER_NOTARY_KEY_ID`
- `ALPENLEDGER_NOTARY_ISSUER_ID`
- `ALPENLEDGER_NOTARY_KEY_PATH`

## Preflight

Release-note structure, suitable for CI and local readiness checks:

```sh
scripts/verify-release-notes.sh
```

Strict release-note evidence, required before producing a release candidate:

```sh
scripts/verify-release-notes.sh --strict
```

Strict UI smoke evidence, required after full UI automation and the manual
window-size/motion pass:

```sh
scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json
```

Strict release evidence manifest, required before publishing a release
candidate:

```sh
scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v0.1.0.json
```

Configuration-only preflight, suitable for CI without private credentials:

```sh
scripts/verify-release-preflight.sh --allow-missing-secrets
```

Strict preflight, required before producing a release candidate:

```sh
scripts/verify-release-preflight.sh
```

The strict mode fails if the Developer ID identity, Team ID, or notary
credentials are missing.

## Packaging

After archiving, signing, notarizing, and stapling the app bundle, create the
versioned ZIP and checksum with:

```sh
scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases
```

The packaging script names the ZIP as
`AlpenLedgerApp-v<CFBundleShortVersionString>-build<CFBundleVersion>.zip`,
checks bundle metadata against the current checkout, writes a `.sha256` file,
and runs `scripts/verify-release-artifact.sh` by default. It stages the ZIP and
adjacent `.sha256` sidecar in a temporary directory first, then publishes them
to the output directory only after final artifact verification passes.

For local packaging rehearsals only, use `--skip-final-verification`. A ZIP
created with that flag is not release evidence until the final artifact
verifier passes against the ZIP and adjacent `.sha256` sidecar.

To verify the packaging command and documentation references without private
Apple credentials:

```sh
scripts/verify-release-packaging.sh
```

## Artifact Verification

After packaging the signed, notarized, and stapled `.app`, verify the final
release payload:

```sh
scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip
```

The verifier compares the packaged app's bundle identifier, marketing version,
and build number against the current checkout/tag. It also requires a Developer
ID Application signature, hardened runtime, a trusted signing timestamp,
Gatekeeper acceptance, a valid stapled notarization ticket, and prints the
final ZIP checksum to record with the release. The verifier also requires the
adjacent `.sha256` sidecar to contain exactly one checksum line matching the ZIP
basename and digest.

## Release Gate

Before marking release signing/notarization complete, archive the exact commands
and outputs that prove:

- `scripts/verify-readiness.sh` passed.
- `RUN_UI_TESTS=full scripts/verify-readiness.sh` passed on a machine with
  macOS automation permission. The readiness script runs
  `scripts/verify-ui-automation-preflight.sh` first so missing Accessibility UI
  scripting fails before the UI test launch timeout.
- `scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json`
  passed for the full UI automation and manual smoke evidence record.
- `scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v0.1.0.json`
  passed for the final manifest that links command logs, UI evidence, strict
  preflight, package creation, and artifact verification.
- `scripts/verify-release-notes.sh --strict` passed for the final release-note
  draft.
- `scripts/verify-support-docs.sh` passed for the support runbook and release
  support anchors in `docs/support.md`.
- `scripts/verify-copy-review.sh` passed for error/help copy, release-note
  limitations, and English-first localization boundaries.
- `scripts/verify-localization.sh` passed for the English-first localization
  framework and planned German/French boundaries.
- `scripts/verify-release-preflight.sh` passed in strict mode.
- The app was signed with Developer ID Application identity.
- The submitted artifact was accepted by Apple notarization.
- The notarization ticket was stapled and validated.
- `scripts/package-release.sh --app path/to/AlpenLedgerApp.app --output-dir dist/releases`
  created the versioned release ZIP and checksum.
- `scripts/verify-release-artifact.sh path/to/AlpenLedgerApp.zip` passed and
  recorded the final artifact checksum, checksum sidecar, and version/build
  number.

Strict release evidence must use actual release-machine paths for the packaged
app and ZIP entries in the JSON manifest. The placeholder commands in this guide
show the required shape only; release-candidate evidence must not contain
`path/to/...` placeholders.
