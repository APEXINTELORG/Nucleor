// v0.8.161 stdlib/rods/cspline.nr first test coverage.
//
// Natural cubic spline interpolation through (x, y) waypoints.
// Foundation for smooth-trajectory generation across joint/
// Cartesian waypoints. Pre-v0.8.161: zero coverage.
//
// Locks four textbook spline invariants:
//   1. Interpolation: spline passes through every supplied
//      waypoint exactly. eval(s, x_k) == y_k.
//   2. Linear data → linear spline: 3 collinear points (y=2x)
//      produce a spline with derivative ≈ 2 anywhere.
//   3. Natural BC: second derivative at boundary x_0 ≈ 0.
//   4. Strict-monotonic-x guard: solve returns 0 (failure) if
//      x is not strictly increasing.
//
// Expected: rc=0.

import "stdlib/rods/cspline.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_interpolation() -> i64 {
    let s: i64 = cspline_new(4);
    cspline_set_waypoint(s, 0, f64_to_bits(0.0), f64_to_bits(1.0));
    cspline_set_waypoint(s, 1, f64_to_bits(1.0), f64_to_bits(3.0));
    cspline_set_waypoint(s, 2, f64_to_bits(2.0), f64_to_bits(2.0));
    cspline_set_waypoint(s, 3, f64_to_bits(3.0), f64_to_bits(5.0));
    if cspline_solve(s) != 1 { cspline_free(s); return 1; };
    if close(cspline_eval(s, f64_to_bits(0.0)), f64_to_bits(1.0), 1e-9) != 1 { cspline_free(s); return 2; };
    if close(cspline_eval(s, f64_to_bits(1.0)), f64_to_bits(3.0), 1e-9) != 1 { cspline_free(s); return 4; };
    if close(cspline_eval(s, f64_to_bits(2.0)), f64_to_bits(2.0), 1e-9) != 1 { cspline_free(s); return 8; };
    if close(cspline_eval(s, f64_to_bits(3.0)), f64_to_bits(5.0), 1e-9) != 1 { cspline_free(s); return 16; };
    cspline_free(s);
    return 0;
}

fn check_linear_data_constant_derivative() -> i64 {
    let s: i64 = cspline_new(4);
    cspline_set_waypoint(s, 0, f64_to_bits(0.0), f64_to_bits(0.0));
    cspline_set_waypoint(s, 1, f64_to_bits(1.0), f64_to_bits(2.0));
    cspline_set_waypoint(s, 2, f64_to_bits(2.0), f64_to_bits(4.0));
    cspline_set_waypoint(s, 3, f64_to_bits(3.0), f64_to_bits(6.0));
    if cspline_solve(s) != 1 { cspline_free(s); return 32; };
    // Derivative at x=1.5 should be ≈ 2 (linear data → constant slope).
    let d: i64 = cspline_eval_derivative(s, f64_to_bits(1.5));
    if close(d, f64_to_bits(2.0), 1e-6) != 1 { cspline_free(s); return 64; };
    cspline_free(s);
    return 0;
}

fn check_natural_bc() -> i64 {
    let s: i64 = cspline_new(3);
    cspline_set_waypoint(s, 0, f64_to_bits(0.0), f64_to_bits(0.0));
    cspline_set_waypoint(s, 1, f64_to_bits(1.0), f64_to_bits(1.0));
    cspline_set_waypoint(s, 2, f64_to_bits(2.0), f64_to_bits(0.0));
    if cspline_solve(s) != 1 { cspline_free(s); return 128; };
    // Natural BC: y''(x_0) ≈ 0.
    let ypp_0: i64 = cspline_eval_second_derivative(s, f64_to_bits(0.0));
    if close(ypp_0, f64_to_bits(0.0), 1e-6) != 1 { cspline_free(s); return 256; };
    cspline_free(s);
    return 0;
}

fn check_non_monotonic_x_fails() -> i64 {
    let s: i64 = cspline_new(3);
    cspline_set_waypoint(s, 0, f64_to_bits(0.0), f64_to_bits(0.0));
    cspline_set_waypoint(s, 1, f64_to_bits(2.0), f64_to_bits(1.0));
    cspline_set_waypoint(s, 2, f64_to_bits(1.0), f64_to_bits(0.0)); // decreasing!
    let r: i64 = cspline_solve(s);
    cspline_free(s);
    if r != 0 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_interpolation();
    fails = fails + check_linear_data_constant_derivative();
    fails = fails + check_natural_bc();
    fails = fails + check_non_monotonic_x_fails();
    return fails;
}
