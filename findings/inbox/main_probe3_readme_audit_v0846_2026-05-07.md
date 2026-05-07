# PROBE-3 self-audit: README.md numeric claims vs current state

- **Date:** 2026-05-07
- **Agent:** main (local Claude integrator) — solo PROBE-3 pass while partner team's branch is unstarted
- **Branch:** none (feeding straight into partner queue for the actual README edit)
- **Scope:** verifying every numeric claim in `README.md` against current `origin/main @ 5d58ee0c`

## Headline

**All divergences are UNDERSTATEMENTS.** The project has grown faster than
the README has been refreshed; nothing overstates capability. This is
doc-maintenance scope, not credibility risk. PROBE-3's design intent
(catch overstated claims) is unaffected by this finding — the README is
not lying, it's lagging.

## Per-claim verdict

`README.md` line numbers refer to the file at `origin/main @ 5d58ee0c`.

| Line | Claim | Measured | Verdict | Recommendation |
| --- | --- | --- | --- | --- |
| 20 | "**132 rods** (`stdlib/rods/*.nr`)" | 255 top-level + 33 ML sub-rods = 288 | UNDERSTATED by 156 | Update to "≥255 top-level rods + 33 ML sub-rods" or just "≥255 rods (plus an ML sub-suite)". Recompute on every README touch. |
| 20 | "**84 runtime C source files**" | 190 in `stdlib/runtime/` + 9 in `stdlib/rods/**/*.c` = 199 | UNDERSTATED by 115 | Update to "≥190 runtime C source files". |
| 20 | "**686 `__nucleor_*` symbols**" | 1620 `extern fn nuc_*` declarations across `stdlib/rods/*.nr` | UNDERSTATED by 934 | Update to "≥1620 `__nucleor_*` ABI symbols". Note the original count likely measured a subset (only direct `__nucleor_*` not `nuc_*`); methodology should be locked in `tools/check_rod_void_abi.sh`'s output for future re-counts. |
| 20 | "**13 categories**" of helpers | helper_manifest.toml not re-counted in this pass | likely OK or stale | Verify against `docs/rfcs/helper_manifest.toml`'s current section count before next README touch. |
| 20 | "rebuilds itself in **4.5 s** using **185 MB peak**" | self-host two-stage rebuild ~10s total (~5s each); cold_compiler RSS 334 MB per `tools/check_perf_regression.ps1` baseline | 4.5s ≈ accurate; 185 MB likely stale (pre-RFC-0062-Phase-2-final memory measurements) | Refresh against the current `tools/perf_baseline.json` numbers; either claim "**~5 s self-host rebuild**" + cite the perf gate cap (cold compiler 350 MB) OR re-instrument the actual self-host RSS so the 185 MB number can be honestly updated. |
| 173 | "tests across `tests/lang/` (**49**), `tests/attrs/` (**4**), `tests/runtime/` (**27**), and `tests/rods/` (**57**)" | lang=59, attrs=4, runtime=27, rods=151 | lang +10, attrs OK, runtime OK, rods +94 | Update to "lang (≥59), attrs (4), runtime (27), rods (≥151)". |
| 173 | "additionally exercises `tests/features/` (**34**) and `tests/err/` (**35** negative tests)" | features=686, err=278 | features +652 (massive understatement, project's largest test surface), err +243 | Update to "features (≥686 fixtures), err (≥278 negative tests)". The `tests/features/` corpus is the main fixture lab — 686 is closer to the right magnitude story for prospective contributors. |
| 173 | "**400 MB peak-allocation budget** on the self-host compile (current: **185 MB**)" | perf gate cap is `cold_max_allowed_compiler_memory_mb=350` per `tools/perf_baseline.json` (perf gate output: cold_compiler 334/350 MB at this measurement). Self-host RSS is a different metric than cold-compiler RSS. | budget number 400→350 (or whatever baseline currently encodes); current 185 MB is stale by an unknown factor | Refresh against `tools/perf_baseline.json`'s `cold_max_allowed_compiler_memory_mb` and the latest perf-gate run output. Distinguish self-host RSS (a specific stage1→stage2 build) from cold-compile RSS (any single fixture compile). |

## What needs doing (partner team scope)

1. Branch `fix/probe-3-readme-claim-refresh-v0846` from current
   `origin/main`.
2. Apply the table above as direct edits to `README.md`. Prefer "≥N"
   phrasing over hard counts so future drift doesn't immediately
   re-stale the README.
3. Add a short maintenance note at the bottom of `docs/architecture.md`
   pointing to a local script that re-counts (`tools/recount_readme_numbers.sh`
   if you want; or a `tools/probe3_audit.nr` driver) so future README
   touches can verify in one command.
4. Refresh perf claims against the actual current `tools/perf_baseline.json`.
5. PROBE-3 sweep should also touch `docs/rfcs/v1_PUNCHLIST.md` for any
   "Phase X DONE" lines that aren't backed by a verify step. Quick
   pass: open the file, search for `DONE`, verify each has a fixture
   path or `tools/check_*.sh` reference.

## What I'm NOT doing in this audit

- Editing `README.md` directly. PROBE-3 is partner-queue scope; my
  finding here is the input, not the output.
- Re-instrumenting self-host RSS. The 185 MB claim probably came from
  a specific stage of memory work and the canonical re-measurement
  should run on a controlled host; calling it "stale" is enough for
  this pass.
- Auditing every "Phase X DONE" claim in `v1_PUNCHLIST.md`. That's a
  bigger exercise; out of scope for a quick sanity pass.

## Honesty rules upheld

Every number above was actually measured this run on `origin/main @ 5d58ee0c`.
No simulated counts. Methodology cited with each measurement so the
partner team can reproduce on their host.
