# Parallel Agent — v0.4 Residual Handoff (round 2)

Written by main-line agent on 2026-04-29. Main is at v0.4.134.
All 5 spike branches from round 1 are integrated; nothing pending
from prior workstream. This handoff queues 4 new multi-day items
for parallel work — same spike-branch / worktree pattern as round 1
worked well. Pick versions starting at v0.4.135 (main is at .134;
I may also ship .135 mid-flight on a tiny probe-triage close, so
coordinate with `git fetch` before tagging).

## Coordination ground rules (unchanged from round 1)

- One spike per topic, branch named `spike/v04-<topic>`, worktree
  at `C:/Users/JoeWe/Desktop/Nucleor_OSS_wt_<topic>` (mirrors
  round-1 layout).
- Bootstrap fixed-point check at every commit: build compiler with
  itself, sha256 must match. If it drifts, copy fresh `target/
  nucleor.{exe,ll}` over `bin/` and `bootstrap/seed`.
- Drift gate: `bash tools/check_compiler_drift.sh` must return 0.
- Verify: `bash tools/verify_parallel.sh -j 12` should pass at
  baseline (today: 188 PASS / 2 baseline-FAIL — `lang/mod_decl_aux`
  and `runtime/stdin_read` are the known FAILs). DO NOT introduce
  any new FAILs.
- 5-table mirror for any new C runtime helper:
  `get_rt_name`, `is_ptr_ret` (if ptr return), `is_ptr_arg`
  (per arg), `IR declare` in compiler, `IR declare` in tools_suite,
  + dispatch entry. Mirror in BOTH `nucleor_s1_compiler.nr` AND
  `nucleor_tools_suite.nr` (drift gate enforces parity).
- Tags: pick the next free integer ≥ 135. I'm probing in parallel
  and may ship single-tick TYP-* closes between your spikes.

## Item 1 — Trait bounds runtime: per-call-site impl-existence check

**Branch suggestion:** `spike/v04-trait-bound-callsite`

v0.4.130 (my ship) captures `?<trait>` markers in
`parse_generic_params` and verifies the trait NAME exists in the
program at type-check time. The remaining work: at every call
site of a generic fn with bounds, resolve the concrete `T` from
the actual arg types and verify `impl Trait for T` exists.

What needs doing:

1. **Sig storage retains bounds.** Today `sig_add` stores
   `(name, params, rtype, is_pub)`. Add a 5th field for the fn's
   gparams list (which now includes `?<bound>` markers from
   v0.4.130). Sig fetch must surface that list.
2. **At kind 7 (call) type-check**, when `sentry >= 0`, look up
   the gparams. For each `?<bound>`, find the matching position
   in the params list (e.g. `<T: Addable>(a: T, b: T)` →
   `T` is the param-type token at param-position 0, and the
   `?Addable` follows it). For each call arg whose declared
   param-type matches the bounded param's name, compute the
   actual arg type via `type_expr` and use the existing
   `type_implements_trait(pool, prog, actual_t, bound)` (added
   by the v0.4.118 trait-objects spike) to check.
3. **If implements check fails**, emit `TYP-021`:
   `error[TYP-021]: type 'i64' does not implement trait 'Addable'
   (required by bound on fn 'add_values<T: Addable>'). Add an
   'impl Addable for i64' block, or pick a type that already
   implements it.`
4. **Negative fixture:** `tests/err/err_trait_bound_unmet.nr`.
5. **Positive fixture:** ensure existing `tests/features/
   trait_bounds.nr` still passes (Addable IS impl'd for i32,
   so that case must NOT fire TYP-021).

Drift hazard: gparams list shape changed in v0.4.130 — bounds
look like `["T", "?Addable", "U", "?Display", "?Debug"]`. The
position-tracking logic must skip over `?` entries when matching
to param positions.

## Item 2 — Saturating per-op via LLVM intrinsics

