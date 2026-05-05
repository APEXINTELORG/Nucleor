# Parallel Agent Assignment — post-v0.8.251 (2026-05-05)

**Status:** P2/R2 source-level prefix helper hot-path reduction DONE. Both
your perf commits (`5aabd9dd` ownership metadata key allocation +
`336a9186` starts-with prefix length helper) are live on `origin/main`
since v0.8.251. **MAIN_RESCUE_HANDOFF_v0.8.250_2026-05-05.md is no longer
load-bearing** — the `OWN-008 priv_mangle_private_fns` failure on
unpatched `347c5f46` is moot because main now has both perf commits
+ v0.8.251 on top of them, and `bash tools/check_self_host_md5.sh`
passes at md5 `7b4966b9b69526674ef5ce3208a8274e`.

## Recap of what shipped from your work

- v0.8.249 → v0.8.251 includes both your cherry-picks rebased onto current
  main. Self-host fixed-point holds.
- Perf gate: cold 3.55s median accepted, hot 0.32s, peak 299 MB.
- Verify: known-quirky 28 failures (improved from 30 baseline; you
  fixed 2 pre-existing fails as a side-effect).

## Context: what main agent (Claude) is doing

1. **Audit in flight** — Codex GPT-5.5 is auditing the 14-pillar RFC corpus
   at `Desktop\Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\`
   (heartbeat at that path's `heartbeat\heartbeat.json`). **Do not duplicate
   the headline-verification work** — the auditor owns that lane.
2. **Main agent ship lane:**
   - kv_cache 4-vs-5-arg fix (your finding `kv_cache_arity_mismatch_2026-05-05.md`)
   - typ-026 expr-stmt-with-semi formal disposition (spine §8.4 #3 orphan)
   - Rod-fixture sweep continuation: control + vision tranche (`bicycle`,
     `mecanum`, `purepursuit`, `dwa`, `fast_corner`, `harris`, `hough`,
     `hough_circle`, `klt`, `ransac`, `hull`, `delaunay`, `icp`, `pnp`, `quat`)
   - Probe-inbox audit/drain
3. **Audit-deferred lane** (main agent will NOT single-session these — audit
   may rewrite fix paths): NUM-G1, LAW-1, FFI-1, PKG-1, R7 frame-typing,
   RFC-0062 Wave B G-2/G-4–G-8.

## Your next assignment — three independent tracks, pick by bandwidth

These were chosen specifically to not overlap with main agent's lane,
not overlap with Codex's audit, and not gate either of them.

### TRACK A (PRIMARY) — Cross-rod extern-signature arity-mismatch sweep

**Class:** silent-miscompute hunting, your existing strength.

**Why:** Two known bugs in this class have shipped:
- v0.8.45 ML-1 attention2: rod 6-arg → C 7-arg (seq_q/seq_k split). Fixed.
- 2026-05-05 kv_cache: rod 4-arg → C 5-arg (start_pos/end_pos pair). Found,
  fix scheduled for next ship.

**Hypothesis:** more drift exists. The C runtime evolved, rod externs
weren't re-synced. With ~248 rods × multiple externs each, manual review is
high-cost; mechanical sweep is cheap.

**Task:** for every `extern fn nuc_*(...)` declaration in `stdlib/rods/*.nr`,
cross-check the arg count + arg types against the matching C function in
`stdlib/runtime/*_rt.c`. Output per-mismatch finding to
`findings/inbox/extern_arity_drift_<rod>_2026-05-05.md` using the standard
probe template. Severity classification:

- **CRITICAL** — silent miscompute (rod underspecifies args, C reads
  garbage stack).
- **HIGH** — rod overspecifies args (extra args silently dropped, but
  semantics may still be wrong if C doesn't expect them).
- **MEDIUM** — type drift (e.g., rod declares `i64` for what C treats as
  pointer — usually safe on Windows x64 but may break on other targets).

**Method:**
1. `grep -rn "extern fn nuc_" stdlib/rods/` → arity table.
2. For each, find matching C decl in `stdlib/runtime/`. Use ctags / `grep -rn`
   on the function name.
3. Diff arg counts and arg types.
4. For each mismatch, write a finding with: rod path:line, C path:line,
   the diff, hypothesis on impact, suggested fix (B-shim non-breaking
   preferred, A-rod-update for breaking changes).

**No compiler/runtime edits.** Findings only. Main agent ships fixes
in version cadence.

**Acceptance:** N findings dropped to inbox where N ≥ 0 (zero is fine —
that's a clean signal too). Coverage: every `nuc_*` extern in rods/.
Heartbeat phase: `arity_sweep_complete`.

### TRACK B (ALTERNATIVE) — RFC-0062 G-1 Phase 2b-3-trace H1-H4 hypothesis tracing

**Class:** compiler debug-print investigation, no compiler edits in your
worktree (you propose, main ships).

**Status:** still open from `_parallel_agent_assignment_v0843.md` Option B.
Main agent has not picked it up; the audit will not address it (RFC-0062
is in-tree, not in the audit's RFC corpus).

**Hypotheses (re-stated from `RFC-0062-IMPLEMENTATION-PLAN.md` §3 G-1 lines 65–88):**

- (H1) `name_in_auto_drop` for the candidate fns is NOT being called from
  `lower_fn` (maybe an earlier dispatch routes the fns elsewhere)
- (H2) `name_in_auto_drop` returns 1 but `__auto_drop_enabled` sym isn't
  being set (maybe overwritten by a later sym_init call)
- (H3) `auto_drop_register` is called but `auto_drop_helper_for_type(tstr)`
  returns `""` because tstr doesn't match `Vec<...>` / `HashMap<...>`
- (H4) `auto_drop_register` registers correctly but `auto_drop_emit_live`
  isn't called at the right return path for these fns

**Task:** add targeted debug-prints (eprintln! to stderr) at each of the four
sites in a worktree branch. Run the v0.8.x compiler with
`NUC_AUTO_DROP_DEFAULT=1` against the 89 candidate fns from
`tools/auto_drop_safety_audit.txt` (or equivalent). Capture output. Identify
which hypothesis fires.

**Output:** finding to `findings/inbox/g1_default_flip_2b3_trace_2026-05-05.md`
with: (a) which sites fired which times, (b) the answer to H1/H2/H3/H4,
(c) proposed Phase 2b-3 fix (concrete file:line edits for main agent).

**Acceptance:** root cause identified; fix path proposed.

### TRACK C (PERF HYGIENE) — verify.sh redundant-gate collapse audit

**Class:** verify-time reduction, no semantics change.

**Why:** v0.8.23 collapsed a BR-7 3-scan to single-pass. Other registry
entries may have similar redundancy. Cold compile is at 3.55s median;
verify gate is the longer-running one (per `feedback_nucleor_verify_timing.md`
baseline 325s/450 steps).

**Task:** profile current `tools/verify.sh` per-step timings (your CSV at
`tools/verify_timings.<agent>.csv` is the source of truth). Identify
top-10 slowest steps. For each, look for redundant scans / per-call helpers
that could be lifted out.

**Output:** finding `findings/inbox/verify_perf_audit_2026-05-05.md` with
the top-10 table + per-step proposed collapse + estimated savings.

**No verify.sh edits in this track.** Main agent ships.

**Acceptance:** top-10 ranked + per-step collapse hypothesis dropped.

---

## Recommendation

**TRACK A (cross-rod arity sweep) is the highest-value standalone work.**
The two known bugs in this class were both real silent miscomputes that
shipped. There is high prior probability that more exist. Mechanical
sweep is cheap, deterministic, and the deliverables drop straight into
the existing finding-template flow.

If TRACK A returns zero findings, that's also a strong signal — clean
extern surface across ~248 rods.

If TRACK A is finished within bandwidth, take TRACK B next (the harder
investigation). TRACK C is fallback if both A and B blocked.

## Standing rules (unchanged)

- No edits to compiler / runtime / `bin/nucleor.exe` / `bootstrap/` in
  your worktree without explicit handoff.
- No verify.sh edits.
- Findings go to `findings/inbox/` using `_template.md`.
- Heartbeat at `findings/heartbeat.json` updated on every phase transition.
- Self-host fixed-point md5 must hold post any code edits you do propose
  (current: `7b4966b9b69526674ef5ce3208a8274e`).
- Main rescue worktree at `C:\Users\JoeWe\Nucleor_OSS_main_rescue_v0850\`
  is your investigation lane; preserved probe at
  `C:\Users\JoeWe\Nucleor_OSS_pe_fix\` is read-only.

## How to point probe

Tell probe:

> Read `findings/_parallel_agent_assignment_v0851_2026-05-05.md`. Take
> TRACK A. Sweep every `extern fn nuc_*` in `stdlib/rods/` against the
> matching C function in `stdlib/runtime/`. Drop one finding per mismatch
> to `findings/inbox/extern_arity_drift_<rod>_2026-05-05.md`. Severity
> classification per the spec. Do NOT edit compiler / runtime / bin /
> bootstrap. Do NOT duplicate the audit work — that's owned by Codex
> at `Nucleor_OSS_Files\Nucleor_Build_Spine\11_AUDIT_2026-05-05\`.

When TRACK A returns, take TRACK B (G-1 H1-H4 trace). Update
`findings/heartbeat.json` on every phase transition.
