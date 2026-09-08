# Building a release

Versions follow YYYY.M.PATCH; CFBundleVersion is an independently increasing build number.

CI tests pull requests without signing secrets. Version tags trigger tests, a universal Release build,
Developer ID signing, Apple notarization of the app and DMG, stapling, SHA-256 generation and artifact
attestation. The workflow publishes a Pre-release. After downloading and testing that exact app,
run Promote Release with its tag and confirmation PROMOTE. Promotion preserves the existing bytes.
No Sparkle feed or in-app updater is included in the current product.

## Public documentation

README describes the current product, installation, permissions, recovery and source builds.
CHANGELOG uses one exact `## YYYY.M.PATCH` heading per version and contains only changes and guidance
that matter to users. Use `###` headings within a version entry.

CI validates the current entry with `scripts/extract-release-notes.py`. The release workflow uses only
that entry for its release notes. A missing, duplicate or empty entry stops publication; the workflow
never falls back to the entire changelog. Review the extracted text before creating a version tag:

```sh
python3 scripts/extract-release-notes.py 2026.9.1 --output /tmp/ululawake-release-notes.md
```

Before creating a tag, check that README matches the app's behavior and that the changelog and
rendered release notes explain the version's changes, installation requirements, limitations and
recovery instructions.

## Production environment

Restrict production deployments to release tags (v*) and main for manual promotion. Configure an owner
reviewer. Store these five values as production environment secrets, never source files:

- MACOS_CERTIFICATE_P12_BASE64
- MACOS_CERTIFICATE_PASSWORD
- APPLE_NOTARY_KEY_P8_BASE64
- APPLE_NOTARY_KEY_ID
- APPLE_NOTARY_ISSUER_ID

The P12 must contain one Developer ID Application identity and its private key. The Apple API key must
be authorized for notarization. Credentials in another repository cannot be read back through GitHub.
The signing script imports them into a temporary keychain and deletes its temporary files on exit.

## Validation

Run `python3 -m unittest discover -s scripts/tests`, `./scripts/test.sh` and `./scripts/build-release.sh`.
The unit-test scheme sets ULULAWAKE_UNIT_TESTS=1. In Debug only, the hosted app skips permission requests,
startup sleep reconciliation and quit handling; controller tests exercise these behaviours with mocks.
Release builds have no test-mode bypass.

Before promoting, download the GitHub DMG and verify installation, first-run permissions, keep-awake,
normal restore, timed restore, lid-open restore, exit, revoke authorization and uninstall on a real Mac.
Do not substitute local-build tests for this final-package acceptance.

If a release already exists, do not overwrite its assets. Diagnose the result and recover the existing
release or create a new version. Retain successful releases and their source snapshots.
