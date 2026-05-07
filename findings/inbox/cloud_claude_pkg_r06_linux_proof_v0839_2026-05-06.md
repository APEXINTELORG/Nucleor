# Cloud Claude PKG-1 + R06 Native Linux Proof — v0839 (2026-05-06)

Lane: `fix/cloud-claude-pkg-r06-linux-proof-v0839`

## 1. Branch / base

| Item | Value |
| --- | --- |
| Branch | `fix/cloud-claude-pkg-r06-linux-proof-v0839` |
| Cloud branch HEAD | `988f4b92` (`fix: PKG-1 signed publish + R06 rust_bridge ownership on native Linux (v0839)`) |
| Cloud branch base | `origin/main` @ `a437f6a6` |
| Cloud branch merge-base | `a437f6a6` |
| Main integration base | `origin/main` @ `3bbd8159` after Helper2 RFC-0063 Wave 2 |

Main-agent integration note: the cloud branch was older-based and was
cherry-picked onto current main. During integration, the new
`#link_windows` / `#link_posix` directive support was also mirrored into
`compiler/nucleor_tools_suite.nr` so s1 and tools-suite do not diverge on
the new directive syntax.

## 2. Host

```
uname -a:  Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
shell:     /bin/bash (POSIX)
pwsh:      /usr/bin/pwsh — PowerShell 7.4.6 (installed during this lane via Microsoft .deb)
ssh-keygen:/usr/bin/ssh-keygen — OpenSSH_9.6p1 Ubuntu-3ubuntu13.16, OpenSSL 3.0.13 30 Jan 2024
            (installed during this lane via apt)
clang:     /usr/bin/clang — Ubuntu clang version 18.1.3 (1ubuntu1)
distro:    Ubuntu 24.04.4 LTS (Noble Numbat) amd64
```

`./bin/nucleor --version` → `nucleor 0.8.323 (self-hosted, llvm backend)`.

The bin/nucleor used for proofs is a fresh stage-2 Linux build linked from
`target/nucleor_s2.ll` produced by the stage-1 seed binary, after applying
the patches described in §5. The seed fixed-point check fails (seed
sha256 `e0c534ad…` vs stage-2 `00f9be19…`) — the seed was already stale
on `origin/main` before this lane, and patching the compiler made the
delta larger; refreshing the seed is out of scope for this lane and
requires a Windows host today.

`pwsh` and `ssh-keygen` are not preinstalled in the cloud Linux image.
Both were installed inline (apt for openssh-client, Microsoft .deb for
PowerShell 7.4.6); record this as an environment prerequisite for any
future PKG-1 lane on the same image.

## 3. Scope A — PKG-1 signed publish proof

Per the dispatch command shape; all paths absolute.

### 3.1 Build tools-suite

```
./bin/nucleor build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache
→ target/nucleor_tools (1438720 bytes; staged also at bin/nucleor_tools so
  the in-process tool-suite resolver finds it via exe_dir).
```

### 3.2 Dry-run signed publish (must produce no artifacts)

Command:

```
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
  --registry "$registry" --dry-run --sign --key-id throwaway-ci
```

Stdout summary:

```
publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created
manifest: tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml
package: foo
version: 0.1.0
registry: /tmp/tmp.xfYSl6wZwi/nucleor-registry
signature_target: …/foo/0.1.0/Nucleor.publish.signature.json
signing_key_id: throwaway-ci
```

`find "$registry" -type f` after dry-run: **(empty)** — the registry dir
itself is not even created. Specifically:

```
test ! -e "$registry/foo/0.1.0/Nucleor.publish.signature.json" → OK no signature file
```

### 3.3 Keygen (pwsh)

```
pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen throwaway-ci --json
```

JSON:

```json
{
  "policy_root": "/tmp/tmp.xfYSl6wZwi/nucleor-keys",
  "key_id": "throwaway-ci",
  "signing_key": "/tmp/tmp.xfYSl6wZwi/nucleor-keys/release-signing-keys/throwaway-ci",
  "trusted_key": "/tmp/tmp.xfYSl6wZwi/nucleor-keys/trusted-release-keys/throwaway-ci.pub",
  "public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILVuD2SxR5Rcr6R0qHARF8+U9t8DmoKGD1uhZTbrAzqG nucleor-release:throwaway-ci"
}
```

Files at `$NUCLEOR_POLICY_ROOT`:

```
release-signing-keys/throwaway-ci
release-signing-keys/throwaway-ci.pub
trusted-release-keys/throwaway-ci.pub
```

### 3.4 Signed publish (must write signature)

```
./bin/nucleor publish tests/fixtures/t14_registry/foo/0.1.0/Nucleor.toml \
  --registry "$registry" --sign --key-id throwaway-ci
→ published: /tmp/tmp.xfYSl6wZwi/nucleor-registry/foo/0.1.0
```

