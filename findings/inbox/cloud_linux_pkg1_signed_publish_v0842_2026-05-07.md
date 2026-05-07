# Cloud Linux PKG-1 Signed Publish Proof — v0842 (2026-05-07)

Lane: `fix/cloud-linux-pkg1-signed-publish-v0842`
Dispatch: `docs/rfcs/CLOUD_LINUX_PKG_R06_DISPATCH_v0842_2026-05-07.md` — Queue 1
Audience: cloud Linux agent only. No WSL / Wine / `.exe` / Python.

## 1. Branch / base

| field           | value                                                            |
| --------------- | ---------------------------------------------------------------- |
| branch          | `fix/cloud-linux-pkg1-signed-publish-v0842`                      |
| base            | `origin/main`                                                    |
| HEAD            | `4fa86e02 docs: dispatch v0842 parallel agent queues`            |
| merge-base      | `4fa86e027a08f5e83dbc6e931dd42e1234894a21` (= HEAD; clean off main) |
| working tree    | clean — **no source files modified**, no compiler/runtime/CLI patches |

`git status --short --branch` after the proof:

```
## fix/cloud-linux-pkg1-signed-publish-v0842...origin/main
```

## 2. Host

```
$ uname -a
Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```

True native Linux x86_64 (kernel 6.18.5). `/proc` present. No WSL / Wine /
copied Windows artifacts used as POSIX evidence.

### Tool inventory

| tool          | path                              | version / note                                                |
| ------------- | --------------------------------- | ------------------------------------------------------------- |
| `clang`       | `/usr/bin/clang`                  | Ubuntu clang version 18.1.3 (target `x86_64-pc-linux-gnu`)    |
| `ssh-keygen`  | `/usr/bin/ssh-keygen`             | OpenSSH_9.6p1 Ubuntu-3ubuntu13.16, OpenSSL 3.0.13 — installed inline via `apt-get install -y openssh-client` |
| `pwsh`        | `/usr/bin/pwsh`                   | PowerShell 7.6.1 — installed inline via Microsoft `packages-microsoft-prod.deb` + `apt-get install -y powershell` |
| `bash`        | `/usr/bin/bash`                   | GNU bash 5.x                                                  |
| `bin/nucleor` | `/home/user/Nucleor/bin/nucleor`  | nucleor 0.8.323 (self-hosted, llvm backend); ELF 64-bit LSB pie, x86-64, GNU/Linux 3.2.0 |
| `bin/nucleor_tools` | `/home/user/Nucleor/bin/nucleor_tools` | tools-suite ELF (1438720 B), staged from `target/nucleor_tools` |

`pwsh` and `ssh-keygen` are not preinstalled on the cloud Linux image
(same prereq gap noted by `cloud_claude_pkg_r06_linux_proof_v0839`). Both
were installed inline; record this as an environment prerequisite for any
future PKG-1 lane on the same image.

### `bin/nucleor` provenance

`bin/nucleor` was produced on this host from `bootstrap/nucleor_s1_seed.ll`
via `tools/bootstrap_linux.sh --seed-only`. The shipped Windows binaries in
`bin/` (`nucleor.exe`, `nucleor-lsp.exe`) are **not** used.

```
$ time bash tools/bootstrap_linux.sh --seed-only
==> stage-1 link: clang bootstrap/nucleor_s1_seed.ll + runtime → bin/nucleor
    /usr/bin/ld: warning: -z stacksize=16777216 ignored
    stage-1 binary: 2185608 bytes
    stage-1 --version: nucleor 0.8.323 (self-hosted, llvm backend)
==> --seed-only: stopping after stage-1 (verify.sh handles self-rebuild)
real    0m1.788s

$ file bin/nucleor
bin/nucleor: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV),
  dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2,
  BuildID[sha1]=2addc7af6e9186e22362d972e08d4db0f67833c5,
  for GNU/Linux 3.2.0, not stripped

$ ./bin/nucleor --version
nucleor 0.8.323 (self-hosted, llvm backend)
```

### `bin/nucleor_tools` provenance

`./bin/nucleor publish` requires the tools-suite binary; the bootstrap
seed builds only the primary compiler, so `nucleor_tools` was built on
this host:

