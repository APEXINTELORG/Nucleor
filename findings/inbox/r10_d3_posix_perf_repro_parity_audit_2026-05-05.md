# R10-D3 POSIX Perf/Repro Parity Audit

Date: 2026-05-05
Owner: helper2
Branch: `probe/helper2-r10-d3-posix-perf-repro-audit-v0821`
Base: `origin/main` at `94cadcdac96ea1b43616e883b40770e25075e317`

## Summary

R10-D3 remains open, but the shape changed while this audit was in flight:
current `origin/main` now includes the R13-D5 POSIX RSS e-stop work
(`tools/run_capped.sh`) and later verification/cache-key updates. The R13-D5
work closes the old "soft NUC_TRACE_ALLOC fallback" problem for the verify
memory-budget steps on native Linux hosts.

What is still missing for R10-D3 is the POSIX equivalent of the Windows
cold/hot perf regression gate:

- no `tools/check_perf_regression.sh`,
- no `tools/verify.sh` step equivalent to Windows
  `T1.8 perf + memory regression monitor`,
- no native Linux transcript showing 3 cold and 3 hot self-build samples,
  cache miss/hit enforcement, threshold comparison, and native process-tree
  RSS evidence against the perf baseline,
- no POSIX routine `verify-reproducible` gate; Windows `verify.ps1` has a
  sample `verify-reproducible` fixture, but `verify.sh` does not.

WSL launching `bin/nucleor.exe` through interop is still invalid for POSIX
RSS/process-tree proof. Native Linux evidence must use a native Linux
`bin/nucleor` produced from the bootstrap seed.

## Local Evidence Captured

Commands run from:

`C:\Users\JoeWe\Nucleor_OSS_helper2_r10_d3_posix_perf_repro_audit_v0821`

```powershell
bash -n tools/run_capped.sh tools/verify.sh tools/verify_fast.sh tools/bootstrap_linux.sh tools/check_self_host_md5.sh tools/check_mem_regression.sh tools/bisect_mem.sh tools/memory_drift_profile.sh
```

Result: PASS.

```powershell
pwsh -NoProfile -File tools\check_perf_regression.ps1
```

Result: PASS.

Observed output on the helper branch after refreshing through current
`origin/main`:

```text
OK perf: cold=3.68s (max 4s) | hot=0.27s (max 1s) | mem cold_tree=311/400MB cold_compiler=292/350MB hot_tree=42/128MB hot_compiler=28/64MB
```

```powershell
git diff --check
```

Result: PASS.

No native Linux runner is available in this local Windows worktree, so no
native POSIX RSS or Linux timing claim is made here.

## Source Evidence

- `tools/verify.ps1:2836-2844` has the Windows routine step
  `T1.8 perf + memory regression monitor`, invoking
  `tools/check_perf_regression.ps1`.
- `tools/check_perf_regression.ps1:1-12` defines the cold/hot self-build perf
  check; `tools/check_perf_regression.ps1:199-306` runs 3 cold samples and 3
  hot samples, checks cache miss/hit shape, and enforces time plus split RSS
  ceilings from `tools/perf_baseline.json`.
- `tools/verify.sh:5620-5623` and `tools/verify_fast.sh:5144-5147` run
  bootstrap seed and self-host fixed-point steps, but there is no analogous
  `check_perf_regression` step in the POSIX gate. `tools/verify.sh:290` only
  comments that `tools/check_perf_regression.ps1` reads timing CSVs.
- `tools/verify.ps1:1448-1453` has a sample
  `nuc verify-reproducible` fixture. `tools/verify.sh` and
  `tools/verify_fast.sh` have no `verify-reproducible` step.
- `tools/verify.sh:1357-1362` documents the current memory-budget contract:
  Windows uses the PowerShell process-tree sampler; Linux uses
  `tools/run_capped.sh`; unsupported POSIX hosts fail instead of soft-passing.
- `tools/verify.sh:4936-5000` implements that selection and calls
  `tools/run_capped.sh` when no PowerShell sampler is selected.
- `tools/run_capped.sh:1-14` defines a Linux `/proc` process-tree RSS e-stop;
  `tools/run_capped.sh:72-96` requires Linux `/proc` plus `setsid` and rejects
  WSL Windows `.exe` interop; `tools/run_capped.sh:192-282` samples process
  tree RSS and kills the process group on budget crossing.
- `tools/bootstrap_linux.sh:11-18` documents the POSIX bootstrap pipeline:
  clang the committed seed plus runtime, self-rebuild, compare fixed point,
  and promote stage 2.
- `tools/check_self_host_md5.sh:14-20` verifies stage1-emitted compiler IR
  equals stage2-emitted compiler IR and that stage2 matches
  `bootstrap/nucleor_s1_seed.ll`.
- `tools/VERIFY_TIMING_RECIPE.md:60-96` documents the new POSIX RSS e-stop
  path, including forced Linux `/proc` verification commands and the WSL
  interop caveat.
