# Perf-Regression Fix Brief — v1.0.2 → sub-4s cold compile

**Branch:** `fix/perf-regression-2026-05-09`
**Base:** v1.0.2 tag (commit `296ab6c4`)
**Target:** cold self-host compile sub-4s on Windows AND Linux

## Problem

v1.0.2 ships clean (PASS=1589 / FAIL=0) but the cold self-host compile is **22 seconds on Windows** (vs v1.0.0 baseline of ~4s). Cloud agent's verify ran clean on Linux but didn't enforce a perf gate.

## Per-phase breakdown (Windows, stage1 bin × v1.0.2 source)

| Phase | v1.0.0 baseline | v1.0.2 current | Slowdown |
|---|---|---|---|
| resolve_source | 141 ms | **5766 ms** | 41× |
| lex | 62 ms | **8719 ms** | 140× |
| ownership | 1062 ms | 1922 ms | 1.8× |
| type | 625 ms | 813 ms | 1.3× |
| type call_expr | 3644 ms | **6598 ms** | 1.8× |
| **Total** | **~3032 ms** | **~22000 ms** | **7×** |

The slowness is in v1.0.2 SOURCE code added by L1/L2/L4. Specifically:
- L4 added ~520 lines to `fn lex` (BOM check, F-066 silent-byte fix, depth limit, NUL byte rejection, hex/float overflow checks, char-literal disambiguation, smart-quote / zero-width / non-ASCII detection, etc.)
- L1 added type-flow + call_expr profiling work
- L4 also added work to `resolve_source_with_records_active` (parse_depth tracking)

## Bootstrap state on this branch

`bin/nucleor.exe` is a Windows PE built locally as a stepping-stone:
- Source: v1.0.2 source compiled by L4 worktree's bin (`bin/nucleor.exe.bootstrap` checked into the branch for reproducibility)
- 14 `__nucleor_*` externs missing from L4 bin's emit_externs were added via `/tmp/missing15.ll` patch + a forwarding shim for `diag_exit() → __nucleor_diag_exit()`
- Stage1 bin md5: `508419822321b5becbb6191d8a4102f8`
- Reports `nucleor 1.0.1` (version label was bumped 1.0.0 → 1.0.1 by the agent, never to 1.0.2)

The stage1 bin works (smoke OK), but cold self-host is still 22s — the perf cost is in the source's lex/resolve_source/type code that gets compiled into ANY bin built from v1.0.2 source.

## Required reading

- `compiler/nucleor_s1_compiler.nr` lines 295-1300 — `fn lex` (massively expanded by L4)
- `compiler/nucleor_s1_compiler.nr` line 34331 onward — `fn resolve_source` + `_with_records_active`
- `compiler/nucleor_s1_compiler.nr` — search for `__nucleor_parse_depth_inc` call sites (3258, 4240, 35339) — these are L4's recursion-depth tracking inserted into parse_expr/parse_stmt

The audit findings (the source of truth for what each lane was supposed to fix) are at the v1.0.0 + audit-findings branch on archive: `audit-findings-2026-05-09` (tip `36d126b3`).

## What needs to happen

Surgically optimize each slow phase WITHOUT regressing FAIL=0. Target sub-4s cold.

Suggested attack order:

1. **lex (8.7s → target <500ms)** — instrument internally first (add `print_phase_time` calls at intermediate points within `fn lex` to find which sub-section is slow), then optimize. Hypotheses: per-byte calls to a slow helper, accumulated branch overhead from many new `else if` cases, possibly a per-char `str_concat` hidden somewhere. The whole-function profile says 3.6 µs/char vs v1.0.0's 0.026 µs/char — 138× per-char regression. Find what got added that runs on EVERY char.
2. **resolve_source (5.7s → target <300ms)** — likely parse_depth tracking running per parse-recursion. Check call frequency. Each `__nucleor_parse_depth_inc()` is cheap but if called millions of times, accumulates.
3. **call_expr (6.6s → target <2s)** — type-checker's per-call work. L1 added type-flow analysis. If any new check runs per call AND scales with N, it's the issue.

After each fix:
- Rebuild bin from source
- Cold compile + measure
- Verify still passes (FAIL=0 must hold)
- Commit one fix at a time

## Hard rules

- Stay on `APEXINTELORG/Nucleor-archive`. NEVER push to `APEXINTELORG/Nucleor`.
- Sub-4s cold compile is the SHIP GATE.
- FAIL=0 must hold after every fix.
- Self-host fixed-point md5 must hold post-final-rebuild.
- All commits include `Co-Authored-By: <model> <noreply@anthropic.com>`.

## When done

- Bump `compiler_version_label` "1.0.1" → "1.0.3" in `compiler/nucleor_s1_compiler.nr` + `compiler/nucleor_tools_suite.nr`
- Add CHANGELOG `[1.0.3]` block
- Tag `v1.0.3` (annotated, ON THE ARCHIVE)
- Push branch + tag to `origin` (the archive)

## Optional later (separate branch)

- Cherry-pick F-CONC-006 + F-CONC-007 Windows parity from `fix/integrator-local-windows-parity-2026-05-09` (`4c1da4ce`) — these are runtime C edits, won't affect perf.

## Honest reporting

Report final cold + hot self-host times, per-phase breakdown, verify counts, self-host fixed-point md5, what optimizations landed, what was rejected as too risky.
