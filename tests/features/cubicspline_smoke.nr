// v0.8.249 stdlib/rods/cubicspline.nr first test coverage.
//
// Natural cubic spline interpolation through N waypoints. Pre-
// v0.8.249: zero coverage on the standalone rod. The
// algorithmic path needs raw double[] xs/ys/y2 arrays;
// deferred to dedicated path-smoothing ships once the
// Vec → raw-ptr bridge lands.
//
// Locks four bad-input invariants — the runtime requires N≥2
// and null-checks all three pointer triplets:
//
//   1. fit with n < 2 returns 0 — degenerate.
//   2. fit with null ptrs returns 0 — bad input.
//   3. sample with n < 2 returns 0 — degenerate.
//   4. sample with null ptrs returns 0 — bad input.
//
// Expected: rc=0.

import "stdlib/rods/cubicspline.nr"

fn check_fit_n_lt_2() -> i64 {
    if cubicspline_fit(1, 1, 1, 1) != 0 { return 1; };
    if cubicspline_fit(1, 1, 0, 1) != 0 { return 2; };
    return 0;
}

fn check_fit_null_ptrs() -> i64 {
    if cubicspline_fit(0, 1, 4, 1) != 0 { return 4; };
    if cubicspline_fit(1, 0, 4, 1) != 0 { return 8; };
    if cubicspline_fit(1, 1, 4, 0) != 0 { return 16; };
    return 0;
}

fn check_sample_n_lt_2() -> i64 {
    if cubicspline_sample(1, 1, 1, 1, f64_to_bits(0.5), 1) != 0 { return 32; };
    if cubicspline_sample(1, 1, 1, 0, f64_to_bits(0.5), 1) != 0 { return 64; };
    return 0;
}

fn check_sample_null_ptrs() -> i64 {
    if cubicspline_sample(0, 1, 1, 4, f64_to_bits(0.5), 1) != 0 { return 128; };
    if cubicspline_sample(1, 0, 1, 4, f64_to_bits(0.5), 1) != 0 { return 256; };
    if cubicspline_sample(1, 1, 0, 4, f64_to_bits(0.5), 1) != 0 { return 512; };
    if cubicspline_sample(1, 1, 1, 4, f64_to_bits(0.5), 0) != 0 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fit_n_lt_2();
    fails = fails + check_fit_null_ptrs();
    fails = fails + check_sample_n_lt_2();
    fails = fails + check_sample_null_ptrs();
    return fails;
}