- `docs/rfcs/gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md:29-36`
  still records the original R10-D3/PERF-3 and PERF-5 gaps: POSIX verify lacks
  the perf gate, and routine verify lacks the intended reproducibility gate.

## Audit Questions

### 1. Windows-only verify/perf/repro commands today

- `pwsh -NoProfile -File tools\check_perf_regression.ps1`
  - Requires `bin\nucleor.exe`.
  - Uses `tools\rss_estop_lib.ps1`.
  - Measures Windows process-tree RSS for `nucleor.exe`, `clang.exe`,
    `lld-link.exe`, and related descendants.
  - Enforces cold/hot timing and split process-tree/compiler RSS ceilings.
- `pwsh -NoProfile -File tools\measure_peak_build.ps1 ...`
  - Windows process-tree RSS sampler for one build.
- `pwsh -NoProfile -File tools\run_verify_rss_estop.ps1 ...`
  - Windows wrapper around Git Bash `verify.sh` with a PowerShell
    process-tree e-stop.
- `pwsh -NoProfile -File tools\run_with_rss_estop.ps1 ...`
  - Generic Windows process-tree RSS e-stop wrapper.
- `pwsh -NoProfile -File tools\run_with_peakmem.ps1 ...`
  - Windows verify wrapper that appends a run-summary row to verify timing CSV.
