// v0.8.248 stdlib/rods/bezier.nr first test coverage.
//
// Bezier curve evaluation in 2-D and 3-D via de Casteljau.
// Pre-v0.8.248: zero coverage on the standalone rod. The
// algorithmic path needs raw double[] control-point arrays;
// real curve evaluation is deferred to dedicated path-authoring
// ships once the Vec → raw-ptr bridge lands.
//
// Locks four bad-input invariants — the runtime null-checks
// both `ctrl_ptr` and `out_ptr` and validates `n_ctrl ≥ 2`:
//
//   1. Null ctrl_ptr returns 0 in 2-D.
//   2. Null out_ptr returns 0 in 2-D.
//   3. n_ctrl < 2 returns 0 — degenerate curve.
//   4. 3-D variant returns 0 on null inputs — same null-
//      check shape as 2-D.
//
// Expected: rc=0.

import "stdlib/rods/bezier.nr"

fn check_null_ctrl_2d() -> i64 {
    let r: i64 = bezier_eval_2d(0, 4, f64_to_bits(0.5), 1);
    if r != 0 { return 1; };
    return 0;
}

fn check_null_out_2d() -> i64 {
    let r: i64 = bezier_eval_2d(1, 4, f64_to_bits(0.5), 0);
    if r != 0 { return 2; };
    return 0;
}

fn check_n_lt_2() -> i64 {
    let r: i64 = bezier_eval_2d(1, 1, f64_to_bits(0.5), 1);
    if r != 0 { return 4; };
    let r0: i64 = bezier_eval_2d(1, 0, f64_to_bits(0.5), 1);
    if r0 != 0 { return 8; };
    return 0;
}

fn check_3d_null_returns_zero() -> i64 {
    let r: i64 = bezier_eval_3d(0, 4, f64_to_bits(0.5), 0);
    if r != 0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_ctrl_2d();
    fails = fails + check_null_out_2d();
    fails = fails + check_n_lt_2();
    fails = fails + check_3d_null_returns_zero();
    return fails;
}
