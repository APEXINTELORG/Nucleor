# Release Signing

Nucleor uses two signing layers:

- Windows release binaries use user-mode Authenticode signing through SSL.com
  eSigner in the manual GitHub Actions workflow
  `.github/workflows/sign-windows-release.yml`.
- Package metadata uses `tools/native_release.ps1` and Nucleor's package
  signing format. That is separate from Windows Authenticode signing.

Kernel-mode signing is not required for the current release artifacts. It would
only apply if Nucleor shipped Windows drivers or other kernel-loaded
components.

## Windows Authenticode

The workflow is manual (`workflow_dispatch`) and scoped to:

```text
APEXINTELORG/Nucleor
```

It does not run in the archive repository and does not run on every push. That
keeps signing deliberate and avoids unnecessary hosted-runner cost.

The workflow signs staged copies of:

```text
bin/nucleor.exe
bin/nucleor-lsp.exe
bin/nucleor.exe.bootstrap
```

Signed binaries are release artifacts. They are not committed back to Git.

## GitHub Configuration

Create a protected GitHub environment named `release-signing` on
`APEXINTELORG/Nucleor`. Store the SSL.com values as environment secrets:

```text
SSL_COM_USERNAME
SSL_COM_PASSWORD
SSL_COM_CREDENTIAL_ID
SSL_COM_TOTP_SECRET
```

Optional environment variable:

```text
SSL_COM_ENVIRONMENT_NAME
```

Use `PROD` for the production SSL.com account. The workflow defaults to `PROD`
when the variable is unset.

The SSL.com account must be allowed to sign with the selected credential ID.
The workflow pins `SSLcom/esigner-codesign` to a specific commit rather than a
floating branch.

## Release Package

Until SSL.com/Azure verification completes, the release-candidate path can
produce unsigned Windows binaries with a clear signing-pending disclaimer. That
candidate path is for staging and review, not the final signed Windows trust
path.

The signing workflow produces:

```text
nucleor-v<version>-windows-x86_64.zip
nucleor-v<version>-windows-x86_64.zip.sha256
windows-artifacts.sha256
windows-authenticode.json
windows-release-summary.md
```

The GitHub source archive for the same tag remains the source package. The
Windows zip is the binary overlay for that source archive.

## Operator Runbook

1. Confirm the release commit has passed the normal verifier gates.
2. Confirm `release-signing` has the SSL.com secrets above.
3. Open GitHub Actions in `APEXINTELORG/Nucleor`.
4. Run `Sign Windows Release Artifacts`.
5. Use `main` or the release tag as `ref`.
6. Use the release version without a leading `v` as `version`.
7. Download the uploaded signed package artifact.
8. Confirm `windows-authenticode.json` reports `Valid` for every binary.
9. Attach the zip, checksums, Authenticode JSON, verifier summary, and source
   archive to the GitHub release.

Local unsigned sanity check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\check_windows_release_artifacts.ps1
```

Local package dry run without requiring signatures:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\make_windows_release_package.ps1 -Version 1.1.0
```

Full unsigned release-candidate package:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\make_release_candidate.ps1 -Version 1.1.0
```

That writes source archives, Windows binary overlay, SHA256 manifests, and a
release-notes draft under `target\release`. The generated notes include:

```text
Windows Authenticode signing is awaiting certificate/vendor verification completion.
```

Post-signature verification:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\check_windows_release_artifacts.ps1 -RequireSigned -ArtifactRoot target\release-signing\signed -ArtifactPaths nucleor.exe,nucleor-lsp.exe,nucleor.exe.bootstrap
```
