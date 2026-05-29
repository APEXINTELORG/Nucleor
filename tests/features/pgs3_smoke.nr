// v0.8.242 stdlib/rods/pgs3.nr first test coverage.
//
// 3-D pose graph SLAM optimizer (SE(3) Gauss-Newton). Pre-
// v0.8.242: zero coverage on the standalone rod (sister to
// pgs.nr 2-D variant covered in v0.8.234).
//
// Locks four lifecycle invariants. set_node / add_edge /
// get_node use raw double[] pointers; Gauss-Newton convergence
// (cost-decreases) is exercised by the 2-D pgs_smoke and
// generalizes to 3-D.
//
//   1. pgs3_new returns valid handle — non-zero.
//   2. Empty graph cost is zero — no edges → no error.
//   3. Multiple distinct graphs — two constructions →
//      distinct handles (no aliased state).
//   4. pgs3_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/pgs3.nr"

fn check_new_valid() -> i64 {
    let g: i64 = pgs3_new(4);
    if g == 0 { return 1; };
    pgs3_free(g);
    return 0;
}

fn check_empty_cost_zero() -> i64 {
    let g: i64 = pgs3_new(4);
    let c: f64 = f64_from_bits(pgs3_total_cost(g));
    pgs3_free(g);
    if c != 0.0 { return 2; };
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = pgs3_new(2);
    let b: i64 = pgs3_new(2);
    let same: i64 = if a == b { 1 } else { 0 };
    pgs3_free(a);
    pgs3_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let g: i64 = pgs3_new(3);
    pgs3_free(g);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_empty_cost_zero();
    fails = fails + check_distinct_handles();
    fails = fails + check_free_non_crashing();
    return fails;
}