- `tools\nuc_rss_estop.c`
  - Optional native Windows sampler using Win32 ToolHelp/PSAPI, not POSIX.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\verify.ps1`
  - Windows routine verify gate; it contains the perf regression monitor step
    and a sample `verify-reproducible` fixture.

### 2. POSIX commands that exist and parse cleanly

These parsed with `bash -n` in the local environment:

- `bash tools/run_capped.sh`
- `bash tools/verify.sh`
- `bash tools/verify_fast.sh`
- `bash tools/bootstrap_linux.sh`
- `bash tools/check_self_host_md5.sh`
- `bash tools/check_mem_regression.sh`
- `bash tools/bisect_mem.sh`
- `bash tools/memory_drift_profile.sh`

POSIX capability split:

- `bash tools/bootstrap_linux.sh` is the native POSIX bootstrap command.
- `bash tools/check_self_host_md5.sh` is the native self-host fixed-point
  command, provided `bin/nucleor` is a native POSIX binary.
- `bash tools/run_capped.sh ...` is now the native Linux `/proc` RSS e-stop
  wrapper for a single command/process group.
- `NUC_VERIFY_FORCE_POSIX_RSS=1 bash tools/verify.sh --only "<memory step>"`
  can force the verify memory-budget step through Linux `/proc` on a native
  Linux host.
- `bash tools/verify.sh` and `bash tools/verify_fast.sh` include POSIX
  self-host/fixed-point steps and real RSS memory-budget steps, but not a
  native cold/hot perf gate equivalent to `tools/check_perf_regression.ps1`.
- `bash tools/check_mem_regression.sh` can analyze verify timing CSVs, but
  R10-D3 still lacks a POSIX cold/hot perf run-summary producer equivalent to
  the Windows perf gate.

### 3. Commands that require native Linux process evidence rather than WSL

Native Linux evidence is required for:

- proving `tools/run_capped.sh` on real Linux `/proc`,
- POSIX cold/hot self-build timing against Linux clang/lld behavior,
- POSIX process-tree RSS during cold/hot self-build samples,
- POSIX compiler-only versus process-tree memory accounting, if that split is
  required for parity with `tools/check_perf_regression.ps1`,
- any claim that `tools/perf_baseline.json` thresholds are valid for Linux,
- any full POSIX verify run used as RSS/perf evidence.

Do not use WSL `/proc` as proof when the binary under test is
`bin/nucleor.exe`. WSL interop observes a bridge process, not the real Windows
`nucleor.exe` plus `clang.exe`/`lld-link.exe` process tree. The current
`tools/run_capped.sh` explicitly rejects that case.

### 4. Commands that WSL can run as shell/script checks only

WSL is acceptable for non-evidence command shape checks such as:

```bash
bash -n tools/run_capped.sh tools/verify.sh tools/verify_fast.sh
bash -n tools/bootstrap_linux.sh tools/check_self_host_md5.sh
bash -n tools/check_mem_regression.sh tools/bisect_mem.sh
```

WSL can also inspect scripts, grep for step registration, and verify that
`tools/run_capped.sh` rejects Windows `.exe` interop. WSL should not be used to
claim Linux RSS, Linux process-tree memory, or Linux cold/hot timing if it
launches the checked-in Windows `bin/nucleor.exe`.

### 5. Exact native Linux runner commands needed to close the gap

Current repo commands that a native Linux runner should execute first:

```bash
set -euo pipefail
git clean -xfd target .nuc_cache tools/verify_timings.posix.csv 2>/dev/null || true
bash -n tools/run_capped.sh tools/verify.sh tools/verify_fast.sh tools/bootstrap_linux.sh tools/check_self_host_md5.sh tools/check_mem_regression.sh tools/bisect_mem.sh
bash tools/bootstrap_linux.sh
file bin/nucleor
./bin/nucleor --version
bash tools/check_self_host_md5.sh
```

Native Linux RSS e-stop smoke:

```bash
set +e
bash tools/run_capped.sh --budget-mb 1 --label estop-smoke -- sleep 2
test "$?" -eq 99
set -e
bash tools/run_capped.sh --budget-mb 512 --label success-smoke -- sleep 0.2
```

Native Linux verify memory-budget path:

```bash
NUC_VERIFY_FORCE_POSIX_RSS=1 bash tools/verify.sh --only "self-host memory budget (<= 770 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
NUC_VERIFY_FORCE_POSIX_RSS=1 bash tools/verify.sh --only "tools-suite memory budget (<= 580 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
```

Manual native Linux cold/hot timing evidence available today:

```bash
set -euo pipefail
rm -rf target .nuc_cache
bash tools/run_capped.sh --budget-mb 1000 --warning-mb 800 --label posix-cold -- /usr/bin/time -v ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o nuc_perf_check
bash tools/run_capped.sh --budget-mb 1000 --warning-mb 800 --label posix-hot -- /usr/bin/time -v ./bin/nucleor build compiler/nucleor_s1_compiler.nr -o nuc_perf_check
```

That proves command shape and can capture timing/RSS on a native Linux host,
but it is not sufficient for R10-D3 closure because it is not a repo-enforced
3-cold/3-hot gate and does not compare against `tools/perf_baseline.json`.

Exact acceptance command for the next implementation branch:

```bash
bash tools/check_perf_regression.sh --baseline tools/perf_baseline.json --cold-samples 3 --hot-samples 3 --budget-mb 1000 --warning-mb 800
```

That script does not exist yet. It should be added in the implementation lane
and should:

- require or bootstrap a native POSIX `bin/nucleor`,
- use `tools/run_capped.sh` for Linux `/proc` RSS e-stop sampling,
- clear `target/` and `.nuc_cache/` before cold samples,
- require cold samples to start with `cache: miss`,
- run immediate hot samples without cleanup,
- require hot samples to report `cache: hit`,
- measure wall time for each sample,
- report process-tree RSS and, if feasible on POSIX, compiler-only RSS,
- compare results against `tools/perf_baseline.json`,
- exit nonzero on any threshold miss or unsupported dependency.

After that script exists, `tools/verify.sh` should include a named step that
runs it on native POSIX hosts or fails with a clear dependency/unsupported-host
message.

### 6. Files needing edits in a future implementation branch

Minimum future write set:

- `tools/check_perf_regression.sh` - new POSIX cold/hot timing gate that uses
  `tools/run_capped.sh` for Linux `/proc` RSS e-stop sampling.
- `tools/verify.sh` - add the named POSIX perf/repro step.
- `tools/verify_fast.sh` - mirror the step only if fast verify is intended to
  enforce the same parity surface.
- `tools/perf_baseline.json` - either keep the current shared fields with
  host labels or add explicit POSIX baseline fields after native measurements.
- `tools/VERIFY_TIMING_RECIPE.md` - add the native POSIX cold/hot perf runner
  flow once `tools/check_perf_regression.sh` exists.
- `tools/check_mem_regression.sh` - only if the POSIX perf gate emits
  run-summary rows that should feed the existing CSV drift analyzer.
- `docs/rfcs/gap-analyses/Nucleor_Performance_Envelope_Gap_Analysis_and_RFC_2026-05-04.md`
  or the active build-plan closure doc - mark R10-D3 closed only after native
  runner evidence lands.
- CI or release workflow files, if the project wants this enforced outside
  local developer machines.

Do not edit compiler, runtime, rods, committed binaries, bootstrap seed, or
release/changelog files for the audit-only branch.

## Recommended Next Implementation Lane

Open a dedicated `R10-D3 Phase 1 POSIX cold/hot perf gate` implementation
branch with one objective: add `tools/check_perf_regression.sh` and wire it
into `tools/verify.sh` with a native-POSIX dependency gate. Reuse
`tools/run_capped.sh` rather than inventing a second POSIX RSS wrapper.

The branch should run on a real Linux host, not WSL interop, and should attach
the runner transcript showing:

- POSIX bootstrap from `bootstrap/nucleor_s1_seed.ll`,
- `bash tools/check_self_host_md5.sh` passing,
- three cold and three hot self-build samples,
- cache miss on cold and cache hit on hot,
- process-tree RSS e-stop sampling through `tools/run_capped.sh`,
- a threshold comparison against `tools/perf_baseline.json`,
- explicit failure mode when required tools (`clang`, `/usr/bin/time`, Linux
  `/proc`, `setsid`, shell utilities) are unavailable.

Until that exists, R10-D3 should remain open.
