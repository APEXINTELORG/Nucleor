// v0.8.253 stdlib/rods/bicycle.nr first test coverage.
//
// Kinematic bicycle model (rear-axle pose, front-wheel steering).
// Pre-v0.8.253: zero coverage on the standalone rod. The
// algorithmic paths (Euler + RK4) need raw double[3] output
// buffers; bad-input fixtures lock the L>0 + null-out_ptr guards.
//
// Locks four bad-input invariants on both integrators:
//
//   1. **Null out_ptr in step_euler returns 0** — bad output.
//   2. **L ≤ 0 in step_euler returns 0** — degenerate wheelbase.
//   3. **Null out_ptr in step_rk4 returns 0** — bad output.
//   4. **L ≤ 0 in step_rk4 returns 0** — degenerate wheelbase.
//
// Expected: rc=0.

import "stdlib/rods/bicycle.nr"

fn check_null_out_euler() -> i64 {
    let r: i64 = bicycle_step_euler(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(2.5), f64_to_bits(0.05), 0
    );
    if r != 0 { return 1; };
    return 0;
}

fn check_bad_L_euler() -> i64 {
    let r0: i64 = bicycle_step_euler(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.05), 1
    );
    if r0 != 0 { return 2; };
    let rn: i64 = bicycle_step_euler(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.05), 1
    );
    if rn != 0 { return 4; };
    return 0;
}

fn check_null_out_rk4() -> i64 {
    let r: i64 = bicycle_step_rk4(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(2.5), f64_to_bits(0.05), 0
    );
    if r != 0 { return 8; };
    return 0;
}

fn check_bad_L_rk4() -> i64 {
    let r0: i64 = bicycle_step_rk4(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(0.0), f64_to_bits(0.05), 1
    );
    if r0 != 0 { return 16; };
    let rn: i64 = bicycle_step_rk4(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.1),
        f64_to_bits(0.0 - 1.0), f64_to_bits(0.05), 1
    );
    if rn != 0 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_out_euler();
    fails = fails + check_bad_L_euler();
    fails = fails + check_null_out_rk4();
    fails = fails + check_bad_L_rk4();
    return fails;
}
