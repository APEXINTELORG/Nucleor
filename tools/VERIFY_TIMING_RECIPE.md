# Verify Gate Timing Recipe (mandatory)

Every `bash tools/verify.sh` run records per-step timing data to
`tools/verify_timings.csv`. Checking that file before declaring any
release "done" is **non-negotiable** — multiple sessions have shipped
silent regressions that doubled or quadrupled the verify gate runtime
without anyone noticing because the gate's only signal is PASS/FAIL.

## What the CSV looks like

```
run_iso,index,seconds,status,name
2026-04-28T02:58:45Z,1,0.085,PASS,"binary present"
2026-04-28T02:58:45Z,2,1.178,PASS,"compiler ABI tables synced"
2026-04-28T02:58:45Z,3,4.068,PASS,"tools-suite rebuild"
...
```

- **One row per step per run**.
- `run_iso` is the UTC timestamp of the verify run that produced the row;
  multiple runs accumulate in the same file. Filter by `run_iso` to compare runs.
- File is **append-only**. Header is written on first creation only.
  Don't truncate it manually unless you really mean to start over.

Override the path with `NUC_VERIFY_CSV=path` if you want per-machine or
per-branch files.

## v0.5.17 — per-agent CSV namespacing

With three agents (main + parallel-1 + probe) potentially running verify
concurrently, set `NUC_VERIFY_AGENT=<name>` before invocation. The default
CSV path becomes `tools/verify_timings.<name>.csv` so writes don't race.

| Agent | Env | CSV |
|---|---|---|
| main | `NUC_VERIFY_AGENT=main` | `tools/verify_timings.main.csv` |
| parallel-1 | `NUC_VERIFY_AGENT=parallel1` | `tools/verify_timings.parallel1.csv` |
| probe | `NUC_VERIFY_AGENT=probe` | `tools/verify_timings.probe.csv` |

`NUC_VERIFY_CSV=<path>` overrides either default.

## v0.5.29 — full bisect-narrow protocol (run-to-run delta + 1 GB e-stop)

The protocol's primary signal is now **run-to-run delta** computed from
the CSV — not arbitrary thresholds. The 1 GB e-stop is a separate
hard ceiling that fires in real time during any sampled run.

### CSV schema (extended)

The CSV now contains two row types, distinguished by the `name` field:

- **Per-step row** (existing): `run_iso, index, seconds, status, name`
- **Run-summary row** (new): `run_iso, 0, wall_seconds, status, "__run_summary__", peak_mb, killed, last_index`

Per-step rows are written by `verify.sh` as before. Summary rows are
appended by `tools/run_with_peakmem.ps1` after the wrapped invocation
finishes. Both share the same `run_iso` so a run's per-step time data
ties to its peak-memory observation.

### Toolchain

- **`tools/run_with_peakmem.ps1`** — wraps a `verify.sh` invocation,
  polls subprocess-tree memory once per second (Get-Process, scoped to
  this session and StartTime ≥ launch), tracks peak, **kills the entire
  tree at 1 GB hard e-stop** (configurable via `-EstopMb`), appends a
  run-summary row to the CSV.
- **`tools/check_mem_regression.sh`** — reads the CSV, computes rolling
  per-step time stats (mean ± stddev) and per-run peak-mem stats over
  the last K runs (default 20), flags any step whose last run drifted
  past mean + N·stddev (default 2.5σ for time, 2.0σ for memory) AND
  any run whose peak_mb is more than 100 MB above the prior median.
  Excludes killed runs from the baseline (truncated → noise).
- **`tools/bisect_mem.sh`** — orchestrator. See "Tier 3 (mem hunt)" below.
- **`tools/verify.sh --range FROM-TO`** — primitive; runs only steps
  whose global step index falls in `[FROM, TO]` inclusive. Hierarchical:
  `[1-348] + [349-696] = full set`, `[1-174] ⊂ [1-348]`, etc.

### Routine flow (Tier 1) — never run sequential as a routine ship

