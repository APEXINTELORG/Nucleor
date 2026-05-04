// v0.8.109 stdlib/rods/bspline.nr first test coverage.
//
// Per the zero-coverage rod survey, bspline.nr (B-splines + KAN
// forward pass) had no existing tests. Silent regressions in
// basis-function or evaluation would invalidate any KAN
// (Kolmogorov-Arnold) network or spline-based modeling code.
//
// Locks textbook B-spline invariants:
//   1. Uniform knots: bspline_uniform_knots(n_basis, order,
//      lo, hi) returns a vector of length n_basis + order with
//      knots starting at lo and ending at hi.
//   2. Partition of unity: B-spline basis functions sum to ~1.0
//      at any x within the active domain (the textbook PoU
//      property).
//   3. Constant-control-point evaluation: if all control points
//      are c, then B(x) = c for any x in the active domain
//      (because basis functions sum to 1).
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bspline.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_uniform_knot_count() -> i64 {
    // n_basis=5, order=4 → expected knot count = n_basis + order = 9.
    let knots: i64 = bspline_uniform_knots(5, 4, f64_to_bits(0.0), f64_to_bits(1.0));
    if vec_len(knots) != 9 { return 1; };
    return 0;
}

fn check_partition_of_unity() -> i64 {
    // Cubic (order=4) with 5 basis functions on [0, 1].
    // Sum of basis functions at any interior point should be 1.
    let knots: i64 = bspline_uniform_knots(5, 4, f64_to_bits(0.0), f64_to_bits(1.0));
    let basis: i64 = bspline_basis_all(knots, 5, 4, f64_to_bits(0.5));
    if vec_len(basis) != 5 { return 2; };
    let mut sum: f64 = 0.0;
    let mut i: i64 = 0;
    while i < 5 {
        sum = sum + f64_from_bits(vec_get(basis, i));
        i = i + 1;
    };
    let abs_diff: f64 = if sum > 1.0 { sum - 1.0 } else { 1.0 - sum };
    if abs_diff > 1e-6 { return 4; };
    return 0;
}

fn check_constant_control_evaluation() -> i64 {
    // Constant control points c=7.0; B(x) should equal 7.0
    // because basis sum is 1 (partition of unity).
    let knots: i64 = bspline_uniform_knots(5, 4, f64_to_bits(0.0), f64_to_bits(1.0));
    let mut ctrl: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 5 {
        ctrl.push(f64_to_bits(7.0));
        i = i + 1;
    };
    let v: i64 = bspline_eval(knots, ctrl, 4, f64_to_bits(0.3));
    if close(v, f64_to_bits(7.0)) != 1 { return 8; };
    let v2: i64 = bspline_eval(knots, ctrl, 4, f64_to_bits(0.6));
    if close(v2, f64_to_bits(7.0)) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_uniform_knot_count();
    fails = fails + check_partition_of_unity();
    fails = fails + check_constant_control_evaluation();
    return fails;
}
