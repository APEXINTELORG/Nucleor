# Helper2 Queue 4 Release Tooling Closure Report

Date: 2026-05-06

Worktree: `C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

Branch: `fix/helper2-release-tooling-closure-v0830`

Base: `origin/main` at `5ec86d7e4d965359348d33826553659157d16016`

Copied assignment left untracked:
`C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828\findings\_helper2_assignment_v0828_r06_rust_bridge_ownership_harness_2026-05-06.md`

## Summary

This queue stayed tooling/docs/report-first. I did not edit compiler, bin,
bootstrap, or normal release/signing logic.

Completed:

- Scope R: corrected `tools/verify_fast.sh` help/header drift and documented
  that `verify_fast` is not a release signoff substitute.
- Scope S: audited publish/sign dry-run and overwrite surfaces; no broad
  signing implementation was changed.
- Scope T: re-ran POSIX perf doctor from this Windows/WSL host and recorded
  why it cannot be native POSIX evidence.
- Scope U: classified Python references after the integration branch's
  TOOLCHAIN-PY-1 closure into product-path-closed, intentional interop,
  maintenance-only, optional doctor, and test/reference.
- Scope V: refreshed v1 punchlist accounting for PKG-1, POSIX perf, and
  residual TOOLCHAIN-PY audit and added the blocker matrix below.

## Scope R - verify_fast versus full verify parity

Evidence:

- `tools/verify.sh` includes `step "T1.8 POSIX perf + memory regression monitor" posix_perf_regression_monitor`.
- `tools/verify_fast.sh` does not include that full-release POSIX perf step.
- `tools/verify.ps1` owns the Windows perf monitor through
  `tools/check_perf_regression.ps1`.

Change made:

- `tools/verify_fast.sh` now names itself `verify_fast.sh`, uses the correct
  invocation in `--help`, and states that full-release checks such as native
  POSIX cold/hot perf remain owned by `tools/verify.sh`.
- `tools/VERIFY_TIMING_RECIPE.md` now states the same release-signoff
  boundary.

No gate behavior changed.

## Scope S - PKG-1 publish/sign dry-run hardening

Current product path:

- `compiler/nucleor_s1_compiler.nr` delegates `run_publish_command` to the
  external tools-suite path.
- `compiler/nucleor_tools_suite.nr` parses `nuc publish [manifest]
  [--registry <dir>] [--sign] [--key-id <id>]`.
- Publish refuses to overwrite an existing package by checking for
  `<registry>/<name>/<version>/Nucleor.toml` before copying.
- After copy, it writes package export artifacts, checksums, registry metadata,
  then calls `invoke_native_package_sign(...)` when signing is requested.
- `tools/native_release.ps1` signs and verifies release/package artifacts with
  ssh-ed25519 via `ssh-keygen`, and writes the signature JSON files.

Blockers found:

| Item | Current evidence | Why not closed here | Smallest next surface |
|---|---|---|---|
| Native Linux `nuc publish --sign` | PKG-1 still needs native Linux runner evidence in `docs/rfcs/v1_PUNCHLIST.md` | This host is Windows/WSL; no native Linux `bin/nucleor` | Run signed publish on native Linux after `bash tools/bootstrap_linux.sh` |
| Non-mutating publish dry-run | Publish has overwrite protection but copies before signing | Adding `--dry-run` to product publish path touches tools-suite and requires compiler/bin/bootstrap promotion | Add tools-suite `--dry-run` that resolves manifest, graph, target paths, export manifest path, checksum/signature paths, and key id without copying |
| Signing preflight | `tools/native_release.ps1` can sign/verify packages, but package-sign writes signature files and may auto-create keys | A read-only preflight mode is not present | Add `nuc release package-sign --dry-run <dir> [key-id]` or equivalent preflight output listing missing inputs and target signature path |

I did not implement these because the smallest real fix crosses compiler/tools
suite promotion boundaries and this queue's guardrail was tooling/docs/report
first unless the change was obviously isolated.

## Scope T - POSIX perf evidence closeout

Doctor command run from this worktree:

```text
bash tools/check_perf_regression.sh --doctor
```

Observed host refusal:

```text
doctor native-linux: FAIL - WSL kernel is shell-check only for this gate osrelease=6.6.87.2-microsoft-standard-WSL2
doctor linux-proc: OK - /proc is present
doctor required-shell-tools: OK - awk grep sed sort date mktemp rm tail bash setsid
doctor clang: FAIL - missing from PATH
doctor run-capped: OK - /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/tools/run_capped.sh
doctor baseline-and-source: OK - baseline=/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/tools/perf_baseline.json source=/mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/compiler/nucleor_s1_compiler.nr
doctor native-executable: FAIL - native /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/bin/nucleor is missing or not executable; bin/nucleor.exe is Windows-only
doctor elf-proof: FAIL - cannot inspect missing binary: /mnt/c/Users/JoeWe/Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828/bin/nucleor
doctor result: unsupported for native POSIX perf evidence
```

Native Linux transcript command that still needs a real Linux runner:

```bash
bash tools/check_perf_regression.sh --doctor
bash tools/bootstrap_linux.sh
file bin/nucleor
bash tools/check_self_host_md5.sh
bash tools/check_perf_regression.sh \
  --baseline tools/perf_baseline.json \
  --cold-samples 3 \
  --hot-samples 3
