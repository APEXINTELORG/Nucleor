# Nucleor — Numeric Correctness Gap Analysis and RFC

**Date:** 2026-05-04
**Author:** Claude (Opus 4.7) for Joseph Wescott
**Document type:** Combined gap analysis + RFC
**Status:** Draft for main-agent integration
**Disposition:** No file writes were made into `Nucleor_OSS`.

---

# Part I — Definition

## 1.1. The numeric correctness pillar

Numeric correctness covers integer arithmetic (strict-mode, wrapping, saturating, checked), IEEE-754 floating-point conformance, fixed-point, interval arithmetic, directed rounding, and comptime numeric evaluation. Bugs here are silent miscomputes — the most dangerous failure class because they don't crash, they produce wrong answers.

**Headline finding: f64 literals are silently truncated to 6 decimal digits.** The lexer encodes `3.1415926535897932` as `3.141592`. **Systematic, silent miscompute for any code using >6-digit decimal float literals.** Affects all f64-using code, complex rod constants, any user transcribing 15-digit constants.

**Second headline: `math_abs(i64::MIN)` returns wrong result in non-strict mode.** `0 - i64::MIN` overflows; in wrapping mode returns i64::MIN. `math_pow_int` and `math_gcd` inherit the bug.

---

# Part II — Gap Inventory

## NUM-G1 — f64 literal precision truncated to 6 decimal digits — **CRITICAL**
Lexer encodes `int_part * 1_000_000 + frac_millionths`. `3.1415926535897932` silently stored as `3.141592`. **Systematic silent miscompute for any code using >6-digit float literals.** Affects f64 code, complex rod constants, transcribed 15-digit constants.

## NUM-G2 — `math_abs` wrong for i64::MIN in non-strict mode — **HIGH**
`math_abs(n)` computes `0 - n`. For `n = i64::MIN`, overflows. With `NUCLEOR_INT_STRICT_INTRIN=1` panics (correct); in `wrapping {}` context or `INTRIN=0`, silently returns i64::MIN. `math_pow_int` loops with unchecked multiply. `math_gcd` inherits the bug.

## NUM-G3 — `mul_trap` false-negative for mixed-sign overflow — **MEDIUM**
`r / a != b` cross-divide detection. When `a = -1, b = i64::MIN`, product wraps to i64::MIN, then `r / a = i64::MIN / -1` invokes div-overflow panic — wrong error message ("div overflow" not "mul overflow"). Outcome correct (does panic) but diagnostic misleading.

## NUM-G4 — `fixed<I,F>` collapses to i64 — no compile-time width enforcement — **HIGH**
RFC-0043 documents this. `fixed_point.nr` rod is workaround; provides no compiler-enforced separation between Q formats. `let a: fixed<8,8> = ...; let b: fixed<16,16> = a;` silently succeeds (both are i64). Mixed-format arithmetic produces wrong results. `fixed_saturate` returns raw i64 when `I+F == 63` without clamping.

## NUM-G5 — `interval_rt.c` pool exhaustion wraps silently — **HIGH**

Update 2026-05-06 helper1 v0860: the interval runtime had already been changed to fail closed instead of wrapping on pool exhaustion; this slice adds public pool capacity/status/preflight helpers (`iv_pool_capacity`, `iv_pool_used`, `iv_pool_remaining`, `iv_pool_preflight`) so callers can avoid exhaustion before allocating large interval batches. `tests/features/interval_pool_status_smoke.nr` locks checkpoint/reset accounting and preflight refusal for impossible allocation counts.
At pool full, `interval_next = 1` — pool wraps and new handles alias into live data with no diagnostic. Long-running proofs without checkpoint resets are silently corrupted. No capacity counter or overflow warning.

## NUM-G6 — `interval` sin/cos widening uses DBL_EPSILON not rigorous ULP bound — **MEDIUM**
`iv_alloc(lo - DBL_EPSILON, hi + DBL_EPSILON)`. DBL_EPSILON ≈ 2.2e-16 is machine epsilon for 1.0, not universal 1-ULP bound. For values far from 1.0, widening may be insufficient. cos wrapper shifts by `M_PI/2` before sin; that addition is not under directed rounding.

