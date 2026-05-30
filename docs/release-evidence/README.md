# Release Evidence

Archive release-candidate evidence records here when they are safe to keep in
the repository. Do not commit screenshots, logs, or notes that contain personal
finance data, real customer document text, raw workspace databases, or private
Apple signing credentials.

The UI smoke evidence file for v0.1.0 is expected at:

```sh
docs/release-evidence/ui-smoke-v0.1.0.json
```

Validate it with:

```sh
scripts/verify-ui-smoke-evidence.sh --evidence docs/release-evidence/ui-smoke-v0.1.0.json
```

The final release evidence manifest for v0.1.0 is expected at:

```sh
docs/release-evidence/release-v0.1.0.json
```

Validate it with:

```sh
scripts/verify-release-evidence.sh --evidence docs/release-evidence/release-v0.1.0.json
```

The manifest must reference archived logs or artifacts for the default
readiness run, fresh-checkout run, full UI readiness run, UI smoke evidence,
strict release notes, support/copy/localization checks, strict release
preflight, release packaging, and final artifact verification.

All `artifactRefs` in strict evidence JSON must be repo-relative paths under
`docs/release-evidence/` and must already exist when the verifier runs. Use
sanitized command logs, screenshots, review notes, result summaries, or other
release-machine artifacts that are safe to archive. Do not use absolute paths,
URLs, `path/to/...` placeholders, or references to the evidence manifest itself.

The final release manifest must also use the actual packaged ZIP and checksum
paths in `artifact.zipPath`, `artifact.checksumPath`, `artifact.verifiedBy`,
and the `verifyReleaseArtifact` evidence command. The strict verifier checks
that those files exist on the release machine and that the recorded SHA-256
matches the ZIP and checksum sidecar.