```

Expected success shape:

```text
OK POSIX perf: cold=<seconds>s (max <seconds>s) | hot=<seconds>s (max <seconds>s) | mem cold_tree=<mb>/<max>MB cold_compiler=n/a hot_tree=<mb>/<max>MB hot_compiler=n/a
```

## Scope U - TOOLCHAIN-PY residual classification

Python reference classification:

| Class | Hits | Disposition |
|---|---|---|
| Product/toolchain dependency | CLOSED on integration branch: `verify-reproducible` no longer shells out to `python -c "import filecmp"` on Windows | Windows uses native `fc /B`; POSIX uses `cmp -s`; keep this closed by blocking new Python product/toolchain dependencies |
| Intentional language interop | `README.md` Python interop mention, `docs/rods-and-runtime.md`, `stdlib/rods/python.nr`, `stdlib/rods/python_rt.c`, `tests/features/python_*` | Keep; not part of TOOLCHAIN-PY removal |
| Maintenance-only generators | `tools/gen_helper_manifest.py`, `tools/gen_rod_manifest.py`, `tools/gen_releases_index.py`, `tools/gen_numerics_matrix.py`, `tools/gen_benchmark_summary.py`, `tools/g1_default_flip_safety_audit.py` | Keep for now; not product runtime/toolchain dependency |
| Optional doctor check | `nuc_router.ps1` checks Python/SymPy and emits WARN when unavailable | Keep unless product policy decides doctor should stop mentioning optional SymPy |
| Test/reference/docs only | Python snippets/comments in docs and reference examples such as `stdlib/rods/nn.nr` comments | Keep |

Keep-closed validation for the former removable product path:

- Search for accidental reintroduction of Python/filecmp in product paths:
  `rg -n "python -c|filecmp|verify-reproducible" compiler tools docs nuc_router.ps1 stdlib tests README.md`.
- Run the normal compiler/bin/bootstrap promotion checks when this surface
  changes:
  - `bin\nucleor.exe verify-reproducible compiler\nucleor_s1_compiler.nr`
  - `bash tools/check_self_host_md5.sh`
  - `bash tools/check_compiler_drift.sh`
  - `pwsh -NoProfile -File tools\check_perf_regression.ps1`
  - `git diff --check`

## Scope V - Release Blocker Dashboard

| Lane | Current status | Evidence | Next file/function surface | Validation command | Platform | Owner |
|---|---|---|---|---|---|---|
| PKG-1 Linux `nuc publish --sign` | OPEN | `nuc publish` is wired to tools-suite local registry copy + `tools/native_release.ps1`; no native Linux signed transcript yet | `compiler/nucleor_tools_suite.nr::run_publish_command`, `tools/native_release.ps1`, future publish dry-run/preflight | Native Linux signed publish transcript after `bash tools/bootstrap_linux.sh` | Native Linux | main + helper |
| POSIX perf native evidence | PREP INTEGRATED, evidence pending | `tools/check_perf_regression.sh --doctor` refuses WSL/Windows interop honestly | Native Linux runner, `tools/check_perf_regression.sh`, `tools/VERIFY_TIMING_RECIPE.md` | `bash tools/check_perf_regression.sh --doctor`; full cold/hot command above | Native Linux | main/operator |
| Rust bridge ownership | INTEGRATED | Integration branch carries `tools/check_rust_bridge_ownership.ps1`, `tools/check_rust_bridge_ownership.sh`, and repeat/hash ownership fixtures through commits `f6d2fa9c`, `a688067f`, and `04bcbc4e` | Keep harness docs and fail-closed self-test contract current when Rust bridge ownership changes | Harness text/JSON/self-test/doctor commands from v0828 report and `tools/VERIFY_TIMING_RECIPE.md` | Windows + POSIX | helper2 + main |
| TOOLCHAIN-PY | PRODUCT PATH CLOSED, residual audit only | `verify-reproducible` uses native `fc /B` on Windows and `cmp -s` on POSIX; interop/generators remain classified separately | Keep-closed audit for compiler/toolchain product paths | `rg -n "python|py -|python -c|\\.py\\b|filecmp|json.tool" compiler tools docs nuc_router.ps1 stdlib tests README.md` | Windows primary, POSIX sanity | main |
| RT deadline/WCET | OPEN beyond existing warnings | Existing gates cover `RT-004` warning and allow suppression; broader numeric/deadline backing remains open | RT attribute analysis in compiler and WCET estimator path | Existing focused RT fixtures plus full verify when compiler changes | Windows + POSIX | main |
| ROBO-7 frame typing | OPEN | v1 punchlist says new frame types/compiler check still queued | Robotics rod frame types + compiler frame mismatch check | Future ROBO-7 fixture build/run matrix | Windows + POSIX | main |
| Effect-row Phase 2b | OPEN | Phase 1 direct/restricts signals exist; transitive/cross-module enforcement remains open | Effect row parser/type checker/cross-module propagation | Active EFF fixtures plus new Phase 2b negatives | Windows + POSIX | main |

## Validation Results

Run from:
`C:\Users\JoeWe\Nucleor_OSS_helper2_r06_rust_bridge_ownership_v0828`

| Command | Result |
|---|---|
| `bash -n tools/verify.sh` | PASS |
| `bash -n tools/verify_fast.sh` | PASS |
| `[scriptblock]::Create((Get-Content -Raw tools\verify.ps1)) \| Out-Null` | PASS |
| `bash -n tools/check_perf_regression.sh` | PASS |
| `rg -n "publish\|sign\|package\|dry.?run\|checksum\|sha256\|release" tools docs bootstrap README.md` | PASS, matches reviewed |
| `rg -n "POSIX\|Linux\|perf\|cold\|hot\|RSS\|native" tools docs findings` | PASS, matches reviewed |
| `rg -n "python\|py -\|python -c\|\.py\b\|filecmp\|json.tool" compiler tools docs nuc_router.ps1 stdlib tests README.md` | PASS, matches classified above |
| `rg -n "PKG-1\|POSIX\|rust bridge\|TOOLCHAIN-PY\|WCET\|ROBO-7\|effect-row\|Phase 2b" docs tools findings` | PASS, dashboard terms present |
| `git diff --check` | PASS |

Full verify/perf was intentionally not run: this branch only changes docs,
`verify_fast.sh` help text, and this report; native POSIX perf evidence cannot
be produced from this Windows/WSL host.

## Integration Replay Validation

Run from:
`C:\Users\JoeWe\Desktop\Nucleor_OSS_qm7_surface_v0827`

| Command | Result |
|---|---|
| `bash -n tools/verify_fast.sh` | PASS |
| `bash -n tools/verify.sh` | PASS |
| `bash -n tools/check_perf_regression.sh` | PASS |
| `[scriptblock]::Create((Get-Content -Raw tools\verify.ps1)) \| Out-Null` | PASS |
| `bash tools/verify_fast.sh --help` | PASS, help names `verify_fast.sh` and states release signoff remains `tools/verify.sh` |
| `rg -n "python -c\|filecmp" compiler tools nuc_router.ps1` | PASS, no product/toolchain hits |
| `git diff --check` | PASS |