## NUM-G7 — `complex` abs/div/log use direct-square — overflow for large args — **MEDIUM**
`rods_complex_abs` uses `sqrt(a*a + b*b)` — overflows when components exceed ~1e154. `rods_complex_div` computes `c*c + d*d` denominator with same exposure. Should use `hypot`. No NaN/Inf propagation contract.

## NUM-G8 — `checked_*` API not thread-safe (shared global flag) — **HIGH**
`__nucleor_overflow_flag` is single global static int. Concurrent `checked_*` calls from different threads race on flag. Flag can be overwritten between call and `checked_overflow_flag()` read. No mutex, no thread-local storage.

## NUM-G9 — `@const_fn` silently ignored — no comptime evaluation — **HIGH**
Attribute parsed and discarded. Code marked `@const_fn` provides no guarantee of compile-time evaluation, no error if it contains non-const operations, no optimization opportunity.

## NUM-G10 — NUM-001 warning is text heuristic, not type-system check — **MEDIUM**
Operates on raw source text. Only fires for `i32` in additive context. Misses i8+i64, u16+u32, f32+f64, unsigned+signed, and all non-additive mixed-width ops. RFC-0015 type lattice DoD checkboxes still unchecked.

## NUM-G11 — No user-facing directed-rounding API — **MEDIUM**
`fesetround` used internally by `interval_rt.c` and `taylor_rt.c`. **No Nucleor-level rod or builtin exposing `round_down(f64)` / `round_up(f64)` / `get_rounding_mode()` for general user code.**

Update 2026-05-06 helper1 v0858: `numeric.nr` now exposes stable rounding-mode IDs, `n_get_rounding_mode`, `n_set_rounding_mode`, and `n_f64_next_up` / `n_f64_next_down`, covered by `tests/features/numeric_rounding_fma_smoke.nr`.

## NUM-G12 — No FMA on f64 path — **LOW**
`simd_fma` and `vector_fma` exist for SIMD/vector. Scalar `f64_*` surface has no `f64_mul_add(a, b, c)` emitting LLVM `llvm.fma.f64`. Without FMA, `a*b + c` goes through two separately-rounded ops, losing single-rounding FMA result.

Update 2026-05-06 helper1 v0858: `numeric.nr` now exposes scalar `n_f64_mul_add` and `n_f32_mul_add` backed by C `fma` / `fmaf`, covered by `tests/features/numeric_rounding_fma_smoke.nr`.

## NUM-G13 — `saturating_mul_i32/i16/i8` macro uses unchecked `a * b` in C — **MEDIUM**
Macro computes `long long r = a * b` with no overflow check before clamping. For values close to LLONG_MAX, multiplication overflows `long long` (C UB). Safe for in-range inputs but caller passing out-of-range value triggers UB.

## Cross-cutting risks
- **Lexer-side f64 precision (NUM-G1)** propagates silently into every floating-point rod and user program. No diagnostic exists. Most widespread silent miscompute risk.
- **Strict-mode env-controlled, not per-program** — `NUCLEOR_INT_STRICT_INTRIN` consulted at compile time, folded into cache key, but no per-function or per-module annotation to mandate strict-mode for specific code section.
- **`checked_*` global-flag race (NUM-G8)** makes checked arithmetic API unusable in any thread-safe context.
- **IEEE FP model for generated LLVM IR** — clang link command contains no `-ffp-model=strict` or `-fp-contract=off`. Default LLVM/clang FP model may allow contraction silently. `#pragma STDC FENV_ACCESS ON` absent from `nucleor_llvm_rt.c`.

---

# Part III — RFC

## 3.1. Goals
1. Fix the f64 literal precision bug (NUM-G1) — this is the silent miscompute affecting every float user.
2. Fix `math_abs(i64::MIN)` and the related cascade.
3. Make `checked_*` thread-safe.
4. Implement `@const_fn` honestly or remove it from the language.

## 3.2. Closure plan

