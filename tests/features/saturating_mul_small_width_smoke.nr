// v0.8.275 R09-D5 Phase 1 — saturating multiply input-clamping coverage.
//
// Per audit `BUILD_PLAN_R09_numeric_correctness.md` §1 R09-D5 (HIGH):
// pre-v0.8.275 `__nucleor_saturating_mul_##W` for small widths
// (i8/i16/i32) computed `long long r = a * b` with no input
// pre-clamp. A caller passing a long long outside the type's
// declared range (e.g. INT64_MAX) could overflow the i64 product
// before the post-multiply range checks fired — invalidating the
// saturation contract.
//
// Phase 1 (this ship): pre-clamp `a` and `b` to `[MIN_V, MAX_V]`
// of the type before multiplying. For W in {i8, i16, i32},
// MAX_V * MAX_V fits in i64 once inputs are clamped, so the post-
// multiply check is then always meaningful.
//
// Phase 1 acceptance:
//   - min/max edge cases clamp correctly without UB or signal;
//   - cold compile <= 4s (preserved).
//
// This fixture exercises `n_saturating_mul` (the i64 path —
// dedicated `__nucleor_saturating_mul_i64` at runtime line 4329, NOT
// the macro I edited). The i64 path has been correct historically;
// this smoke verifies my edit didn't regress the broader
// saturating-mul surface. Per-small-width fixtures land Phase 2
// alongside the typed-arithmetic surface needed to drive the macro
// directly from Nucleor source.
//
// Locks 4 invariants on `n_saturating_mul`:
//   1. Identity — `mul(7, 1) == 7`.
//   2. Zero — `mul(0, INT_MAX) == 0`.
//   3. Negative product — `mul(2, -3) == -6`.
//   4. Saturate at i64 boundary — `mul(LARGE, LARGE)` clamps
//      to i64::MAX without UB. Specifically `mul(2^32, 2^32)`
//      would naturally be 2^64, which overflows i64 and clamps to
//      i64::MAX (0x7FFFFFFFFFFFFFFF = 9223372036854775807).
//
// Expected: rc=0.

import "stdlib/rods/numeric.nr"

fn check_identity() -> i64 {
    if n_saturating_mul(7, 1) != 7 { return 1; };
    if n_saturating_mul(1, 7) != 7 { return 2; };
    return 0;
}

fn check_zero() -> i64 {
    if n_saturating_mul(0, 9223372036854775807) != 0 { return 4; };
    if n_saturating_mul(9223372036854775807, 0) != 0 { return 8; };
    return 0;
}

fn check_negative_product() -> i64 {
    if n_saturating_mul(2, 0 - 3) != 0 - 6 { return 16; };
    return 0;
}

fn check_saturate_at_i64_boundary() -> i64 {
    // 2^32 = 4294967296
    // 2^32 * 2^32 = 2^64 — overflows i64; saturates to i64::MAX.
    let result: i64 = n_saturating_mul(4294967296, 4294967296);
    if result != 9223372036854775807 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_identity();
    fails = fails + check_zero();
    fails = fails + check_negative_product();
    fails = fails + check_saturate_at_i64_boundary();
    return fails;
}