Artifacts under `$registry/foo/0.1.0/`:

```
Nucleor.toml
Nucleor.exports.rs
Nucleor.exports.h
Nucleor.publish.json
main.nr
Nucleor.publish.signature.json   ← signed
Nucleor.package.sha256
Nucleor.exports.json
```

Required-artifact assertions (from dispatch):

```
test -f Nucleor.toml                      → OK
test -f Nucleor.publish.json              → OK
test -f Nucleor.package.sha256            → OK
test -f Nucleor.publish.signature.json    → OK
```

Signature payload (excerpt) — `signing.algorithm = "ssh-ed25519"`,
`mode = "openssh-y-sign"`, `key_id = "throwaway-ci"`, embedded
`-----BEGIN SSH SIGNATURE-----` block over
`metadata_sha256=582b1350…`, `checksum_sha256=45d192c7…`,
`exports_sha256=feb71f40…`.

### 3.5 Package preflight

```
pwsh -NoProfile -File tools/native_release.ps1 -Root . package-sign-preflight \
  "$registry/foo/0.1.0" throwaway-ci --json
```

```json
{
  "package_dir": "/tmp/tmp.xfYSl6wZwi/nucleor-registry/foo/0.1.0",
  "package": "foo", "version": "0.1.0",
  "metadata_path":   "…/foo/0.1.0/Nucleor.publish.json",
  "checksum_path":   "…/foo/0.1.0/Nucleor.package.sha256",
  "exports_manifest_path": "…/foo/0.1.0/Nucleor.exports.json",
  "exports_manifest_present": true,
  "key_id": "throwaway-ci", "key_id_source": "requested",
  "private_key_path": "…/nucleor-keys/release-signing-keys/throwaway-ci",
  "public_key_path":  "…/nucleor-keys/release-signing-keys/throwaway-ci.pub",
  "key_present": true,
  "signature_path": "…/foo/0.1.0/Nucleor.publish.signature.json",
  "signature_exists": true,
  "would_overwrite_signature": true,
  "would_write_signature": false,
  "status": "ready", "failure_reason": null
}
```

### 3.6 Package verify

```
pwsh -NoProfile -File tools/native_release.ps1 -Root . package-verify \
  "$registry/foo/0.1.0" --json
```

```json
{
  "package_dir": "/tmp/tmp.xfYSl6wZwi/nucleor-registry/foo/0.1.0",
  "package": "foo", "version": "0.1.0",
  "key_id": "throwaway-ci",
  "signature_file": "Nucleor.publish.signature.json",
  "signed": true, "algorithm": "ssh-ed25519"
}
```

PKG-1 signed publish on native Linux: **closed**.

## 4. Scope B — R06 POSIX `rust_bridge` ownership proof

All commands run from a clean `bin/nucleor` (post-fix), with cargo
1.94.1 at `/root/.cargo/bin/cargo` (Linux native — not Windows
cargo.exe).

### 4.1 Doctor

`bash tools/check_rust_bridge_ownership.sh --doctor` →

```
doctor cargo: OK - /root/.cargo/bin/cargo
doctor bridge-crate: OK - /home/user/Nucleor/stdlib/rods/rust_bridge
doctor release-artifact: OK - not present yet; normal run will attempt cargo build --release; expected …/libnucleor_rust_bridge.a
doctor compiler-binary: OK - /home/user/Nucleor/bin/nucleor
doctor focused-fixture:string-free: OK
doctor fixture-buildable: OK
doctor result: ready for POSIX rust_bridge ownership harness
```

`--doctor --json` shape (key fields):

```json
{
  "schema_version": 1,
  "host_family": "posix",
  "cargo": {"present": true, "native": true, "path": "/root/.cargo/bin/cargo"},
  "bridge_artifact": {"present": true, "path": ".../libnucleor_rust_bridge.a"},
  "compiler": {"present": true, "path": "/home/user/Nucleor/bin/nucleor"},
  "result_status": "ready"
}
```

`host_family=posix`, `cargo.native=true`, `compiler.path` resolves to a
Linux ELF — the doctor would reject Windows cargo.exe / Windows .lib
artifacts / Windows nucleor.exe; on this lane it accepted only POSIX
evidence.

### 4.2 Self-test

```
self-test selector:string-free: OK
self-test selector:hash: OK
self-test selector:all: OK
self-test selector:invalid: OK
self-test json:required-keys: OK
self-test fail-closed:cargo: OK
self-test json:fail-closed:cargo: OK
self-test fail-closed:compiler: OK
self-test json:fail-closed:compiler: OK
self-test fail-closed:bridge-artifact: OK
self-test json:fail-closed:bridge-artifact: OK
self-test result: passed
```