```
$ time ./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
  source: compiler/nucleor_tools_suite.nr (1123543 bytes)
  mode: fast (ownership + type)
  mode: llvm-only (--no-link)
cache: disabled (sha=none, size 0 MB)
  functions: 715
  strings: 5637
  optimized: 1363 instructions
  DCE: 39 of 715 fns elided as unreachable
  emitted: target/nucleor_tools.ll (7001969 bytes)
  native link: skipped (use target/nucleor_tools only after a linked build)
/usr/bin/ld: warning: -z stacksize=16777216 ignored
  compiled: target/nucleor_tools
real    0m3.512s

$ cp target/nucleor_tools bin/nucleor_tools
$ ls -la bin/nucleor_tools
-rwxr-xr-x 1 root root 1438720 May  7 02:25 bin/nucleor_tools
```

Without this stage, `nuc publish` aborts with:

```
ERROR: cannot find required tools-suite binary: nucleor_tools
       rebuild with: nuc build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
```

This matches Helper2 R06 dispatch behaviour and is by design — the
tools-suite is `nuc explain` / `nuc audit` / `nuc check` / `nuc publish`
host. Documented as a prereq in `bin/README.md` (R13-D1 Phase 1, multi-binary
policy).

## 3. PKG-1 — Native signed publish proof

All commands relative to repo root. `$REG = /tmp/nucleor-pkg1-v0842-registry`,
`$NUCLEOR_POLICY_ROOT = /tmp/nucleor-pkg1-v0842-keys`.

### 3.1 Dispatch dry-run (must produce no artifacts)

Exact command from the dispatch:

```
$ rm -rf /tmp/nucleor-pkg1-v0842-registry
$ ./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry /tmp/nucleor-pkg1-v0842-registry --dry-run
publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created
manifest: tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml
package: foo
version: 0.1.0
registry: /tmp/nucleor-pkg1-v0842-registry
registry_package_dir: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0
export_manifest_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.exports.json
metadata_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.publish.json
checksum_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.package.sha256
signature_target: (not requested)
signing_key_id: (none)
exit 0

$ find /tmp/nucleor-pkg1-v0842-registry 2>&1
bfs: error: /tmp/nucleor-pkg1-v0842-registry: No such file or directory.
```

Pass: rc=0, prints all `*_target` paths it would write, registry directory
not even created.

### 3.2 Keygen (throwaway ed25519 via pwsh wrapper)

```
$ export NUCLEOR_POLICY_ROOT=/tmp/nucleor-pkg1-v0842-keys
$ rm -rf "$NUCLEOR_POLICY_ROOT"
$ pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json
{
  "policy_root": "/tmp/nucleor-pkg1-v0842-keys",
  "key_id": "throwaway-ci",
  "signing_key": "/tmp/nucleor-pkg1-v0842-keys/release-signing-keys/throwaway-ci",
  "trusted_key": "/tmp/nucleor-pkg1-v0842-keys/trusted-release-keys/throwaway-ci.pub",
  "public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF8x8op7kD4wlicSdzls+xSTQ0cjuKkcVxeTjRNXJMyk nucleor-release:throwaway-ci"
}
exit 0

$ find /tmp/nucleor-pkg1-v0842-keys
/tmp/nucleor-pkg1-v0842-keys
/tmp/nucleor-pkg1-v0842-keys/release-signing-keys
/tmp/nucleor-pkg1-v0842-keys/trusted-release-keys
/tmp/nucleor-pkg1-v0842-keys/release-signing-keys/throwaway-ci
/tmp/nucleor-pkg1-v0842-keys/release-signing-keys/throwaway-ci.pub
/tmp/nucleor-pkg1-v0842-keys/trusted-release-keys/throwaway-ci.pub
```

ssh-keygen produces a real OpenSSH ed25519 keypair under
`release-signing-keys/`, and a parallel pubkey under `trusted-release-keys/`.

### 3.3 Dry-run signed publish (must still produce no artifacts)

```
$ rm -rf /tmp/nucleor-pkg1-v0842-registry
$ ./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry /tmp/nucleor-pkg1-v0842-registry --sign --key-id throwaway-ci --dry-run
publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created
manifest: tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml
package: foo
version: 0.1.0
registry: /tmp/nucleor-pkg1-v0842-registry
registry_package_dir: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0
export_manifest_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.exports.json
metadata_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.publish.json
checksum_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.package.sha256
signature_target: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.publish.signature.json
signing_key_id: throwaway-ci
exit 0

$ find /tmp/nucleor-pkg1-v0842-registry 2>&1
bfs: error: /tmp/nucleor-pkg1-v0842-registry: No such file or directory.
```