```bash
# One concurrent run, sampled, peak-mem and per-step time recorded.
NUC_VERIFY_AGENT=main pwsh tools/run_with_peakmem.ps1 \
    -VerifyArgs "" \
    -EstopMb 1024 -PollMs 1000

# Did this ship drift?
NUC_VERIFY_AGENT=main bash tools/check_mem_regression.sh
```

If `check_mem_regression.sh` exits 0 → ship. If it exits non-zero, it
prints which steps drifted in time or which run drifted in memory.

### Tier 3 — memory excursion hunt (only when Tier 1 flags it)

```bash
NUC_VERIFY_AGENT=main bash tools/bisect_mem.sh --excursion-mb 600
```

Phase 1: full concurrent run, peak-mem sampled. If peak < threshold,
exit clean — no sequential. **Most ships stop here.**

Phase 2: split `[1, N]` into halves, run each concurrent. The half that
blew the threshold (or got killed by the e-stop) is the offender → recurse.

Phase 3: if neither half blew but the parent did → split into 4 quadrants,
run each concurrent. The combination that blows is interaction-bound.

Phase 4: when narrowed region size ≤ `--min-region` (default 16) →
final attribution pass with `-j 2` (low concurrency, preserves some
interaction) or `-j 0` if `--sequential-final`. Per-step memory is
attributed in this final pass. **The full sequential gate over 700
steps NEVER runs in this protocol.**

### Why this design

- **Concurrent + per-step CSV catches time excursions for free** —
  no re-run, no halving. `check_mem_regression.sh` reads the CSV.
- **Memory needs aggregate sampling** — per-step memory under
  concurrency is unattributable. So memory regression detection works
  per-run, and bisect narrows a *region*, not a step. The final small
  attribution pass identifies the step.
- **1 GB e-stop is system safety**, not regression detection. Different
  signals, both armed.
- **Run-to-run delta** beats absolute thresholds because a step that
  always uses 800 MB is fine; a step that jumps from 80 MB to 600 MB is
  the regression. Stats baseline catches that automatically.

### Multi-agent CSV namespacing (unchanged from v0.5.17)

Each agent writes to `tools/verify_timings.<agent>.csv`. `bisect_mem.sh`
and `check_mem_regression.sh` honor `NUC_VERIFY_AGENT`. Probe and
parallel-1 each have their own baseline.

## v0.5.26 — bisect-narrow protocol modes

Test count keeps growing (~696 steps as of v0.5.25, +2-5/hour during
active probe sessions). Re-running the full gate after every probe-finding
closure burns wall time; the per-step CSV makes targeted re-runs cheap.

**Tier 1 — default routine ship (concurrent + env-off):**

```bash
NUC_VERIFY_AGENT=main bash tools/verify.sh
# wall ~150-180s; PASS:696 expected; ship if PASS, otherwise pivot to Tier 2
```

**Tier 2 — re-run only failing steps (`--rerun-failed`):**

```bash
NUC_VERIFY_AGENT=main bash tools/verify.sh --rerun-failed
# Reads tools/verify_timings.main.csv; skips any step whose LAST status
# was PASS. Runs FAIL/SKIP/missing. Wall ~5-30s when most things passed.
```

Pass an explicit CSV path if you want to bisect against a different agent's run:

```bash
bash tools/verify.sh --rerun-failed tools/verify_timings.probe.csv
```

**Tier 4 — single-step verbose (`--only "<step>"`):**

```bash
NUC_VERIFY_AGENT=main bash tools/verify.sh --only "T1.7 bootstrap seed matches current compiler"
# Runs ONLY that step. All others SKIP. Wall ~5-15s.
# Step-name match is exact. Look up the canonical name from the CSV's `name` column.
```

Both modes filter the parallel-fixture loop too — fixture step names take
the form `test <dir>/<tname>` (e.g. `test features/rfc0014_max_depth_assoc_fn`)
or `negative <ename>` (e.g. `negative err_fmt_003_extra_args`).

**Tier 3 — quadrant bisect (planned, not yet shipped):** future ship will
add `--quadrant N/M` to split the parallelizable subset. For now,
`--rerun-failed` + `--only` covers most narrow-down workflows.

