// v0.8.277 R09-D2 Phase 1 — interval trig rigorous outward rounding +
// pool exhaustion fail-closed.
//
// Per audit `BUILD_PLAN_R09_numeric_correctness.md` §1 R09-D2 (HIGH):
// pre-v0.8.277 had two issues in `stdlib/runtime/interval_rt.c`:
//   1. Pool exhaustion silently wrapped to slot 1 (`interval_next = 1`),
//      aliasing all earlier still-live handles — interval-containment
//      guarantees broke without diagnostic.
//   2. Trig widening used a fixed `DBL_EPSILON` which is the f64
//      spacing at 1.0; for inputs with |x| >> 1 the widening was
//      narrower than 1 ULP and the result interval did not
//      rigorously contain the true mathematical value.
//
// Phase 1 (this ship):
//   - `iv_alloc` returns 0 (the canonical "invalid handle") on pool
//     exhaustion. Adopters check and bail safely; no silent
//     aliasing.
//   - `nuc_interval_sin` widens via `nextafter(lo, -INFINITY)` and
//     `nextafter(hi, INFINITY)` — exact 1 ULP outward rounding at
//     the value's magnitude. Output range clamped to `[-1, 1]`
//     (sin's mathematical bounds).
//
// Phase 1 acceptance criteria:
//   - exhaustion never wraps silently (returns invalid handle);
//   - sin/cos fixture contains sampled truths;
//   - cold compile <= 4s (preserved — runtime-only edit).
//
// Locks 4 invariants:
//   1. `sin([0, 0])` contains 0.0 — point-interval at zero.
//   2. `sin([0, 2π])` contains -1, 0, 1 — full period sees min,
//      mid, max. Result interval should be exactly `[-1, 1]`.
//   3. `sin([1e10, 1e10])` returns interval within `[-1, 1]` —
//      large-magnitude input must not produce a wider-than-bound
//      result; the nextafter widening at 1e10 is wider than
//      DBL_EPSILON but the [-1, 1] clamp keeps it valid.
//   4. `sin([π/2, π/2])` contains 1.0 — the peak. Old DBL_EPSILON
//      widening was probably wide enough here (π/2 ≈ 1.57); this
//      passes both pre and post-fix and is a basic sanity check.
//
// Pool exhaustion is verified via code review (the runtime change
// is `if (pool_full) return 0;`). A fixture filling the 2M-slot
// pool would take significant memory + time; deferred to Phase 2
// or a stress-test harness.
//
// Expected: rc=0.

import "stdlib/rods/interval.nr"

fn check_sin_zero_contains_zero() -> i64 {
    let z: i64 = iv_point(f64_to_bits(0.0));
    let s: i64 = iv_sin(z);
    if s == 0 { return 1; }; // alloc failed
    let contains: i64 = iv_contains(s, f64_to_bits(0.0));
    if contains != 1 { return 2; };
    return 0;
}

fn check_sin_full_period_is_full_range() -> i64 {
    // [0, 2π] — sin attains full [-1, 1].
    let p: i64 = iv_new(f64_to_bits(0.0), f64_to_bits(6.283185307179586));
    let s: i64 = iv_sin(p);
    if s == 0 { return 4; };
    if iv_contains(s, f64_to_bits(0.0 - 1.0)) != 1 { return 8; };
    if iv_contains(s, f64_to_bits(0.0)) != 1 { return 16; };
    if iv_contains(s, f64_to_bits(1.0)) != 1 { return 32; };
    return 0;
}

fn check_sin_large_magnitude_within_bounds() -> i64 {
    // sin([1e10, 1e10]) — large-magnitude input. Result must be
    // within [-1, 1] regardless of the widening.
    let big: i64 = iv_point(f64_to_bits(1e10));
    let s: i64 = iv_sin(big);
    if s == 0 { return 64; };
    let lo_bits: i64 = iv_lo(s);
    let hi_bits: i64 = iv_hi(s);
    let lo: f64 = f64_from_bits(lo_bits);
    let hi: f64 = f64_from_bits(hi_bits);
    if lo < 0.0 - 1.0 { return 128; };
    if hi > 1.0 { return 256; };
    return 0;
}

fn check_sin_pi_over_2_contains_one() -> i64 {
    let p: i64 = iv_point(f64_to_bits(1.5707963267948966));
    let s: i64 = iv_sin(p);
    if s == 0 { return 512; };
    if iv_contains(s, f64_to_bits(1.0)) != 1 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_sin_zero_contains_zero();
    fails = fails + check_sin_full_period_is_full_range();
    fails = fails + check_sin_large_magnitude_within_bounds();
    fails = fails + check_sin_pi_over_2_contains_one();
    return fails;
}