`--sign --key-id throwaway-ci --dry-run` correctly elevates `signature_target`
to a concrete path and `signing_key_id` to `throwaway-ci` while still
writing nothing.

### 3.4 Real signed publish (must write all artifacts incl. signature)

```
$ rm -rf /tmp/nucleor-pkg1-v0842-registry
$ ./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry /tmp/nucleor-pkg1-v0842-registry --sign --key-id throwaway-ci
published: /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0
exit 0

$ find /tmp/nucleor-pkg1-v0842-registry -type f | sort
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.exports.h
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.exports.json
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.exports.rs
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.package.sha256
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.publish.json
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.publish.signature.json
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/Nucleor.toml
/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0/main.nr
```

Required-artifact assertions:

```
OK   Nucleor.toml
OK   Nucleor.publish.json
OK   Nucleor.package.sha256
OK   Nucleor.publish.signature.json
OK   Nucleor.exports.json
OK   Nucleor.exports.h
OK   Nucleor.exports.rs
OK   main.nr
```

### 3.5 Signature payload (excerpt)

`Nucleor.publish.signature.json`:

```json
{
  "schema_version": 1,
  "type": "package_signature",
  "package": { "name": "foo", "version": "0.1.0" },
  "files": {
    "metadata_file": "Nucleor.publish.json",
    "metadata_sha256": "23d455cfffbb896dcf746911614eec5af68f6809d9eede3fa0b51921c3732a83",
    "checksum_file":  "Nucleor.package.sha256",
    "checksum_sha256": "45d192c75780ec9ca54aaa42e13c143e4579e61cb86b9abbf0bffde4c0c51649",
    "exports_manifest": "Nucleor.exports.json",
    "exports_sha256":   "feb71f40b945c96f511e36baf1e1309906aa7adae94757d605bea1e8adc63c28"
  },
  "signing": {
    "algorithm": "ssh-ed25519",
    "mode": "openssh-y-sign",
    "key_id": "throwaway-ci",
    "signed_at_unix_s": 1778120730,
    "signature": "-----BEGIN SSH SIGNATURE-----\nU1NIU0lHAAAAAQ...K\n-----END SSH SIGNATURE-----\n"
  }
}
```

`Nucleor.publish.json` records the signing reference:

```json
{
  "schema_version": 1,
  "package": { "name": "foo", "version": "0.1.0", "entry": "main.nr" },
  "published_at_unix_s": 463,
  "checksum": "ca943af4",
  "signing": {
    "algorithm": "ssh-ed25519",
    "key_id": "throwaway-ci",
    "signature_file": "Nucleor.publish.signature.json",
    "mode": "openssh-y-sign"
  },
  "exports": { "present": true, "count": 1, ... }
}
```

`Nucleor.package.sha256` = `sha256 = "ca943af4"` (matches `publish.json.checksum`).

The `metadata_sha256` differs from the v0839 lane (`582b1350…` → `23d455cf…`)
because `publish.json` embeds the new `exports` block; the `checksum_sha256`
(`45d192c7…`) and `exports_sha256` (`feb71f40…`) are byte-stable across
v0839 and v0842, confirming the package payload itself is unchanged.

### 3.6 Package preflight (pwsh)

```
$ pwsh -NoProfile -File tools/native_release.ps1 -Root . \
    package-sign-preflight /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0 throwaway-ci --json
{
  "package_dir": "/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0",
  "package": "foo",
  "version": "0.1.0",
  "metadata_path": ".../Nucleor.publish.json",
  "checksum_path": ".../Nucleor.package.sha256",
  "exports_manifest": "Nucleor.exports.json",
  "exports_manifest_path": ".../Nucleor.exports.json",
  "exports_manifest_present": true,
  "key_id": "throwaway-ci",
  "key_id_source": "requested",
  "private_key_path": "/tmp/nucleor-pkg1-v0842-keys/release-signing-keys/throwaway-ci",
  "public_key_path":  "/tmp/nucleor-pkg1-v0842-keys/release-signing-keys/throwaway-ci.pub",
  "key_present": true,
  "signature_path": ".../Nucleor.publish.signature.json",
  "signature_exists": true,
  "would_overwrite_signature": true,
  "would_write_signature": false,
  "status": "ready",
  "failure_reason": null
}
exit 0
```

### 3.7 Package verify (pwsh)

