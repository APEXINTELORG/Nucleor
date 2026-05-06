# Helper2 PKG-1 release dry-run/preflight closure pack v0831

## Branch and base

- Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`
- Branch: `fix/helper2-pkg1-release-dryrun-preflight-v0831`
- Implementation/report commit: `c30eadae`
- Branch head: reported in the final handoff after the report SHA-record commit
- Base ref: `origin/fix/main-qm7-surface-code-v0827`
- Merge-base with base ref: `7c8c0b0ca64256d73cdddeaa1327992a0c59f3a4`
- `origin/main` at setup: `5ec86d7e4d965359348d33826553659157d16016`
- Local `origin/claude/check-commit-history-UMuPK` after fetch: `1940b977dbfead5657b1f79bc7021a7a81b7c3ea`

## Completed scopes

| Scope | Status | Evidence |
|---|---|---|
| W: native_release package-sign dry-run/preflight | Complete | Added `tools/native_release.ps1 package-sign-preflight <dir> [key-id] [--json]`. It reads package metadata/checksum/export paths, reports key/signature readiness, and does not create keys, write signatures, copy packages, or mutate registries. |
| X: tools-suite `nuc publish --dry-run` dispatch prep | Complete | Added `--dry-run` in `compiler/nucleor_tools_suite.nr::run_publish_command` after manifest, dependency-lock, dependency-graph, and existing-package checks but before copy/checksum/metadata/signing writes. No `bin/` or `bootstrap/` promotion was made. |
| Y: PKG-1 native Linux transcript checklist | Complete | Added operator commands to `tools/VERIFY_TIMING_RECIPE.md` for bootstrap, self-host drift compare, POSIX perf, publish dry-run, signed publish against a throwaway registry/key, preflight, and signature verify. |
| Z: release blocker reduction matrix | Complete | Updated this report and `docs/rfcs/v1_PUNCHLIST.md`; PKG-1 remains open only for native Linux signed-publish evidence. |

## Validation transcript

Branch setup:

```text
git fetch origin --prune
git switch -c fix/helper2-pkg1-release-dryrun-preflight-v0831 origin/fix/main-qm7-surface-code-v0827
git merge-base HEAD origin/fix/main-qm7-surface-code-v0827
7c8c0b0ca64256d73cdddeaa1327992a0c59f3a4
```

PowerShell parser and help:

```text
[scriptblock]::Create((Get-Content -Raw -LiteralPath 'tools\native_release.ps1')) | Out-Null
PASS

pwsh -NoProfile -File tools\native_release.ps1 -Help
Usage: nuc release [keygen [key-id]|sign-bundle <dir>|verify-bundle <dir>|package-sign <dir> [key-id]|package-sign-preflight <dir> [key-id]|package-verify <dir>|export-key <key-id> <path>|trust-key <key-id> <path>] [--json]
  package-sign-preflight <dir> [key-id]  Report package signing inputs without creating keys or signatures
```

Scratch package-sign preflight with an empty policy root:

```text
package               : helper2-smoke
version               : 0.0.1
key_id                : helper2-missing
key_present           : False
would_write_signature : False
status                : blocked
failure_reason        : release signing key 'helper2-missing' is missing at C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_empty_policy\release-signing-keys\helper2-missing
```

Tools-suite source validation:

```text
.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o _helper2_tools_suite_dryrun_check --no-link --no-cache
emitted: target/_helper2_tools_suite_dryrun_check.ll
native link: skipped

.\bin\nucleor.exe build compiler\nucleor_tools_suite.nr -o _helper2_tools_suite_dryrun_check --no-cache
compiled: target\_helper2_tools_suite_dryrun_check.exe
```

`nuc publish --dry-run --sign` smoke with an existing tiny fixture and temp registry:

```text
target\_helper2_tools_suite_dryrun_check.exe publish tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml --registry C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry --dry-run --sign --key-id helper2-key
publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created
manifest: tests\fixtures\t14_registry\foo\0.1.0\Nucleor.toml
package: foo
version: 0.1.0
registry: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry
registry_package_dir: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry/foo/0.1.0
export_manifest_target: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry/foo/0.1.0/Nucleor.exports.json
metadata_target: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry/foo/0.1.0/Nucleor.publish.json
checksum_target: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry/foo/0.1.0/Nucleor.package.sha256
signature_target: C:\Users\JoeWe\AppData\Local\Temp\nucleor_helper2_publish_dryrun_registry/foo/0.1.0/Nucleor.publish.signature.json
signing_key_id: helper2-key
registry_exists_after_dry_run=False
```

Syntax and requested audit commands:

```text
bash -n tools/verify.sh
PASS

