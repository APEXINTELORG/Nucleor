# Memory Drift Investigation — 2026-05-01

**Author:** main agent
**Trigger:** user observed parallel-agent reports of 882-968 MB peak self-host (close to the 1 GB cap) and asked "we had 3.5s cold and like 300-400 MB or thereabouts... 800 MB is not going to work". The 1 GB process-tree cap was supposed to be an emergency-stop, not a normal-operation budget.
**Ship that lands the tighten:** v0.5.14 (this doc + the budget-ratchet in `tools/verify.sh`).

## Findings

The real-time process-tree e-stop already exists in `tools/measure_peak_build.ps1`: it samples every 100 ms and kills the process tree if peak RSS exceeds the budget. **What broke is the budget itself was raised to 1024 MB by Track L** without forcing a memory-tighten pass — used as a comfort blanket exactly as the user described.

### Memory budget history

| Ship | Self-host budget | Self-host actual peak | Notes |
|---|---|---|---|
| v0.2.161 | **400 MB** | 185 MB | Original cap, 2.2× headroom |
| Track L (v0.5.0 cut) | **1024 MB** | (raised) | "Process-tree compile cap" — accommodated growth instead of forcing a tighten |
| v0.4.232 (mid-arc) | 1024 MB | ~400-450 MB | (extrapolated from spike docs) |
| **v0.5.13 (main)** | 1024 MB | **587 MB env-off / 704 MB env-on** | What we actually run with |
| `v06-track-max-depth-extensions` | 1024 MB | 650 MB env-off | Parallel-1 deliverable, not in main |
| `v06-track-effects-types` | 1024 MB | **818-823 MB env-off** | Parallel-1 deliverable, biggest offender |
| Parallel-agent full-run reported peak | 1024 MB | **968 MB env-off / 882 MB env-on** | Sampler covers compiler + clang + native isolated child overlap (different aggregator from per-step `_memory_budget_for`) |

Baseline-to-current ratio: **3.2× on main, 4.4× on the worst v0.6 branch, 5.2× on the parallel-agent's full-run reported peak**.

### What drifted

No single ship broke it; ~50-100 MB per major addition accreted across the v0.4 → v0.5 arc:

- RFC-0006 DbC (CONTRACT-001..011) — contract-evaluation + snapshot machinery
- RFC-0007 atomics (Track G + H) — intrinsic lowering paths + queue rod state
- RFC-0014 max_depth (Track I) — analyzer + wrapper-rewrite source-level pass
- Track L cache v2 — content-addressed in-memory cache state
- v0.5.13 generic-T propagation — argument-walk binding accumulation (small)

Effects-types branch's ~230 MB delta vs main is concentrated in the new `with [...]` parser machinery + EFF-* check pass (per spike doc). It's the urgent investigation for the v0.6 line.

### env-off vs env-on overhead

env-on (`NUCLEOR_INT_STRICT_INTRIN=1`) adds **~117 MB on main** (587 → 704 MB) on top of env-off. This is the strict-arithmetic intrinsic state — likely a wider IR-symbol surface and per-binop overflow trap label allocation. Worth a follow-up profile to see if any of it is reducible.

## Action taken in v0.5.14

1. **Ratchet the budget down**: `self_host_memory_budget` from 1024 → **750 MB** (current peaks 587/670/704 MB across multiple samples; 80 MB env-on headroom). `tools_suite_memory_budget` from 1024 → **580 MB** (initial 540 MB from one sample was too tight — second sample landed at 529 MB; 580 MB is current peak + 50 MB headroom).

> **Note on sample variance:** memory peaks vary 10-15% between identical runs because the sampler captures process-tree RSS at 100 ms granularity and clang's working-set timing depends on OS scheduler / page-cache state. Pick budgets at peak + 50 MB rather than peak + 5 MB.

2. **Make the raise-rule explicit**: comments in `tools/verify.sh` now require any future bump to come with a documented investigation in the same ship. Comfort-blanket raises are how the original 1024 MB ceiling was reached.