**Phase 1 (emergency, silent-miscompute fixes):**
- NUM-G1: replace 6-digit lexer encoding with full IEEE-754 round-trip via `strtod`. Test: `let x: f64 = 3.141592653589793; assert(x == 3.141592653589793);` — currently fails silently, must pass.
- NUM-G2: `math_abs` checks for `n == i64::MIN` and either panics (always) or saturates to `i64::MAX`. Document choice. Same for `math_pow_int` overflow handling and `math_gcd`'s call to `math_abs`.
- NUM-G3: `mul_trap` does explicit overflow check before division to produce "mul overflow" diagnostic instead of "div overflow".
- NUM-G8 P1: serialize `__nucleor_overflow_flag` via mutex; document checked API as not-recommended-for-multithreaded.
- NUM-G9 P1: emit warning NUM-WARN-001 on `@const_fn`: "Compile-time evaluation not yet enforced; attribute is currently a no-op. See RFC-0034."

**Phase 2 (short-term):**
- NUM-G5: `interval_rt.c` pool exhaustion fails closed instead of silently wrapping, and helper1 v0860 adds public status/preflight helpers so callers can query capacity before allocation. User must increase pool or reset checkpoints for larger workloads.
- NUM-G7: `rods_complex_abs` uses `hypot(a, b)`. `rods_complex_div` uses range-aware formula (Smith's algorithm). Document NaN/Inf propagation contract.
- NUM-G8 P2: replace global flag with thread-local storage. `checked_*` returns become re-entrant.
- NUM-G11: implement `round_down`/`round_up`/`round_to_nearest`/`get_rounding_mode` in `numeric.nr` rod. Direct wrappers around `fesetround`. **Mode get/set + next-up/down shipped helper1 v0858.**
- NUM-G12: implement `f64_mul_add` and `f32_mul_add` mapping to `llvm.fma.f64`/`f32`. Documented IEEE single-rounding semantics. **C `fma`/`fmaf` wrappers shipped helper1 v0858; compiler intrinsic lowering remains future work.**
- NUM-G13: rewrite `saturating_mul` macro to do checked multiply (use `__builtin_mul_overflow` on GCC/Clang, equivalent on MSVC).

**Phase 3 (medium-term):**
- NUM-G4: implement `fixed<I,F>` as a typed wrapper distinct from i64 in IR. Cross-format assignment is type error. Saturate respects declared width across all I+F combinations.
- NUM-G6: implement rigorous interval sin/cos using ULP-aware bounds. Reference implementation: Boost.Interval's transcendental policy.
- NUM-G9 P2: implement `@const_fn` interpreter for arithmetic + branching. Compile-time evaluation of pure functions with constant arguments.
- NUM-G10: implement RFC-0015 type lattice. NUM-001 becomes a real type-checker output, not text scanner.

**Phase 4 (v1.0 gate):**
- IEEE FP model: emit `-ffp-model=strict` and `-fp-contract=off` in clang invocation by default. Add `#pragma STDC FENV_ACCESS ON` to `nucleor_llvm_rt.c`.
- Per-function strict-mode annotation: `#[strict_arith]` on a function makes overflow checks unsuppressible regardless of env.
- All cross-cutting risks closed.

## 3.3. v1.0 release gate
Phase 1 emergency fixes (NUM-G1 especially) IMMEDIATELY — every day this ships, silent wrong f64 literals propagate. Phase 2 minimum for v1.0. Phase 3 strongly preferred. Phase 4 acceptable as v1.x.

## 3.4. Open questions
1. NUM-G2: should `math_abs(i64::MIN)` panic or saturate? Recommendation: panic (matches strict-mode philosophy); user can use `wrapping_abs` for explicit wrap.
2. NUM-G9: full CTFE interpreter is large effort. Should `@const_fn` be removed instead? Recommendation: keep as warning-only Phase 1, decide based on user demand whether to implement Phase 3.
3. NUM-G6: rigorous interval transcendentals are research-grade. Acceptable to ship "DBL_EPSILON heuristic with disclosure" instead? Recommendation: yes for v1.0, rigorous bounds as v1.x.

---

# Part IV — Disposition
**Document path:** `C:\Users\JoeWe\Desktop\Nucleor_Numeric_Correctness_Gap_Analysis_and_RFC_2026-05-04.md`

*End of document.*
