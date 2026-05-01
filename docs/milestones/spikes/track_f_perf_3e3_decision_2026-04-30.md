# Track F Perf Gate For 3e.3 Strict-Mode Default Flip

Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_f`

Branch: `v05-spike-3e3-perf`

Base: `b2510eb` (`v05-spike-3e1`, Track B LLVM overflow intrinsic spike)

Date: 2026-04-30

## Decision

Do not flip strict arithmetic on by default yet.

The intrinsic path is the better strict-mode candidate, but it did not stay inside the `1.13s` hot ceiling in the official perf-gate runs:

- Official run 1: intrinsic hot `1.18s`
- Official run 2: intrinsic hot `1.51s`

The legacy helper path is worse and remains the negative control:

- Official run 1: legacy helper hot `1.66s`
- Official run 2: legacy helper hot `2.24s`

Because even the env-off control was noisy and failed in the repeated official runs, the exact absolute deltas should be re-run on an idle machine before ship 8. The directional conclusion is still stable: intrinsic strict mode is materially cheaper than the legacy helper path, but not yet green for the default flip.

## Official Perf Gate Runs

Command shape for each case:

```powershell
# env-off
Remove-Item Env:\NUCLEOR_INT_STRICT_INTRIN -ErrorAction SilentlyContinue
Remove-Item Env:\NUCLEOR_INT_STRICT_ARITH -ErrorAction SilentlyContinue
.\tools\check_perf_regression.ps1

# intrinsic
$env:NUCLEOR_INT_STRICT_INTRIN = "1"
Remove-Item Env:\NUCLEOR_INT_STRICT_ARITH -ErrorAction SilentlyContinue
.\tools\check_perf_regression.ps1

# legacy helper
Remove-Item Env:\NUCLEOR_INT_STRICT_INTRIN -ErrorAction SilentlyContinue
$env:NUCLEOR_INT_STRICT_ARITH = "1"
.\tools\check_perf_regression.ps1
```

Each run was wrapped by an external process-tree watchdog. If the measured compiler tree or global `nucleor*`/`clang*` RSS crossed `1024 MB`, the wrapper would kill only the Track F child tree. The e-stop did not fire.

| Config | Official run | Gate rc | Cold | Hot | Hot ceiling | Watchdog own peak | Watchdog global compiler peak | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| env-off baseline | pre-matrix canary | 0 | 3.52s | 0.94s | 1.13s | n/a | n/a | green |
| env-off baseline | 1 | 1 | 4.10s | 1.41s | 1.13s | 571 MB | 645 MB | noisy fail |
| intrinsic (`NUCLEOR_INT_STRICT_INTRIN=1`) | 1 | 1 | 3.77s | 1.18s | 1.13s | 515 MB | 551 MB | fail |
| legacy helper (`NUCLEOR_INT_STRICT_ARITH=1`) | 1 | 1 | 3.98s | 1.66s | 1.13s | 603 MB | 637 MB | fail |
| env-off baseline | 2 | 1 | 4.09s | 1.84s | 1.13s | 632 MB | 530 MB | noisy fail |
| intrinsic (`NUCLEOR_INT_STRICT_INTRIN=1`) | 2 | 1 | 3.84s | 1.51s | 1.13s | 542 MB | 440 MB | fail |
| legacy helper (`NUCLEOR_INT_STRICT_ARITH=1`) | 2 | 1 | 5.74s | 2.24s | 1.13s | 513 MB | 445 MB | fail |

Baseline file: `tools/perf_baseline.json`

```text
cold baseline: 3.31s
cold ceiling: 3.64s
hot baseline: 1.03s
hot ceiling: 1.13s
root-process memory baseline: 132 MB
root-process memory ceiling: 145 MB
```

## No-Global-Kill Harness

The repo script starts with:

```powershell
Get-Process nucleor*,clang* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
```

That is correct for an isolated perf gate but dangerous on this shared machine. During the first Track F attempt, another worktree was actively compiling under `C:\Users\JoeWe\Desktop\Nucleor_OSS_probe`, so the initial official run was paused and a no-global-kill harness was used first. That harness runs the same cold/hot self-build workload but only kills its own Track F child process tree if the e-stop trips.

No-global-kill run:

| Config | Cold | Hot | Own peak | Global compiler peak | Notes |
|---|---:|---:|---:|---:|---|
| env-off baseline | 3.652s | 1.264s | 448 MB | 505 MB | concurrent compiler activity present |
| intrinsic (`NUCLEOR_INT_STRICT_INTRIN=1`) | 3.910s | 1.514s | 440 MB | 470 MB | emitted `7795568` byte IR |
| legacy helper (`NUCLEOR_INT_STRICT_ARITH=1`) | 3.876s | 1.540s | 507 MB | 494 MB | emitted `7170404` byte IR |

## Interpretation

- The intrinsic path is not ready for a default flip under the current `1.13s` hot ceiling.
- The legacy helper path should remain opt-in only. It is consistently slower than the intrinsic path in the official runs and in the no-global-kill run.
- The env-off control instability means this should be rerun on an idle machine after Track B is rebased onto the integrated Track D/ship 3 base.
- Peak memory stayed below the 1 GB e-stop in all Track F runs. The highest watchdog peak observed was `645 MB` global compiler RSS during the noisy official env-off run.

## Recommended Next Step

Before ship 8, re-run the same matrix on an idle machine after Track E validates narrow i8/i16/i32 intrinsic correctness. Flip strict arithmetic by default only if the intrinsic path lands at or below `1.13s` hot, or if the perf baseline is intentionally re-established with a justified new ceiling after integration.