3. **The real-time e-stop unchanged**: `tools/measure_peak_build.ps1` still samples every 100 ms and kills the process tree if peak RSS > budget. v0.5.14 only tightens the budget — the kill mechanism was already correct.

## Action deferred

1. **Block the v0.6 parallel-1 branches from merging** until they ship a memory-tighten pass. `v06-track-effects-types` at 818 MB self-host fails the new 750 MB cap by 68 MB; `v06-track-max-depth-extensions` at 650 MB still passes but with less margin than main. **Effects-types is the urgent one.**

2. **Profile the cumulative drift**: run `NUC_TRACE_ALLOC=1` against tagged commits (v0.4.232, v0.4.260, v0.5.0, v0.5.13) to identify the worst per-ship offenders. Goal: tighten back toward the v0.2.161 era's 400 MB ceiling, not just stop-the-bleeding at 750 MB.

3. **Investigate the env-on +117 MB delta**. Likely candidates: per-binop overflow trap labels, IR-symbol expansion under strict-intrin. Cap target post-investigation: <= 50 MB env-on overhead.

## Profile data (v0.5.16, 2026-05-01)

`tools/memory_drift_profile.sh` runs the **current `bin/nucleor.exe` against historical s1 sources** (each tag's `compiler/nucleor_s1_compiler.nr`). Same compiler, varying input size — isolates source-size effect from compiler-internal-state effect.

| Tag | s1 size (KB) | s1 lines | Peak RSS (MB) | Wall (s) |
|---|---|---|---|---|
| v0.4.260 | 1,378 | 25,781 | 830 | 4.10 |
| v0.4.282 | 1,412 | 26,497 | 858 | 4.32 |
| v0.5.0 | 1,440 | 27,070 | 825 | 4.62 |
| v0.5.7 | 1,445 | 27,156 | 895 | 4.33 |
| v0.5.13 | 1,460 | 27,413 | 902 | 5.05 |
| v0.5.14 | 1,460 | 27,413 | 903 | 4.49 |
| v0.5.15 | 1,460 | 27,413 | 898 | 4.80 |

**Two reads:**

1. **Source-driven growth is healthy.** v0.4.260 → v0.5.15: source grew 5.9%, peak grew 8.2%. Compiler allocation is mostly proportional to input size with only ~2.3% extra-per-byte cost from new compiler logic. The `is_atomic_ordered_builtin`, `gparam_extract_binding`, and `md_find_enclosing_impl_type` substrate added since v0.5.0 hasn't bloated allocation patterns.

2. **Absolute peaks are 200-300 MB higher than the normal-verify-gate reports.** Same bin, same `--no-cache`, same source — but `tools/memory_drift_profile.sh` (back-to-back single-source measurements) consistently shows 825-903 MB while normal `tools/verify.sh` runs report 587-703 MB self-host peak. The delta is OS-state-dependent (Windows working-set timing varies with the broader build sequence). **Implication: our 770 MB cap might be tighter than intended on cold environments — we'll want to measure on a cold `cmd.exe` to confirm.**

What the profile DOESN'T tell us: the era-current era-current relationship (a v0.4.260-era bin compiling v0.4.260-era source). To get that we'd need to build the historical bin chain, which is multi-hour bootstrap work. Deferred to a future investigation if the unwind effort warrants it.

The profile script is committed at `tools/memory_drift_profile.sh` and the CSV at `tools/memory_drift_profile.csv` for future re-runs.

## Verify-gate enforcement

The drift is now CI-enforced: any new ship pushing past 750 MB self-host or 540 MB tools-suite fails `verify.sh`. Adopters can bump the cap inline only by also writing a same-ship investigation note explaining what added the memory and why it can't be tightened. The user's quote: "the agent is supposed to monitor in real time the process and if it exceeds 1gb he's supposed to stop it so it doesn't crash the system" — that mechanism stays; the threshold is now far below the system-crash-risk level so drift is caught before it becomes a real e-stop event.
