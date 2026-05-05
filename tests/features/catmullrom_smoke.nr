// v0.8.249 stdlib/rods/catmullrom.nr first test coverage.
//
// Catmull-Rom spline evaluation in 2-D and 3-D (centripetal
// parameterization). Pre-v0.8.249: zero coverage on the
// standalone rod. The algorithmic path needs raw double[]
// control-point arrays; deferred to dedicated path-authoring
// ships once Vec → raw-ptr bridge lands.
//
// Locks four bad-input invariants — the runtime requires
// `n_ctrl ≥ 4` (segment between i+1 and i+2 needs neighbors
// i and i+3) and null-checks `ctrl_ptr` and `out_ptr`:
//
//   1. **n_ctrl < 4 returns 0** — degenerate (cannot form a
//      segment with neighbors).
//   2. **Null ctrl_ptr returns 0** in 2-D.
//   3. **Null out_ptr returns 0** in 2-D.
//   4. **3-D variant has the same n ≥ 4 + null-check guards**.
//
// Expected: rc=0.

import "stdlib/rods/catmullrom.nr"

fn check_n_lt_4_2d() -> i64 {
    let r: i64 = catmullrom_eval_2d(1, 3, f64_to_bits(0.0), f64_to_bits(0.5), 1);
    if r != 0 { return 1; };
    let r0: i64 = catmullrom_eval_2d(1, 0, f64_to_bits(0.0), f64_to_bits(0.5), 1);
    if r0 != 0 { return 2; };
    return 0;
}

fn check_null_ctrl_2d() -> i64 {
    let r: i64 = catmullrom_eval_2d(0, 4, f64_to_bits(0.0), f64_to_bits(0.5), 1);
    if r != 0 { return 4; };
    return 0;
}

fn check_null_out_2d() -> i64 {
    let r: i64 = catmullrom_eval_2d(1, 4, f64_to_bits(0.0), f64_to_bits(0.5), 0);
    if r != 0 { return 8; };
    return 0;
}

fn check_3d_guards() -> i64 {
    // n < 4
    let r1: i64 = catmullrom_eval_3d(1, 2, f64_to_bits(0.0), f64_to_bits(0.5), 1);
    if r1 != 0 { return 16; };
    // Null ctrl
    let r2: i64 = catmullrom_eval_3d(0, 4, f64_to_bits(0.0), f64_to_bits(0.5), 1);
    if r2 != 0 { return 32; };
    // Null out
    let r3: i64 = catmullrom_eval_3d(1, 4, f64_to_bits(0.0), f64_to_bits(0.5), 0);
    if r3 != 0 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_n_lt_4_2d();
    fails = fails + check_null_ctrl_2d();
    fails = fails + check_null_out_2d();
    fails = fails + check_3d_guards();
    return fails;
}
