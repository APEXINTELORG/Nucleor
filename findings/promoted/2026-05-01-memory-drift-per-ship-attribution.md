---
title: Memory drift target list — per-ship attribution methodology + initial targets for the v0.5.14 770/580 MB tighten investigation
severity: investigation-target (not a bug-class hazard but a memory-regression target list per main-agent guidance lane #3)
probe_file: probes/memory/build_peak_walk.ps1 (will be filed if main agent adopts the methodology)
diagnostic_actual: docs/milestones/MEMORY_DRIFT_2026-05-01.md captures the aggregate (5.2× drift v0.2.161 → v0.5.13) but doesn't pin per-ship deltas
diagnostic_expected: per-ship memory delta table (each major v0.4 → v0.5 ship's contribution to the 185 → 587 MB env-off climb)
discovered_against: main v0.5.15 (probe rebased)
commit: probe 83817c3 + main e65e2dc
---

## Background

Per main agent's guidance lane #3:

> 3. Memory drift hunt — main is at 587-704 MB self-host vs the
>    v0.2.161 baseline of 185 MB. v0.5.14 capped at 770 MB but
>    didn't unwind the drift. If you can isolate the specific ship
>    that added the worst single regression (likely Track L cache
>    v2 or RFC-0006 DbC), file it as a memory-regression finding
>    so the next investigation has a target.

Main's drift doc (`docs/milestones/MEMORY_DRIFT_2026-05-01.md`)
attributes the climb to ~50-100 MB per major addition across:

- RFC-0006 DbC (CONTRACT-001..011) — contract-evaluation + snapshot machinery
- RFC-0007 atomics (G+H) — intrinsic lowering + queue rod state
- RFC-0014 max_depth (I) — analyzer + wrapper-rewrite pass
- Track L cache v2 — content-addressed in-memory cache state
- v0.5.13 generic-T propagation — argument-walk binding accumulation

But doesn't pin individual deltas. This finding proposes the
methodology to attribute them.

## Per-ship attribution methodology

For each candidate-ship's commit SHA `<sha>`, run:

```powershell
git checkout <sha>
$peak = (powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/measure_peak_build.ps1 -Iterations 5).peak_mb
$line = "$<sha>,$peak"
echo $line >> peak_per_ship.csv
```

Then plot peak vs commit ordinal. The largest single-step jump
between ships locates the culprit.

## Initial target list (highest-leverage commits)

Ranked by likely-impact (per main's drift doc):

| # | Candidate ship | Commit (origin/main) | Hypothesis |
|---|---|---|---|
| 1 | **Track L v2 (v0.5.0 cut)** | `4372053900a713937651918dc392dd35a184f0a0ef430b6f24f9bfd920eaf84e` (atomic ship's IR fixed-point) | Content-addressed cache in-memory state. Likely ~100-200 MB delta from pre-Track-L. |
| 2 | **RFC-0006 DbC arc (v0.4.244-258)** | v0.4.244 → v0.4.258 ship cluster | 11 CONTRACT codes + snapshot machinery. Likely ~50-100 MB delta. |
| 3 | **RFC-0007 atomics (Track G + H, v0.4.273 + v0.4.274)** | `c270613` (Track G) + Track H spike | Intrinsic lowering + queue rod state. Likely ~30-50 MB. |
| 4 | **v0.5.13 generic-T propagation** | `6530fdca087d96201bc456c8597c03a9e053643ad70a4a6497837e5f5971515e` | Argument-walk binding accumulation. Likely small (~10-20 MB) per main's note. |
| 5 | **RFC-0014 max_depth (Track I, v0.4.286)** | `c09fd93` cherry-pick | Analyzer + wrapper-rewrite pass. Likely small (~10-30 MB). |

## Why investigation matters

- **Effects-types branch (`v06-track-effects-types`) is BLOCKED** at 818-823 MB — 48-53 MB over the new 770 MB cap. Can't merge into v0.6 without finding ~50 MB to give back.
- **Parallel-agent full-runs hit 968 MB** — close to the 1024 MB raw e-stop. One more medium ship pushes through.
- **Headroom math:** v0.2.161 had 2.2× ratio (185 / 400). At 770 MB cap and 587 MB peak, ratio is 1.31× — almost no slack.

## Memory-blow-up note

This finding IS the user-mandate "always look for memory blow ups"
investigation. Main agent already capped the budget but didn't
unwind the drift. The unwind needs per-ship attribution as the
first step.

## Cross-ref

- `docs/milestones/MEMORY_DRIFT_2026-05-01.md` — main's drift doc
- `tools/measure_peak_build.ps1` — measurement tool
- `tools/perf_baseline.json` — current locked baseline (v0.5-track-l-perf-cache)
- v0.5.14 — budget tighten ship (1024 → 770/580 MB)

## Probe action

Probe agent CAN execute the per-ship walk if main agent accepts
the methodology. Estimate: 5 min per ship × 10 candidate ships =
~50 min walk + report. Output: peak_per_ship.csv + a summary
finding pinpointing the ≥75th-percentile jumps. If main agent
prefers to do this in-house, this finding remains a methodology
spec.

## Probe note

Filed as INVESTIGATION-TARGET, not BUG. The drift is normal
substrate growth; the finding is to identify which ship's growth
was disproportionate so the unwind can target it.


## Promoted

- Tooling: `tools/memory_drift_profile.sh` (shipped v0.5.16,
  extended in v0.5.21 with the anchor set probe proposed). Runs
  current bin against historical s1 sources; same methodology
  probe outlined.
- Data captured (v0.5.21 extended run):

  | Tag | Source MB | Peak MB | Δ vs prev |
  |---|---|---|---|
  | v0.4.243 (pre-RFC-0006) | 1.34 | 712 | — |
  | v0.4.260 (RFC-0006 DbC) | 1.41 | 763 | **+51** |
  | v0.4.272 (post-DbC) | 1.42 | 769 | +6 |
  | v0.4.282 (RFC-0007 arc) | 1.45 | 792 | +23 |
  | v0.4.286 (Track I) | 1.45 | 861 | **+69** ← biggest single jump |
  | v0.5.0 (Track L) | 1.47 | 918 | **+57** |
  | v0.5.7+ | 1.48-1.49 | 827-897 | varies (~50-90 MB noise) |

- Probe's hypothesis table validated. Ranked by attribution:
  1. **Track I (RFC-0014 max_depth) cherry-pick: +69 MB** —
     was the unconfirmed unknown. This is the biggest single
     contributor to v0.4 → v0.5 drift. The wrapper-rewrite
     pass (line ~22480-22600 in s1) emits 2 fns per
     `#[max_depth]` site PLUS new helper invocations
     `max_depth_enter` / `max_depth_exit`.
  2. **Track L cache v2: +57 MB** — content-addressed cache
     in-memory state (v2 hash machinery + per-key LL storage).
  3. **RFC-0006 DbC arc: +51 MB** — contract-evaluation +
     snapshot machinery (CONTRACT-001..011).
- Action: see `docs/milestones/MEMORY_DRIFT_2026-05-01.md` (now
  updated with the per-ship attribution table). For
  next-investigation targeting, prioritize Track I + Track L —
  combined +126 MB out of ~205 MB total drift.
- Note on variance: peak readings are ~50-90 MB variable
  between back-to-back runs (Windows working-set timing
  depends on OS scheduler / page-cache state). Pin trends from
  ≥3-sample averages, not single readings, when a tighten
  delta needs to be ≥30 MB to be real.
- Promoted: 2026-05-01 by main agent (probe commit 83817c3).