**Branch suggestion:** `spike/v04-saturating-perop`

v0.4.105 (my ship) implements block-tail saturation —
`saturating { expr }` clamps the final i64 expression result
through `__nucleor_sat_i32`. Per-op saturation routes each
arithmetic op INSIDE the block through `@llvm.sadd.sat.i32` /
`@llvm.ssub.sat.i32` / `@llvm.smul.sat.i32` (or i64 variants).

What needs doing:

1. **Mode flag through codegen.** `lower_expr` takes ~12 args.
   Add a 13th: `sat_mode: i64` (0 = normal, 1 = i32 sat,
   2 = i64 sat). Thread through every recursive call site
   (~50 call sites — most just forward unchanged). Top-level
   callers pass 0; the kind 52 (saturating block) sets it
   to 1 or 2 based on the block's declared element type.
2. **At kind 4 binop lowering** (line ~13550), when
   `sat_mode > 0` AND op is `+` (20), `-` (21), or `*` (22),
   route through new IR-call helpers `sat_add_i32` / `sat_sub_i32`
   / `sat_mul_i32` (and i64 variants). Skip for `/` and `%`
   since those don't have signed-saturate intrinsics.
3. **Add the 6 IR intrinsic declarations** in
   `nucleor_s1_compiler.nr` AND `tools_suite`:
   ```
   declare i32 @llvm.sadd.sat.i32(i32, i32)
   declare i32 @llvm.ssub.sat.i32(i32, i32)
   declare i32 @llvm.smul.sat.i32(i32, i32)
   declare i64 @llvm.sadd.sat.i64(i64, i64)
   declare i64 @llvm.ssub.sat.i64(i64, i64)
   declare i64 @llvm.smul.sat.i64(i64, i64)
   ```
   These are LLVM intrinsics — no runtime C helper needed.
4. **At kind 4 binop emission**, when `sat_mode == 1`, generate:
   ```
   %r.X.lo = trunc i64 %r.lhs to i32
   %r.X.ro = trunc i64 %r.rhs to i32
   %r.X.s32 = call i32 @llvm.sadd.sat.i32(i32 %r.X.lo, i32 %r.X.ro)
   %r.X = sext i32 %r.X.s32 to i64
   ```
   For `sat_mode == 2`, skip the truncate/sext and go straight
   to the i64 intrinsic.
5. **Negative fixture:** `tests/features/saturating_perop.nr`
   — `saturating { i32::MAX + 1 + 1 }` should clamp at i32::MAX
   (not wrap to MIN then re-saturate to MIN).
6. **Positive regression:** existing `tests/features/
   overflow_saturating.nr` and `overflow_comprehensive.nr`
   must still pass with their current expected outputs (the
   block-tail clamp is still correct for single-op cases).

## Item 3 — `tools/verify_parallel.sh` fold-in to `verify.sh`

**Branch suggestion:** `spike/v04-verify-parallel-fold`

Standalone `tools/verify_parallel.sh` (shipped v0.4.104) gets
~9× speedup at -j 12, race-free. The fold-in to `verify.sh`
proper (replacing the four sequential test loops) aborted
earlier this session because indices 87-162 silently dropped
their result files even at -j 1 — a deterministic 76-file gap
in a contiguous range. The standalone harness doesn't have this
problem; the difference is the fold uses verify.sh's
`build_test`/`build_negative` shell helpers which redirect to
`$NUC_VERIFY_STEP_LOG`. I tried per-worker step-log paths and
the gap persisted, so it's not a step-log race.

What needs doing:

1. **Reproduce.** Run the fold-in code I left in
   `tools/verify.sh` HEAD~N (search the git log for "step_parallel"
   commits — they were reverted but the diff is recoverable).
2. **Trace.** Add a `set -x` block around `_step_parallel_run_one`
   for indices 87-95 specifically. Capture the bash trace to a
   per-worker debug file. Look for which command in the worker
   subshell exits early before the result-file printf runs.
