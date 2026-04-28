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