bash -n tools/verify_fast.sh
PASS

[scriptblock]::Create((Get-Content -Raw tools\verify.ps1)) | Out-Null
PASS

rg -n "publish|sign|package|dry.?run|checksum|sha256|release" tools docs bootstrap README.md
PASS

rg -n "publish|dry.?run|sign|registry|package" compiler/nucleor_tools_suite.nr tools docs tests
PASS

rg -n "bootstrap_linux|publish|sign|package|registry|POSIX|perf|native Linux" docs tools findings compiler
PASS

rg -n "PKG-1|POSIX perf|rust bridge|TOOLCHAIN-PY|deadline|WCET|ROBO-7|effect-row|Phase 2b" docs tools findings compiler
PASS

git diff --check
PASS
```

## Release blocker matrix

| Blocker | Current evidence | Next file/function surface | Validation command | Platform | Owner |
|---|---|---|---|---|---|
| PKG-1 dry-run/preflight | This branch adds non-mutating `package-sign-preflight` and `publish --dry-run` with scratch validation. | Land branch, then use `compiler/nucleor_tools_suite.nr::run_publish_command` and `tools/native_release.ps1::Get-PackageSignaturePreflight` as the review surfaces. | `pwsh -NoProfile -File tools\native_release.ps1 -Root . package-sign-preflight <pkg> --json`; `nuc publish <manifest> --registry <temp> --dry-run --sign --key-id <id>` | Windows and native POSIX | helper2 then main integration |
| PKG-1 native Linux signed publish transcript | Not claimed from this Windows host. Checklist is documented. | Native Linux runner using `bin/nucleor`, throwaway registry, throwaway key, then `package-verify`. | Commands in `tools/VERIFY_TIMING_RECIPE.md` PKG-1 section. | Native Linux only | main/operator |
| POSIX perf native transcript | Queue 4 evidence remains fail-closed on WSL/Windows interop; no new native Linux host was available here. | `tools/check_perf_regression.sh` on native Linux with native ELF `bin/nucleor`. | `bash tools/check_perf_regression.sh --doctor`; `bash tools/check_perf_regression.sh --json` | Native Linux only | main/operator |
| rust bridge ownership evidence | Windows harness and JSON/self-test lanes are documented; POSIX native run still requires native cargo/compiler/artifact. | `tools/check_rust_bridge_ownership.ps1`, `tools/check_rust_bridge_ownership.sh`, Rust bridge crate. | `pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Fixture all -Iterations 20`; POSIX equivalent on native host. | Windows plus native POSIX | helper/main split |
| TOOLCHAIN-PY keep-closed audit | Queue 4 closed product-path `python -c` use; this branch adds no Python helpers. | Keep `verify-reproducible` native compare paths closed. | `rg -n "python|py -|python -c|\\.py\\b|filecmp|json.tool" compiler tools docs nuc_router.ps1 stdlib tests README.md` | Cross-platform | main |
| RT deadline/WCET | Still open for numeric deadline backing and WCET table/pass. | `compiler/nucleor_s1_compiler.nr` deadline/checker surfaces, not touched here. | Focused deadline fixtures plus perf budget once implemented. | Main compiler lane | main |
| ROBO-7 frame typing | Still open for compile-time frame-tag consistency. | Robotics/frame type checker and stdlib robotics rods, not touched here. | Future frame-typing positive/negative fixtures. | Main compiler/stdlib lane | main |
| effect-row Phase 2b | Partial effect-row closures are on integration branch; broader restricts/deeper propagation remains open. | Effect checker surfaces in compiler; not touched here. | Existing EFF fixtures plus new deeper propagation fixtures. | Main compiler lane | main |

## Files changed

- `compiler/nucleor_tools_suite.nr`
- `docs/rfcs/v1_PUNCHLIST.md`
- `findings/inbox/helper2_pkg1_release_dryrun_preflight_v0831_2026-05-06.md`
- `tools/VERIFY_TIMING_RECIPE.md`
- `tools/native_release.ps1`

## Residual work

PKG-1 is not fully closed until a native Linux host runs the signed publish
transcript against a throwaway registry/key and verifies the resulting package
signature. This branch closes the non-mutating preflight and dry-run inspection
gap without touching `bin/`, `bootstrap/`, real keys, or production registries.