```
$ pwsh -NoProfile -File tools/native_release.ps1 -Root . \
    package-verify /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0 --json
{
  "package_dir": "/tmp/nucleor-pkg1-v0842-registry/foo/0.1.0",
  "package": "foo",
  "version": "0.1.0",
  "key_id": "throwaway-ci",
  "signature_file": "Nucleor.publish.signature.json",
  "signed": true,
  "algorithm": "ssh-ed25519"
}
exit 0
```

PKG-1 signed publish on native Linux (kernel 6.18.5, clang 18.1.3,
OpenSSH 9.6p1, PowerShell 7.6.1, nucleor 0.8.323): **CLOSED on `origin/main`
@ `4fa86e02`**.

## 4. Patches

**None.** No edits to compiler, runtime, CLI, tools-suite, bootstrap,
fixtures, scripts, or docs were necessary. Working tree at end of lane:

```
$ git status --short --branch
## fix/cloud-linux-pkg1-signed-publish-v0842...origin/main
$ git diff --stat
(empty)
```

The dispatch's "smallest patch" deliverable is therefore the empty patch.

## 5. Residual blockers

None for PKG-1 publish itself on this host. Two **environmental**
prerequisites remain non-trivial for fresh cloud Linux runners:

1. **`pwsh` is not in default Ubuntu apt indexes.** Must install via
   Microsoft's `packages-microsoft-prod.deb` (one-time per image). Suggested
   doc location: `bin/README.md` "Linux prereqs" section, or a new
   `docs/POSIX_RELEASE_PREREQS.md`. Out of scope for this lane (touching
   release docs is not a Queue 1 deliverable).
2. **`ssh-keygen` (openssh-client) is not preinstalled.** `apt-get install -y
   openssh-client` is sufficient. Same recommended doc location.
3. **`bin/nucleor_tools`** (Linux ELF) is not committed; must be built
   from source after bootstrap. The error message on missing-tools-suite
   is already actionable (`rebuild with: nuc build compiler/nucleor_tools_suite.nr
   -o nucleor_tools --no-cache`), so no patch is needed; this is just a
   cost-of-bootstrap note for downstream lanes.

Apart from those env prereqs, no compiler, signing, or registry blockers
remain. The dispatch's stated goal — "Close PKG-1 with a native Linux
transcript for `nuc publish --sign` against a throwaway registry/key" —
is met.

## 5.1 Main integration note

The proof branch was report-only and based on `4fa86e02`. It was reviewed and
cherry-picked after Helper2 Wave 6 moved `origin/main` to `57e36eb9`. No source
files, generated binaries, bootstrap seed, scripts, or package fixtures were
changed. Integration validation for this findings-only merge was `git diff
--check` on the added report.

## 6. Lane scope hygiene

- No edits to Windows / compiler semantics, R05, ROBO-7, RFC-0063, laws,
  units, or quantum lanes.
- No Python helpers used.
- No WSL, Wine, copied Windows `.exe` artifacts used as POSIX evidence.
- Did not touch Queue 2 (R06 POSIX rust_bridge proof) — per dispatch, that
  runs on its own branch (`fix/cloud-linux-r06-rust-bridge-proof-v0842`)
  off a fresh fetch of `origin/main`.

## 7. Reproducer

```bash
# Prereqs (cloud Linux image, root):
apt-get install -y openssh-client
wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/pmp.deb
dpkg -i /tmp/pmp.deb && apt-get update && apt-get install -y powershell

# Branch:
git fetch origin
git checkout -B fix/cloud-linux-pkg1-signed-publish-v0842 origin/main

# Bootstrap native ELF nucleor + tools-suite:
bash tools/bootstrap_linux.sh --seed-only
./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
cp target/nucleor_tools bin/nucleor_tools

# Throwaway registry + keys:
export NUCLEOR_POLICY_ROOT=/tmp/nucleor-pkg1-v0842-keys
rm -rf "$NUCLEOR_POLICY_ROOT" /tmp/nucleor-pkg1-v0842-registry

# Dry-run (no artifacts):
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry /tmp/nucleor-pkg1-v0842-registry --dry-run

# Keygen + signed publish:
pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
    --registry /tmp/nucleor-pkg1-v0842-registry --sign --key-id throwaway-ci

# Verify:
pwsh -NoProfile -File tools/native_release.ps1 -Root . \
    package-sign-preflight /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0 throwaway-ci --json
pwsh -NoProfile -File tools/native_release.ps1 -Root . \
    package-verify /tmp/nucleor-pkg1-v0842-registry/foo/0.1.0 --json
```

End-to-end wall time on this host: ~12 s (excludes apt installs).
