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

## Windows RSS e-stop discipline

On Windows, `NUCLEOR_MEM_CAP_KB` / Git Bash `ulimit` is not the crash guard.
For long compiler or verify runs, use the PowerShell process-tree watchdog:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\run_verify_rss_estop.ps1 `
  -Jobs 1 -BudgetMb 1000 -WarningMb 800 -SampleMs 100 `
  -RunName verify_local_iter
```

- `BudgetMb 1000` is an emergency stop. If the launched process tree crosses
  it at any sample, the watchdog kills the tree immediately and exits `99`.
- `WarningMb 800` is already a serious regression signal; do not normalize it.
- Keep iteration runs at `-Jobs 1` or `NUC_VERIFY_JOBS=1` unless the work is
  specifically about parallel verify behavior. Parallel fixture workers stack
  compiler resident sets and can hide which edit caused the peak.
- The wrapper sets `NUCLEOR_MEM_CAP_KB=0` internally so Git Bash virtual-memory
  behavior does not conflict with the real resident-memory watchdog.
- Job-object containment is opt-in with `NUC_RSS_USE_JOB=1`. The default uses
  parent-process-tree RSS sampling because Job assignment can cause self-host
  compiler shutdown hangs on this Windows toolchain.
- The RSS summary reports multiple memory views:
  - `process_tree_peak_mb`: launched compiler plus descendants such as
    `clang` / `lld`; this remains the safety/e-stop view.
  - `compiler_peak_mb`: Nucleor compiler processes only; this separates
    compiler drift from linker/runtime-toolchain variance.
  - `peak_mb`: compatibility alias for `process_tree_peak_mb`.
- The watchdog writes stdout/stderr logs under `target/` plus the normal
  `NUC_VERIFY_CSV` timing rows, so the killed step remains diagnosable.

## POSIX RSS e-stop discipline

On Linux hosts, `tools/verify.sh` and `tools/verify_fast.sh` can enforce the
same memory-budget contract with `tools/run_capped.sh`. The wrapper starts the
compile in a new process group with `setsid`, samples the Linux `/proc`
process tree, and kills the group if total RSS crosses the budget.

Direct smoke examples:

```bash
bash tools/run_capped.sh --budget-mb 512 --label success-smoke -- sleep 0.2
bash tools/run_capped.sh --budget-mb 1 --label estop-smoke -- sleep 2
```

The second command should exit `99` after killing the process group. If the
host is not Linux `/proc`, or if `setsid` is unavailable, the wrapper exits
`96` and reports `UNSUPPORTED`.

WSL interop is not valid POSIX RSS evidence for `bin/nucleor.exe`: Linux
`/proc` sees the Windows bridge process, not the real Windows compiler and
`clang` process tree. In that case the wrapper exits `96`. Use the PowerShell
sampler for Windows `.exe` builds, or run the POSIX wrapper against a native
Linux compiler binary.

The verify memory-budget steps still prefer the PowerShell process-tree
sampler when it is visible, which preserves the Windows safety path. To prove
the Linux `/proc` path specifically, force it:

```bash
NUC_VERIFY_FORCE_POSIX_RSS=1 bash tools/verify.sh --only "self-host memory budget (<= 770 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
NUC_VERIFY_FORCE_POSIX_RSS=1 bash tools/verify.sh --only "tools-suite memory budget (<= 580 MB; tight cap, see docs/milestones/MEMORY_DRIFT_2026-05-01.md)"
```

`NUC_TRACE_ALLOC=1` remains useful for allocation forensics, but it is no
longer an acceptable green path for these memory-budget gate steps. If neither
the PowerShell sampler nor the Linux `/proc` wrapper is available, the step
must fail unsupported rather than silently passing a soft allocation proxy.

## R10-D3 POSIX cold/hot perf gate prep

`tools/check_perf_regression.sh` is the POSIX/Linux counterpart shape for
the Windows cold/hot self-build perf gate. It requires a native Linux host,
Linux `/proc`, `setsid`, `clang`, a native `bin/nucleor`, and
`tools/run_capped.sh`. It intentionally refuses WSL evidence so a Windows
`.exe` launched through interop cannot be mistaken for real POSIX process-tree
RSS.

Native Linux validation flow:

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

The doctor mode is a preflight only. It prints one readiness line for the
native Linux kernel, `/proc`, shell tools, `clang`, `tools/run_capped.sh`,
baseline/source files, native `bin/nucleor`, and ELF proof when `file` is
available. Unsupported hosts and missing native prerequisites exit `96`.

The script clears `target/` and `.nuc_cache/` before each cold sample and
requires `cache: miss`; it runs the hot samples without cleanup and requires
`cache: hit`. Timing is reported as the median sample wall time. Memory is
enforced as Linux process-tree RSS from `tools/run_capped.sh` against
`cold_max_allowed_memory_mb` and `hot_max_allowed_memory_mb`.

Compiler-only RSS remains a distinct Windows-only split in this prep branch.
The POSIX prep gate prints `cold_compiler=n/a` and `hot_compiler=n/a` rather
than pretending Linux `/proc` process-tree RSS is the same measurement. R10-D3
should not be marked closed until a native Linux runner transcript exists and
the team decides whether POSIX compiler-only RSS parity is required or
process-tree RSS is the accepted POSIX contract.

`tools/verify.sh` includes this as `T1.8 POSIX perf + memory regression
monitor`. On unsupported hosts the standalone script exits `96`; `verify.sh`
maps that to an explicit `SKIP` so Windows and shell-check-only hosts do not
claim POSIX perf evidence.

## R06 rust_bridge ownership harness

`tools/check_rust_bridge_ownership.ps1` and
`tools/check_rust_bridge_ownership.sh` are opt-in harnesses for the Rust
bridge string ownership path. They are not wired into `verify.sh` or
`verify.ps1`. Use them when changing `stdlib/rods/rust_bridge`,
`stdlib/rods/rust.nr`, or the `rust_free_str` ownership convention.

Windows validation:

```powershell
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Doctor
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 -Iterations 100
pwsh -NoProfile -File tools\check_rust_bridge_ownership.ps1 `
  -Fixture tests\features\rust_bridge_string_free_repeat_smoke.nr `
  -Iterations 100