### 4.3 Repeat fixture (text and JSON)

`bash tools/check_rust_bridge_ownership.sh --fixture all --iterations 20` →

```
[cargo build --release: OK; libnucleor_rust_bridge.a 26597926 bytes]
building focused fixture: tests/features/rust_bridge_string_free_smoke.nr → OK
building focused fixture: tests/features/rust_bridge_hash_determinism_smoke.nr → OK
OK rust_bridge ownership: fixture_selector=all iterations=20 \
  fixture_executions=40 fixture_alloc_free_cycles=2040 \
  bridge_artifact=/home/user/Nucleor/stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a \
  executable=/home/user/Nucleor/target/_rust_bridge_ownership_check
```

`--fixture all --iterations 5 --json` summary:

```json
{
  "schema_version": 1, "host_family": "posix", "mode": "run",
  "fixture_selector": "all", "iterations_requested": 5,
  "fixture_executions_completed": 10,
  "cargo": {"present": true, "native": true, "path": "/root/.cargo/bin/cargo"},
  "bridge_artifact": {"present": true, "path": ".../libnucleor_rust_bridge.a"},
  "compiler": {"present": true, "path": "/home/user/Nucleor/bin/nucleor"},
  "result_status": "passed", "failure_reason": ""
}
```

Artifact assertion (from dispatch):

```
test -f stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a → OK
ls -la …/libnucleor_rust_bridge.a   → 26,597,926 bytes
```

R06 native Linux ownership harness: **closed**.

## 5. Blockers found and patched on this branch

Two POSIX gaps blocked the dispatched commands. Both fixes are small,
local, and conditional on host kind so Windows behaviour is preserved.

### 5.1 PKG-1 — `path_shell_native` rewrote `/` → `\` on POSIX

Symptom: `./bin/nucleor publish … --sign` reported
`ERROR: native package signing failed: …/foo/0.1.0`. The metadata,
checksum and exports files were written, but the signature step
short-circuited.

Diagnosis: `invoke_native_package_sign` builds the pwsh command via
`path_shell_native`, which unconditionally rewrote forward slashes to
backslashes. On Linux:

* the pwsh script path turned into `tools\native_release.ps1`,
* the package-root argument turned into `\tmp\…\foo\0.1.0`,
* the redirection target turned into `.nuc_cache\package_sign_<ms>.json`.

`/bin/sh` happily redirected to a literal file named
`.nuc_cache\package_sign_<ms>.json` (created in the repo root, not in
`.nuc_cache/`), so the lane was silently dropping the diagnostic
output. Inspecting that file revealed the real failure inside the pwsh
script:

```
Exception: …/native_release.ps1:1135
  missing package signing input: /home/user/Nucleor/tmp/tmp.xfYSl6wZwi/nucleor-registry/foo/0.1.0/Nucleor.publish.json
```

`Join-Path -Root /home/user/Nucleor` had glued the backslash-encoded
relative-looking path onto the repo root instead of using it as
absolute.

Fix (`compiler/nucleor_tools_suite.nr`): make
`path_shell_native` a no-op on POSIX hosts; only rewrite on Windows.
Manual `pwsh -NoProfile -File tools/native_release.ps1 … package-sign`
already worked, confirming the script itself was correct. After the
fix, the in-compiler invocation produces:

```
{ ..., "signed": true }
```

and the signature file appears at the correct registry path.

### 5.2 R06 — `stdlib/rods/rust.nr` linked Windows-only system libs unconditionally

Symptom: building `tests/features/rust_bridge_string_free_smoke.nr` on
Linux failed with:

```
/usr/bin/ld: cannot find -lws2_32: No such file or directory
/usr/bin/ld: cannot find -luserenv: No such file or directory
/usr/bin/ld: cannot find -lntdll:   No such file or directory
/usr/bin/ld: cannot find -lbcrypt:  No such file or directory
clang: error: linker command failed with exit code 1
```

`ws2_32 / userenv / ntdll / bcrypt` are pulled in by the Rust Windows
std for `rust_bridge`; POSIX targets resolve those symbols via
`libc / libpthread` already linked by the Nucleor runtime.

Fix (two-part, both small):

* `compiler/nucleor_s1_compiler.nr` and `compiler/nucleor_tools_suite.nr`
  — extend `extract_directives` to recognise `#link_windows "<lib>"`
  and `#link_posix "<lib>"`. They emit `-l<lib>` only when the host kind
  matches; the existing unqualified `#link "<lib>"` is unchanged.
* `stdlib/rods/rust.nr` — convert the four Windows system libs from
  `#link` to `#link_windows`. `nucleor_rust_bridge` itself stays
  cross-platform (`#link`), as does the `#libpath`.

