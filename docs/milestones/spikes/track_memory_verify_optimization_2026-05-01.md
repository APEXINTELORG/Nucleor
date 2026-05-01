# Track Memory/Verify Optimization Spike - 2026-05-01

## Scope

This spike tightens Windows compile/verify safety and starts reducing the
self-host compiler resident-memory peak without paying for repeated full
env-on/env-off verify loops during iteration.

## E-stop change

Added a shared PowerShell RSS watchdog:

- `tools/rss_estop_lib.ps1`
- `tools/run_with_rss_estop.ps1`
- `tools/run_verify_rss_estop.ps1`

The watchdog samples the launched process tree every `SampleMs` and uses a
Windows Job Object when possible (`job_assigned: true`) so child processes
remain killable even if a launcher process exits or re-parents. `BudgetMb 1000`
is treated as an emergency stop: crossing it kills the job/tree immediately.
`WarningMb 800` is a serious regression signal, not an acceptable target.

`tools/measure_peak_build.ps1` and `tools/check_perf_regression.ps1` now use
the shared watchdog. `tools/VERIFY_TIMING_RECIPE.md` documents the required
Windows invocation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\run_verify_rss_estop.ps1 `
  -Jobs 1 -BudgetMb 1000 -WarningMb 800 -SampleMs 100 `
  -RunName verify_local_iter
```

## Watchdog proof

Intentional low-budget trip:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\measure_peak_build.ps1 `
  -Source compiler\nucleor_s1_compiler.nr `
  -OutName estop_job_trip_probe `
  -BudgetMb 120 -WarningMb 80 -TimeoutSec 60 -SampleMs 50
```

Result:

```text
FAIL: compiler\nucleor_s1_compiler.nr peak 257 MB / 120 MB e-stop, wall 0.895s (process-tree RSS exceeded 120 MB e-stop)
       peak detail: nucleor:238.5MB, conhost:9.8MB, cmd:4.8MB, nucleor:3.8MB
```

Short verify timeout probe:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\run_verify_rss_estop.ps1 `
  -Jobs 1 -BudgetMb 1000 -WarningMb 800 `
  -TimeoutSec 3 -SampleMs 100 `
  -RunName estop_verify_timeout_probe2
```

Result summary:

```json
{
  "exit_code": 99,
  "killed": true,
  "reason": "timeout exceeded 3s",
  "peak_mb": 47.9,
  "job_assigned": true
}
```

After the probe, no `Nucleor_OSS_opt_memory_verify` child processes remained.

## Memory changes

1. `emit_module_ext` now frees each lowered IR function immediately after it is
   emitted or DCE-skipped. This removes the old end-of-emit bulk free and avoids
   keeping emitted IR function storage alive longer than needed.

2. Runtime `NVec` now stores the first element inline and starts `Vec::new` at
   capacity 1. This avoids a second heap allocation for the many zero/one-slot
   helper vectors created during compiler self-hosting while preserving normal
   doubling when vectors grow.

## Measured results

Baseline measured before this spike in the same worktree:

```text
measure_peak_build.ps1 self-host: peak 695 MB / wall 6.862s
check_perf_regression.ps1: cold 6.85s, hot 1.93s, peak near 695 MB
no-link timeline: peak 646.8 MB near emit/end
NUC_TRACE_ALLOC total tracked: 540 MB
```

Best guarded patched self-host results after rebasing onto `origin/main`
(`v0.5.13`):

```text
patched compiler no-link: peak 658.8 MB, wall 4.266s
patched compiler full self-build: peak 611-663 MB, wall 4.93-6.068s
NUC_TRACE_ALLOC total tracked after Vec changes: 522 MB in the inline-one run
```

This is a first reduction, not the final target. The branch is now safely under
the 800 MB warning line for these self-host runs and far under the 1000 MB
e-stop. Getting back to the older 300-400 MB range likely requires a deeper
streaming lower/emit design or a larger reduction in retained AST/IR structures.

## Focused validation

Compiled and ran these fixtures with `target\opt_final_stage1.exe` under the
1000 MB e-stop:

```text
OK tests\features\vec_basic.nr peak=129 MB
OK tests\features\vec_grow.nr peak=185.1 MB
OK tests\runtime\vec_more.nr peak=129.5 MB
OK tests\runtime\hashmap_extras.nr peak=129.7 MB
OK tests\features\rfc0007_atomic_swap_bool.nr peak=133.1 MB
OK tests\features\rfc0014_max_depth_bounded.nr peak=151.9 MB
```

Two-stage fixed point:

```text
stage2 2DEC9DD7C89C89B766BED4D6B44677FE01A0AC019FDCBA503E72B78BF8754B18
stage3 2DEC9DD7C89C89B766BED4D6B44677FE01A0AC019FDCBA503E72B78BF8754B18
FIXED_POINT_OK
```

Note: the full env-off/env-on `verify.sh` matrix was intentionally not run in
the inner loop. The intended final gate is one `run_verify_rss_estop.ps1` pass
with `-Jobs 1`, then a deliberate final full gate only when the memory patch is
ready to merge.