### Worked example

```bash
# 1. Routine ship: full gate
NUC_VERIFY_AGENT=main bash tools/verify.sh
# fails on step "T3.42 some new fixture"

# 2. Identify the failure from CSV
awk -F, '$4 == "FAIL"' tools/verify_timings.main.csv | tail -5

# 3. Re-run just the failure with verbose
NUC_VERIFY_AGENT=main bash tools/verify.sh --only "T3.42 some new fixture"
# investigate, fix code, re-run --only loop

# 4. Once fixed, re-run failed steps (catches collateral damage)
NUC_VERIFY_AGENT=main bash tools/verify.sh --rerun-failed
# if PASS, full gate one more time before ship
```

## How to check it after every run

```bash
# Top 20 slowest steps in the most recent run:
sort -t, -k3 -rn tools/verify_timings.csv | head -20

# Per-run total wall time:
awk -F, 'NR>1 {sum[$1]+=$3} END{for(r in sum) print r, sum[r]"s"}' \
    tools/verify_timings.csv

# Track a specific step over time:
grep '"compiler ABI tables synced"' tools/verify_timings.csv

# Distribution of step durations:
awk -F, 'NR>1 {
    if($3<0.1) b="<0.1s";
    else if($3<0.5) b="0.1-0.5s";
    else if($3<1.0) b="0.5-1.0s";
    else if($3<3.0) b="1.0-3.0s";
    else if($3<10.0) b="3.0-10s";
    else b=">10s";
    c[b]++; t[b]+=$3
} END {for(b in c) printf "%-10s : %3d steps, %7.2fs\n", b, c[b], t[b]}' \
    tools/verify_timings.csv | sort -k7 -rn
```

The live ticker also shows timings now — every `[N/450] OK <step>` line
gets a `( N.NNs)` suffix so you can spot slowdowns as they happen.

## Baseline (v0.4.22 — 2026-04-28)

- 450 steps, 448 PASS / 2 FAIL (memory budget items, pre-existing)
- **Total: 325s (5.4 min)**
- Median step: **0.609s**
- p99: 5.0s, max: 27.5s

### Top 5 slowest steps to be aware of

| Step | Time | Why it's slow | Possible optimization |
|---|---|---|---|
| `nuc explain — full spec code set wired` | 27.5s | spawns ~130 subprocesses (one per error code) | batch into one `nuc explain --all` invocation |
| `no UTF-8 mojibake in source/docs` | 16.8s | full repo file scan, possibly per-file iter | single byte-pattern grep |
| `self-host memory budget (<= 100 MB)` | 5.7s | full self-host with NUC_TRACE_ALLOC=1 | reuse the IR from `self-host rebuild closes` |
| `self-host rebuild closes` | 5.5s | full self-host build | (foundational; can't speed) |
| `T1.7 bootstrap seed matches current compiler` | 5.0s | another full self-host build | cache the IR from the prior step |

The 3 self-host-class steps (5.7s + 5.5s + 5.0s = 16.2s) all rebuild
the compiler from source. Caching the IR across them would save ~10s.

## When to investigate

- **Total wall time grew >15%** vs the prior run on the same machine
- **Any single step jumped >2x** vs its earlier baseline
- **Verify hangs** (no live ticker advancing for >60s) — interrupt, kill
  `nucleor*` and `clang*` processes, look at the partial CSV to see
  which step blocked

## Why this is mandatory

Silent runtime regressions caused by:
- Static-array bloat in the runtime (e.g., `g_inst_recycle[65536]`)
- Per-call counter writes added to hot paths (e.g., `g_vec_cap_hist`)
- Over-broad panic statements in the s1 compiler that abort otherwise-fine fixtures
- File-lock retry loops compounding across many compile spawns
- Subprocess fan-out (each `nuc <subcommand>` invocation has fixed Windows process-creation overhead)

…all hide in the long tail of 450 sub-second steps. The CSV makes them
visible. The user has been burned multiple times by 30-second cycles
becoming 7-minute hangs without warning. The CSV is the early warning.

**Check it every time. Don't ship without checking.**
