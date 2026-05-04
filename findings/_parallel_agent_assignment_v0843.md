# Parallel Agent Assignment — post-v0.8.42 (2026-05-04)

**Status:** P2 hot-path allocation hunt COMPLETE. Ready for next assignment.

## Recap of P2 work

Per `findings/heartbeat.json`:

- `str_from_i64` hot-path optimized (str_concat 2.5M → 1.2M, ~50% reduction).
- `fn_return_map` lookup switched from Vec backward-scan to dedicated HashMap.
- Cold 3.15s, peak 294MB on 3-sample perf check.
- Verify: 808 pass / 2 skip / 0 fail.
- Branch: `perf/prefer-pwsh-rss-sampler` in worktree
  `C:\Users\JoeWe\Desktop\Nucleor_OSS_perf_a64`.
- Q-class halts (Q5 import tails, Q6 HRTB, Q10 inline/cold) covered.

The branch is **ready for integration** into main. Main agent
should review and merge in a future ship cycle.

## Next assignment — pick ONE based on probe agent's strengths

Probe agent's demonstrated strengths: perf-attribution, hot-path
allocation hunting, defensive-halt closures, fixture-driven
investigation. Apply those to the new gap-RFC set.

### Option A (PRIMARY) — Investigate critical silent-miscompute findings

The user landed 14 new gap-analysis RFCs at `docs/rfcs/gap-analyses/`
on 2026-05-04. Each has CRITICAL findings flagged. Probe should
investigate (write fixtures + characterize the bug):

1. **NUM-G1** (`Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`):
   f64 lex truncation to 6 decimal digits. Write fixtures that
   demonstrate `3.1415926535897932 != 3.141592` parses identically.
   Quantify which adopter use-cases break.

2. **ML-1** (`Nucleor_Tensor_ML_Autodiff_Gap_Analysis_and_RFC_2026-05-04.md`):
   `nuc_attn_flash` rod takes 6 args, C runtime takes 7. Write
   a fixture that calls flash-attention end-to-end and verifies
   bit-exact output against a reference. Today's silent miscompute
   should manifest as wrong outputs.

3. **T-3, T-4** (`Nucleor_Type_System_Gap_Analysis_and_RFC_2026-05-04.md`):
   char↔int silent compatibility. Write fixtures that trip the
   type-checker into accepting nonsensical assignments.

4. **C-1, C-2** (`Nucleor_Concurrency_Gap_Analysis_and_RFC_2026-05-04.md`):
   Linux concurrency — cancel token + POSIX channel both broken.
   Write fixtures that demonstrate the breakage on Linux. (Probe
   agent runs Windows but can write Linux-targeted tests for CI.)

Each finding becomes an inbox entry under `findings/inbox/` with
the standard probe template (repro, expected/observed, severity,
suggested phase-1 fix).

### Option B (ALTERNATIVE) — RFC-0062 Phase 2b-3-trace investigation

The main agent has been blocked on the seed-side flip mystery
(why seed IR is byte-identical under `NUC_AUTO_DROP_DEFAULT=1`).
Hypotheses H1-H4 are documented in
`docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md` §2b-3-trace.

If probe wants to take this on, the next step is targeted debug
prints in:
- `lower_fn` (does name_in_auto_drop get called? returns what?)
- `auto_drop_register` (does it run for the candidate fns? what tstr does it see?)
- `auto_drop_emit_live` (does it run at the right return paths?)

This is harder than Option A but unblocks the critical-path memory
safety closure.

### Option C (PARALLEL TO A and B) — Continue P-class perf hunt

If A and B are too high-bandwidth for one probe cycle, continue
the hot-path allocation hunt on remaining helpers (P3 / P4 per
existing roadmap). The cold-time budget is comfortable (3.5s
mean) but more headroom is welcome before Phase 2b proper-analysis
checkers land.

## Recommendation

**OPTION A** is highest-value — the critical findings represent
real shipped bugs that affect adopter trust. Probe is well-suited
to write the demonstration fixtures and quantify impact. After
landing Option A inbox entries, main agent integrates them into
the v1_PUNCHLIST sequence.

If probe returns to this assignment file with multiple inbox
entries and clear severity classifications, that's a successful
assignment cycle.

## How to point probe

Tell probe:

> Read `docs/rfcs/v1_PUNCHLIST.md` and `findings/_parallel_agent_assignment_v0843.md`.
> Pick OPTION A. Investigate NUM-G1, ML-1, T-3, T-4, C-1, C-2 in
> that priority order. For each, write a repro fixture under
> `findings/inbox/` following the standard probe template.
> Quantify severity. Don't ship to main; just investigate and
> report findings.
