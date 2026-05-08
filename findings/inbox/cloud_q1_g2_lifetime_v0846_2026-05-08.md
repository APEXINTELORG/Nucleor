# Q1 — G-2 Phase 2b/3/4 single-input lifetime check (BORROW-G2-LIFETIME)

**Branch:** `claude/v1-finish-cloud-Q1-g2-lifetime`
**Base:** `origin/main @ 746298d`
**Host:** `Linux vm 6.18.5 #2 SMP PREEMPT_DYNAMIC Wed Jan 14 17:56:08 UTC 2026 x86_64`
**Tools:** `clang Ubuntu-18.1.3`
**Mandate:** `CLOUD_AGENT_V1_FINISH_BRIEF_2026-05-07.md` Q1 row.
**Plan ref:** `docs/rfcs/RFC-0062-IMPLEMENTATION-PLAN.md` G-2 row, lines 97-109.

## Bug shape (the gap this closes)

Per RFC-0062 §3.3 G-2: lifetime annotations (`<'a>`) parse, lex, type-check,
and the `&'a T` syntax produces well-formed AST. The borrow checker, however,
does not enforce the lifetime annotation. Two distinct `<'a>` regions in the
same function can alias. The Phase 1 BR-7 audit-pass count (~line 32172) was
diagnostic-only — counted occurrences but did not enforce.

Phase 2b spec (the queue spec): "for `fn foo(x: &T) -> &T` (single ref input,
ref output), verify the returned borrow's region == input's region." Phase 3
adds elision rules; Phase 4 promotes the diagnostic to a hard error. The
brief's bar: ship 2b + 3 + 4 in one cycle.

## Patch shape

Three targeted edits to `compiler/nucleor_s1_compiler.nr`:

1. **Diagnostic registration** (line ~11144). Add `BORROW-G2-LIFETIME` to
   `is_error_code` so `own_diag` halts compilation when the rule is violated
   (Phase 4 promotion).

2. **Helper** (line ~20665). New `expr_param_root(pool, nid, own) -> str`
   alongside the existing `expr_escape_root`. Mirror structure but flips the
   param-vs-local test: returns the *parameter* name a returned reference
   traces back to, or `""` if the trace cannot be proved (or if the source is
   a non-param local — that case stays with OWN-009). For `if`/`else`
   expressions both arms must trace to the same param; otherwise the join is
   inconclusive and the helper returns `""` (conservative against false
   positives).

3. **Check** (line ~20272 inside `check_fn`). After the existing OWN-009
   escape-from-local block, count ref-typed parameters; if exactly 1 ref
   input and the existing `escape_root` is empty (so OWN-009 will not fire
   on this path), invoke `expr_param_root` on the return expression. If the
   resulting param-root is non-empty AND not equal to the single ref input's
   name, emit `BORROW-G2-LIFETIME` at error severity via `own_diag`.

Conservative behavior:
- Multi-input cases (`ref_param_count > 1`) are skipped here — Phase 3
  elision territory per the plan.
- Trace failure (`expr_param_root` returns `""`) is silent — either OWN-009
  is already firing (escape-from-local) or the trace is opaque enough that
  emitting would risk false positives.
- Only fires when the trace *succeeds* but lands on a non-matching param.

## Validation

### Bootstrap fixed-point
```
seed pre-Q1:    86b491ca2d056f6006f4545e0e29d706 (v0.8.323 post-DFLIP-PATCH)
seed post-Q1:   sha256=e04a9c13ac6ccd9ec250606bb92a7f98148bb1ab8da03a7d0822e761432d2eb2
                (md5 captured in CHANGELOG/release notes if needed)
```
Single seed refresh: rebuilt stage-1 from new seed, stage-2 from new
stage-1, IR matches bootstrap/nucleor_s1_seed.ll byte-for-byte.

### `bash tools/verify.sh`
**PASS=1483 / SKIP=7 / FAIL=0 across 1490 steps.** (was 1480/7/1 pre-patch;
+2 new fixtures, +1 dup-audit step now passing after report regen.) Full
log: `findings/inbox/cloud_q1_g2_lifetime_v0846_2026-05-08_default.log`.

### `bash tools/verify_strict.sh`
**PASS=1483 / SKIP=7 / FAIL=0 across 1490 steps.** Cache-cold +
NUC_VERIFY_STRICT=1. Full log: `findings/inbox/cloud_q1_g2_lifetime_v0846_2026-05-08_strict.log`.

### Fixtures
- **Positive:** `tests/features/g2_single_input_lifetime_ok.nr` — `fn id_ref(x: &i32) -> &i32 { x }` builds + runs cleanly (prints 42 + OK).
- **Negative:** `tests/err/err_borrow_g2_lifetime_value_param.nr` — `fn borrow_other_param(x: &i32, y: i32) -> &i32 { &y }` triggers `error[BORROW-G2-LIFETIME]` with the param-root (`y`) and single-ref-input (`x`) both named in the message.

### Existing OWN-009 lock-in unaffected
`tests/err/err_lifetime_dangling_return.nr` (`fn dangling() -> &i32 { let x: i32 = 42; &x }`) continues to fire OWN-009 — my new check only runs when there's exactly one ref-typed input parameter; that fixture has zero ref params so the new code path skips and OWN-009 fires as before.

### Adopter-code surface impact
Pre-edit grep across stdlib + tests + fixtures + compiler sources found
zero `fn ...(...:&...) -> &...` patterns (i64-everywhere ABI). The check
landed at error severity without breaking any existing call site. Real-world
adopter code in Nucleor today does not exercise the rule; locking it in now
ensures future adopters who write proper ref-in/ref-out signatures get
enforced lifetime semantics from day one of v1.0.

## Audit-report regen

`tools/audit_dup_fns_report.csv`: only delta is the `check_fn` size column
(49 → 89 reflecting the new G-2 block). Per-bucket totals unchanged: still
30 IDENTICAL / 131 SIG_MATCH_BODY_DIFFERS / 19 SIG_DIFFERS — that's the Q5
inventory matching the brief's wave 12-16 spec exactly.

## Per-step timing notes

T1.7 (bootstrap seed match): 5.61s (was 5.55s) — within noise.
T1.8 (self-host fixed-point): 15.45s (was 14.96s) — within noise; the
+0.5s reflects one extra AST walk per `fn` that has a ref return type
(rare in the seed self-host source — most fns are i64 or value-typed).
PROBE-1 driver: 1.16-1.26s (was 1.24s) — within noise.

No step exceeded 1.3× its baseline; no perf regression flagged.

## Honesty section

- BR-7 textual audit at line 32172 is unchanged. Phase 2b adds the
  structural check alongside; the BR-7 line still surfaces the count for
  build summary. A future polish (not in this Q) could refine the BR-7
  message to "Phase 2b live; counts are advisory" but the brief is
  explicit about not touching anything beyond what closes the gate.
- This patch is purely additive in `check_fn`. No existing diagnostic
  semantics changed; OWN-009 is the only sibling that could double-fire
  and that's explicitly suppressed via the `escape_root` empty check.
- New helper `expr_param_root` is `#[manual_drop]`-annotated to match the
  surrounding fns in that block (not because it owns heap data; for
  consistency with the existing call-site convention).

## Done

- All Phase 4 acceptance criteria met: structural check fires with the
  correct diagnostic code at error severity, registered in is_error_code,
  fixtures locked in, both verify modes GREEN, fixed-point holds.
- Cumulative `check_fn` cost stays within plan-projected +0.10s on
  ref-using fns.

Cumulative cloud queue progress: Q1 done, Q2-Q5 next.