```

POSIX validation:

```bash
bash tools/check_rust_bridge_ownership.sh --doctor
bash tools/check_rust_bridge_ownership.sh --iterations 100
bash tools/check_rust_bridge_ownership.sh \
  --fixture tests/features/rust_bridge_string_free_repeat_smoke.nr \
  --iterations 100
```

The normal run builds `stdlib/rods/rust_bridge` with `cargo build --release`
when the release artifact is missing, builds the focused fixture, then runs the
resulting executable repeatedly. Missing `cargo`, missing crate files, missing
compiler binary, fixture build failure, or any nonzero fixture run is a hard
failure.

| Host path | Expected bridge artifact | Compiler binary | Harness |
|---|---|---|---|
| Windows | `stdlib\rods\rust_bridge\target\release\nucleor_rust_bridge.lib` | `bin\nucleor.exe` | `tools\check_rust_bridge_ownership.ps1` |
| POSIX Linux/macOS | `stdlib/rods/rust_bridge/target/release/libnucleor_rust_bridge.a` | `bin/nucleor` | `tools/check_rust_bridge_ownership.sh` |

`tests/features/rust_bridge_string_free_smoke.nr` is the narrow legacy
fixture: each run performs 100 alloc/free cycles through
`rust_to_uppercase`/`rust_regex_find`. The broader repeat fixture
`tests/features/rust_bridge_string_free_repeat_smoke.nr` covers all seven
string-returning Rust bridge functions and performs 700 alloc/free cycles per
fixture process run.

## v0.8.317 — cold/hot memory split for the perf gate

`tools/check_perf_regression.ps1` now reads the split RSS fields and enforces
four memory ceilings independently:

- cold process-tree memory: `cold_max_allowed_memory_mb`
- cold compiler-only memory: `cold_max_allowed_compiler_memory_mb`
- hot process-tree memory: `hot_max_allowed_memory_mb`
- hot compiler-only memory: `hot_max_allowed_compiler_memory_mb`

`tools/perf_baseline.json` keeps `cold_peak_memory_mb` as a compatibility
alias for cold process-tree memory, but new automation should prefer
`cold_process_tree_peak_memory_mb`, `cold_compiler_peak_memory_mb`,
`hot_process_tree_peak_memory_mb`, and `hot_compiler_peak_memory_mb`.
This matters because a clang/lld or Defender-induced process-tree spike is a
different problem from a compiler allocation regression, and a hot-cache memory
excursion should not be hidden by the larger cold-cache ceiling.

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
  polls memory once per second from the launched `bash` tree plus
  repo-rooted Git-Bash/MSYS workers started during the same run, tracks
  peak, **kills the verify workload at 1 GB hard e-stop** (configurable
  via `-EstopMb`), appends a run-summary row to the CSV.
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
| `self-host memory budget (<= 100 MB)` | 5.7s | historical v0.4.22 full self-host with old NUC_TRACE_ALLOC=1 path | reuse the IR from `self-host rebuild closes` |
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
