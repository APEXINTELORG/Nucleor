# Release Signing

Nucleor uses two different signing layers:

- Windows release artifacts are signed with DigiCert KeyLocker / Software Trust
  Manager through the manual GitHub Actions workflow
  `.github/workflows/sign-windows-release.yml`.
- Nucleor package metadata is signed by `tools/native_release.ps1` using the
  repository's package-signing format. That is separate from Windows
  Authenticode signing.

## Windows Authenticode Signing

The signing workflow is manual (`workflow_dispatch`) and is scoped to the
public repository only:

```text
APEXINTELORG/Nucleor
```

It does not run in the archive repository and does not run on every push. This
keeps release signing deliberate and avoids spending hosted runner minutes on
ordinary development pushes.

The workflow signs staged copies of these committed Windows artifacts and
uploads the signed copies as a workflow artifact:

```text
bin/nucleor.exe
bin/nucleor-lsp.exe
bin/nucleor.exe.bootstrap
```

Signed binaries are not committed back to Git. Authenticode signatures include
timestamp data, so the signed files are release artifacts, not reproducible
source-tree content.

## GitHub Configuration

Create a protected GitHub environment named `release-signing` on
`APEXINTELORG/Nucleor`. Store the DigiCert values as environment secrets so
GitHub redacts them from public workflow logs. `SM_HOST` and `SM_KEYPAIR_ALIAS`
may also be repository variables for private testing, but release use should
prefer environment secrets.

Required values:

```text
SM_HOST
SM_API_KEY
SM_CLIENT_CERT_FILE_B64
SM_CLIENT_CERT_PASSWORD
SM_KEYPAIR_ALIAS
```

`SM_HOST` is the DigiCert ONE client-auth host for the account, for example
`https://clientauth.one.digicert.com`. `SM_CLIENT_CERT_FILE_B64` is the base64
contents of the `.p12` client authentication certificate generated for the
service user. `SM_KEYPAIR_ALIAS` is the KeyLocker / Software Trust Manager
keypair alias that owns the Windows code-signing certificate.

The DigiCert service user must be allowed to sign with the selected keypair.

## Operator Runbook

1. Confirm the release commit already passed the normal verifier gates.
2. Open GitHub Actions in `APEXINTELORG/Nucleor`.
3. Run `Sign Windows Release Artifacts`.
4. Use `main` or the release tag as the `ref` input.
5. Download the `nucleor-windows-signed-<ref>` artifact.
6. Verify the uploaded `windows-authenticode.json` reports `Valid` for every
   binary.
7. Attach the signed binaries and `windows-artifacts.sha256` to the release.

Local artifact sanity check before a signing run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\check_windows_release_artifacts.ps1
```

Post-signature verification uses:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\check_windows_release_artifacts.ps1 -RequireSigned
```
