// v0.8.246 stdlib/rods/dubins.nr first test coverage.
//
// Shortest path for a car-like robot with minimum turning radius
// (Dubins 1957). Pre-v0.8.246: zero coverage on the standalone
// rod.
//
// The C runtime null-checks `type_out_ptr`, so we can pass 0 to
// skip the type-id output and exercise the length-only path.
//
// Locks four classical Dubins invariants:
//
//   1. **Straight-line path** — start (0,0,0) → goal (5,0,0) with
//      R=1: collinear poses with same heading give path length 5
//      (degenerate LSL with t=0, p=5, q=0).
//   2. **Negative R returns -1** — invalid input sentinel.
//   3. **Self-pose returns 0** — start ≡ goal gives path length
//      0 (or very close).
//   4. **Larger separation gives larger length** — start (0,0,0)
//      → (10,0,0) longer than (0,0,0) → (5,0,0) at same R.
//
// Expected: rc=0.

import "stdlib/rods/dubins.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_straight_line() -> i64 {
    let len: i64 = dubins_shortest(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), 0
    );
    if close(len, f64_to_bits(5.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_negative_R_returns_minus_one() -> i64 {
    let len: i64 = dubins_shortest(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0 - 1.0), 0
    );
    if close(len, f64_to_bits(0.0 - 1.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_self_pose_zero() -> i64 {
    let len: i64 = dubins_shortest(
        f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(0.5),
        f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(0.5),
        f64_to_bits(1.0), 0
    );
    if close(len, f64_to_bits(0.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_larger_separation_longer_path() -> i64 {
    let short: i64 = dubins_shortest(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), 0
    );
    let long: i64 = dubins_shortest(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), 0
    );
    let sf: f64 = f64_from_bits(short);
    let lf: f64 = f64_from_bits(long);
    if lf <= sf { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_straight_line();
    fails = fails + check_negative_R_returns_minus_one();
    fails = fails + check_self_pose_zero();
    fails = fails + check_larger_separation_longer_path();
    return fails;
}
