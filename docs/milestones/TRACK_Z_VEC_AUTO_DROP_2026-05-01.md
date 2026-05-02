# Track Z: Vec Auto-Drop Spike

Branch: `v06-track-vec-drop`
Worktree: `C:\Users\JoeWe\Desktop\Nucleor_OSS_track_vec_drop`
Base: `origin/main` at `f78d922` (`v0.5.31`)

## Scope

This spike implements the first safe slice of RFC-0042: opt-in auto-drop for owned locals via `#[auto_drop]`.

## Shipped In This Spike

- Source-text scanner for `#[auto_drop]` function attributes.
- Lowering-time tracking for local `let` bindings of `Vec<T>` and `HashMap<K,V>`.
- Cleanup before explicit and implicit returns.
- Manual `vec_free` / `hashmap_free` recognition to avoid generated double-free.
- Rebinding cleanup for tracked locals before replacement store.
- Shadowing cleanup for tracked locals after RHS lowering and before new binding install.
- Return-by-bare-local skip so owned values can be returned without being freed first.
- Feature fixture: `tests/features/rfc0042_auto_drop_vec.nr`.
- Verify smoke: `RFC-0042 auto_drop emits owned-local cleanup once`.

## Boundaries

- Opt-in only. Default semantics are unchanged.
- Tracks local `let` bindings only. Parameters, globals, fields, and captures are intentionally excluded.
- Nested branch-scope fallthrough cleanup is not complete in this slice; returns inside cloned branch scopes still run cleanup for that branch's tracked locals.
- User struct drop glue and trait-based `Drop` dispatch are RFC follow-up work.
- `str` / `String` auto-drop is excluded until the compiler can distinguish owned heap strings from string literals.

## Validation Notes

Use the agent namespace and monitored wrappers. `1024 MB` is an emergency stop threshold only; it is not the memory target. The target remains the lowest practical peak, with drift judged against the tight memory budgets and recent baseline history.

```powershell
$env:NUC_VERIFY_AGENT='parallel1'
. .\tools\run_capped.ps1
$r = Run-Capped '.\bin\nucleor.exe' @('build','compiler/nucleor_s1_compiler.nr','-o','_track_vec_drop_syntax','--no-link','--no-cache') -EstopMB 1024 -TimeoutSec 180 -Label 'compiler no-link syntax'
```

Observed sanity check:

- compiler no-link syntax: PASS, 3.81s wall, 661 MB peak.
- promoted self-host compiler after string auto-drop exclusion: PASS, 6.332s wall, 713 MB peak.
- RFC-0042 narrow verify smoke under `tools/run_with_peakmem.ps1`: PASS, step 0.52s; wrapper wall 121.738s; wrapper peak 280 MB; killed=False.
- linked RFC-0042 runtime fixture: PASS, 1.353s build wall, 151 MB peak; executable exit code 0.
- fixed-point self-host: PASS. `_stage_b_vec_drop.ll` and `_stage_c_vec_drop.ll` SHA256 both `D19A493D1761937C7B086CA899630D7F0F714DDDC49BEE42D67FEE5BC54B9378`.
- refreshed `bootstrap/nucleor_s1_seed.ll`; seed verify rebuild matched the same SHA256, 7.514s wall, 713 MB peak.
- direct `tools/check_compiler_drift.sh`: PASS.
- direct `tools/verify.sh --only 'compiler ABI tables synced'`: PASS.
- direct self-host memory budget gate: PASS, 713 MB / 770 MB budget, 6.385s wall.
- direct tools-suite memory budget gate: PASS, 539 MB / 580 MB budget, 5.841s wall.
- official wrapper `tools/run_with_peakmem.ps1 -VerifyArgs '--only "tools-suite rebuild"' -EstopMb 1024`: PASS, step 6.83s; wrapper peak 772 MB; killed=False.

Narrow gate:

```powershell
$env:NUC_VERIFY_AGENT='parallel1'
pwsh tools/run_with_peakmem.ps1 -VerifyArgs '--only "RFC-0042 auto_drop emits owned-local cleanup once"' -EstopMb 1024 -PollMs 1000
```

Note: a wrapper-only run of the `compiler ABI tables synced` step reported an implausible high process-sum peak for a non-build step in this mixed Windows/bash environment. The direct drift script and the direct verify step both passed; the memory-budget gates above used the PowerShell process-tree sampler.

## Rebase Refresh: 2026-05-02

Rebased onto `origin/main` at `f78d922` after the Track Y merge and verify-gate perf fixes.

- conflict shape: source files auto-merged; generated artifacts `bin/nucleor.exe` and `bootstrap/nucleor_s1_seed.ll` were rebuilt from the merged compiler source.
- stage1 self-host build: PASS, 4.92s wall, 678 MB peak; monitored with 1024 MB emergency stop.
- stage2 self-host build: PASS, 4.953s wall, 675 MB peak; monitored with 1024 MB emergency stop.
- fixed-point hash: `_z_rebase_stage1.ll` and `_z_rebase_stage2.ll` both `9CA0CFA6345820B4A314474C9BDC0406C6998FC3EF06CFD4800CF8890428BC60`.