Both edits are guarded by `host_is_windows()`, so a Windows host still
emits `-lws2_32 …` and remains untouched.

### 5.3 `tools/check_compiler_drift.sh` preferred a non-runnable Windows binary on Linux

While running the dispatch's "compiler/tooling source changes →
`tools/check_compiler_drift.sh`" follow-up, the gate failed with:

```
FAIL: promoted compiler binary version is stale:
  expected: nucleor 0.8.323 ...
  actual:
```

Cause: the script preferred `bin/nucleor.exe` (a checked-in Windows
PE32+ binary that carries the +x bit) over `bin/nucleor` whenever the
`.exe` exists. On Linux the kernel rejects it
(`cannot execute binary file: Exec format error`), the captured
`--version` is empty, and the gate fails — but the underlying compiler
is fine. Patched the binary picker in `tools/check_compiler_drift.sh`
to prefer the native binary on `Linux/Darwin/{Free,Open,Net}BSD` and
keep `.exe` first on other platforms.

### 5.4 Generated drift artifact refresh

After the compiler-source change, `tools/audit_dup_fns_report.csv`
went stale (the s1 fn count moved by +0/-0 net, but a couple of
duplicate-fn detections shifted). Regenerated via:

```
./bin/nucleor build tools/audit_dup_fns.nr -o audit_dup_fns
./target/audit_dup_fns
```

This is the regenerator the drift gate already prescribes; no manual
edits to the CSV.

## 6. Validation after the fixes

```
git diff --check                        → clean
bash tools/check_compiler_drift.sh      → exit 0, all OK lines
                                          (pre-existing parser-divergence
                                          WARNs unchanged — RFC-0063
                                          Phase 2.0 territory, not this
                                          lane)
pwsh -NoProfile -File tools/native_release.ps1 -Root . keygen drift-check --json
                                        → JSON OK; key files written
```

PKG-1 and R06 commands re-run end-to-end after the fixes, all green
(see §3 / §4).

Main-agent Windows integration validation after cherry-picking onto
current main:

```
.\bin\nucleor.exe build compiler\nucleor_s1_compiler.nr -o _cloud_pkg_s1_check --no-cache --no-link
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o nucleor_tools --no-cache
bash tools/check_compiler_drift.sh
bash tools/check_rod_void_abi.sh
git diff --check
```

Results: both compiler sources built; drift passed with only the known
RFC-0063 parser-divergence warnings; rod void ABI passed; whitespace
check passed. The integration pass also ran a Windows package-signing
smoke with `cloud-pkg-review`: dry-run signed publish wrote no
signature, real signed publish wrote `Nucleor.publish.signature.json`,
`package-sign-preflight` returned `status: ready`, and `package-verify`
returned `signed: true`, `algorithm: ssh-ed25519`.

## 7. Changed files

```
M  compiler/nucleor_s1_compiler.nr      — #link_windows / #link_posix directives
M  compiler/nucleor_tools_suite.nr      — host-aware path_shell_native and #link_windows/#link_posix mirror
M  stdlib/rods/rust.nr                  — Windows system libs → #link_windows
M  tools/check_compiler_drift.sh        — host-aware bin/nucleor vs nucleor.exe pick
M  tools/audit_dup_fns_report.csv       — regenerated
A  findings/inbox/cloud_claude_pkg_r06_linux_proof_v0839_2026-05-06.md (this report)
A  findings/inbox/cloud_claude_pkg_r06_linux_proof_v0839_scope_b/{doctor,doctor_postfix,self_test,fixture_all_20,fixture_all_5}.{txt,json}
```

`bin/nucleor`, `bin/nucleor_tools`, and `target/nucleor_s2.ll` were
rebuilt locally during the lane but are not committed (gitignored).

## 8. Blockers

None remaining for the dispatched scope. `pwsh` and `ssh-keygen` had
to be installed inline on the cloud Linux image; if that image is
re-used for future PKG-1 lanes, pre-install both (`apt install
openssh-client` and the Microsoft `powershell_*.deb`) to skip the
provisioning step.

## 9. Main-line follow-ups

* **Drift**: not needed — `tools/check_compiler_drift.sh` is green
  after this lane (§6).
* **Perf**: not exercised here; out of dispatch scope.
* **Self-host**: the seed fixed-point check still fails on POSIX
  (`bootstrap_linux.sh` without `--seed-only`). The seed
  `bootstrap/nucleor_s1_seed.ll` is older than `compiler/*` by enough
  that this lane's compiler edits could not have introduced it; the
  pre-existing gap is inherited from `origin/main`. Seed refresh
  belongs on a Windows host today, per `bootstrap/README.md`.
* **Full verify**: not run, per the dispatch's "Do not run full
  verify by default" instruction.
