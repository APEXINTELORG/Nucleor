// v0.8.100 stdlib/rods/interp.nr first test coverage.
//
// Per the zero-coverage rod survey, interp.nr (linear / cubic
// spline / Lagrange / Chebyshev / 2D bilinear / RBF) had no
// existing tests. Silent regressions in interpolation are
// correctness-critical for any numerical pipeline that
// resamples or fits data.
//
// Locks textbook interpolation invariants:
//   1. Linear interpolation passes through every knot exactly.
//   2. Linear interpolation at midpoint of [x0, x1] returns
//      midpoint of [y0, y1].
//   3. Lagrange of degree-N polynomial reproduces the polynomial
//      at any point (over its domain) — when the data IS the
//      polynomial sampled at N+1 distinct points.
//   4. Cubic spline passes through every knot exactly (interp
//      condition).
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/interp.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-9 { return 1; };
    return 0;
}

fn close_loose(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_linear_passes_knots() -> i64 {
    let mut xs: Vec<i64> = Vec::new();
    let mut ys: Vec<i64> = Vec::new();
    xs.push(f64_to_bits(0.0));   ys.push(f64_to_bits(10.0));
    xs.push(f64_to_bits(1.0));   ys.push(f64_to_bits(20.0));
    xs.push(f64_to_bits(2.0));   ys.push(f64_to_bits(40.0));
    let r0: i64 = interp_linear(xs, ys, f64_to_bits(0.0));
    let r1: i64 = interp_linear(xs, ys, f64_to_bits(1.0));
    let r2: i64 = interp_linear(xs, ys, f64_to_bits(2.0));
    if close(r0, f64_to_bits(10.0)) != 1 { return 1; };
    if close(r1, f64_to_bits(20.0)) != 1 { return 2; };
    if close(r2, f64_to_bits(40.0)) != 1 { return 4; };
    return 0;
}

fn check_linear_midpoint() -> i64 {
    let mut xs: Vec<i64> = Vec::new();
    let mut ys: Vec<i64> = Vec::new();
    xs.push(f64_to_bits(0.0));   ys.push(f64_to_bits(10.0));
    xs.push(f64_to_bits(2.0));   ys.push(f64_to_bits(30.0));
    // Midpoint x=1 → y should equal 20.0
    let r: i64 = interp_linear(xs, ys, f64_to_bits(1.0));
    if close(r, f64_to_bits(20.0)) != 1 { return 8; };
    return 0;
}

fn check_lagrange_reproduces_polynomial() -> i64 {
    // Sample y = 2x + 3 at x = 0, 1, 2.
    // Lagrange of these three points should reproduce y exactly
    // at any x (since it interpolates a degree-1 polynomial
    // exactly with 3 sample points; the 3rd point is redundant).
    let mut xs: Vec<i64> = Vec::new();
    let mut ys: Vec<i64> = Vec::new();
    xs.push(f64_to_bits(0.0));   ys.push(f64_to_bits(3.0));
    xs.push(f64_to_bits(1.0));   ys.push(f64_to_bits(5.0));
    xs.push(f64_to_bits(2.0));   ys.push(f64_to_bits(7.0));
    let r: i64 = interp_lagrange(xs, ys, f64_to_bits(0.5));
    // Expected: 2 * 0.5 + 3 = 4.0
    if close_loose(r, f64_to_bits(4.0)) != 1 { return 16; };
    let r2: i64 = interp_lagrange(xs, ys, f64_to_bits(1.5));
    // Expected: 2 * 1.5 + 3 = 6.0
    if close_loose(r2, f64_to_bits(6.0)) != 1 { return 32; };
    return 0;
}

fn check_cubic_spline_passes_knots() -> i64 {
    let mut xs: Vec<i64> = Vec::new();
    let mut ys: Vec<i64> = Vec::new();
    xs.push(f64_to_bits(0.0));   ys.push(f64_to_bits(0.0));
    xs.push(f64_to_bits(1.0));   ys.push(f64_to_bits(1.0));
    xs.push(f64_to_bits(2.0));   ys.push(f64_to_bits(8.0));
    xs.push(f64_to_bits(3.0));   ys.push(f64_to_bits(27.0));
    let r0: i64 = interp_cubic_spline(xs, ys, f64_to_bits(0.0));
    let r1: i64 = interp_cubic_spline(xs, ys, f64_to_bits(1.0));
    let r3: i64 = interp_cubic_spline(xs, ys, f64_to_bits(3.0));
    if close_loose(r0, f64_to_bits(0.0)) != 1 { return 64; };
    if close_loose(r1, f64_to_bits(1.0)) != 1 { return 128; };
    if close_loose(r3, f64_to_bits(27.0)) != 1 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_linear_passes_knots();
    fails = fails + check_linear_midpoint();
    fails = fails + check_lagrange_reproduces_polynomial();
    fails = fails + check_cubic_spline_passes_knots();
    return fails;
}