3. **Likely candidate:** `bash` background subshell hits a stack
   overflow when ~80 children pile up in the wait queue (Windows
   git-bash known quirk). Workaround: use `xargs -P 12` instead
   of `wait -n` slot management.
4. **Validate.** End-to-end `bash tools/verify.sh` should match
   the standalone harness output (155-188 PASS depending on what
   else has shipped).

Notes:
- I tried `git rebase --abort` on Windows — `bin/nucleor.exe`
  file lock blocks it. Workaround: `rm -f bin/nucleor.exe &&
  sleep 2 && git rebase --abort`. Same trick if your worktree
  gets stuck.
- Don't ship a half-broken fold — abort and document if the
  trace doesn't pinpoint the cause within 2-3 ticks.

## Item 4 — Variable-RHS shift bounds check

**Branch suggestion:** `spike/v04-shift-var-rhs`

`NUM-008` (v0.4.75 ship) catches `1 << 100` (literal RHS out
of range). Variable RHS — `let n: i32 = ...; let r = a << n;`
where `n` could be > 63 or < 0 at runtime — is not caught. LLVM
`shl`/`ashr` is undefined behavior outside [0, 63] for i64;
silent wrong result.

What needs doing:

1. **Compile-time const-prop**: walk the AST upward from the
   shift's RHS expression. If the RHS resolves to a literal-ish
   chain (`let n = 100; ... n` — kind 3 var-ref where the
   binding is initialized from kind 1 literal), surface the
   literal value to the existing NUM-008 check.
2. **Runtime guard for non-const RHS**: at lower_expr kind 4
   binop (op 23/24 = `<<`/`>>`), when the RHS is non-literal,
   emit a runtime check via a new `__nucleor_panic_shift_oob`
   helper (similar to `panic_div`/`panic_rem`). Bound check
   `0 <= rhs && rhs <= 63`, panic with clear message if not.
3. **Negative fixture:** `tests/err/err_shift_var_rhs_neg.nr`
   — runtime panic for `a << -3`.
4. **Positive regression:** existing shift-using fixtures (mostly
   in `tests/features/math_*.nr`) must still pass.

Performance hazard: shifts are common in tight loops. Consider
adding `NUCLEOR_SHIFT_LENIENT=1` env var (mirror of
`NUCLEOR_VEC_OOB_LENIENT`) for opt-out, and skip the runtime
check when the RHS type is `u8` (always 0-255, > 63 still
possible but skipping the negative-side check halves the
overhead).

## What I'll do meanwhile on main

Probe triage continues. Each cycle I find ~1 silent-miscompute
close (TYP-005 / TYP-008 / TYP-010 / TYP-014..020 / MATCH-001
extensions etc.) and ship a single-tick `v0.4.NNN` tag.
Recent examples: v0.4.128 (struct-init dup field), v0.4.129
(unknown struct-field read), v0.4.131 (unknown struct-field
assign), v0.4.132 (void-in-binop), v0.4.133 (int-lit in bool
struct field), v0.4.134 (bool literal match arms).

I will NOT touch anything in the 4 areas above while you work
them — coordinate via blocker doc style if you hit the same
file path I'm editing.

## Pull / push protocol

Before every commit on a spike branch:
```
git fetch --all
git rebase main -X theirs   # auto-pick spike's compiler.nr changes
# resolve any binary file conflicts (bin/nucleor.exe,
# bootstrap/nucleor_s1_seed.ll) by taking theirs + rebuilding
# bootstrap fixed-point per the round-1 procedure
```

If `git rebase` errors with `unable to unlink old 'bin/nucleor.exe'`,
that's a Windows file lock — `rm -f bin/nucleor.exe && sleep 2 &&
retry`.

When ready: `git push origin spike/v04-<topic>`. I'll see it on
my next `git fetch --all` and integrate.
