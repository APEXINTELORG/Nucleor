// v0.8.251 stdlib/rods/diff_drive.nr first test coverage.
//
// Differential-drive 2-wheel kinematics + odometry. Pre-v0.8.251:
// zero coverage on the standalone rod. The algorithmic paths
// need raw double[] output buffers; these fixtures lock the
// bad-input null-check + L>0 guards.
//
// Locks four bad-input invariants:
//
//   1. **Null v_out / w_out returns 0** — forward kinematics
//      (velocities) bad output.
//   2. **L ≤ 0 returns 0 in velocities** — degenerate track width.
//   3. **Null vl_out / vr_out returns 0** — inverse kinematics
//      bad output.
//   4. **L ≤ 0 in step / step_arc returns 0** — degenerate
//      kinematics integration.
//
// Expected: rc=0.

import "stdlib/rods/diff_drive.nr"

fn check_null_velocities_outs() -> i64 {
    let r1: i64 = diff_drive_velocities(
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.5),
        0, 0
    );
    if r1 != 0 { return 1; };
    let r2: i64 = diff_drive_velocities(
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.5),
        0, 1
    );
    if r2 != 0 { return 2; };
    return 0;
}

fn check_velocities_bad_L() -> i64 {
    let r: i64 = diff_drive_velocities(
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.0),
        1, 1
    );
    if r != 0 { return 4; };
    let r_neg: i64 = diff_drive_velocities(
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.0 - 0.5),
        1, 1
    );
    if r_neg != 0 { return 8; };
    return 0;
}

fn check_null_wheels_outs() -> i64 {
    let r: i64 = diff_drive_wheels(
        f64_to_bits(1.0), f64_to_bits(0.5), f64_to_bits(0.5),
        0, 0
    );
    if r != 0 { return 16; };
    return 0;
}

fn check_step_bad_L() -> i64 {
    // step
    let r1: i64 = diff_drive_step(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.0),
        f64_to_bits(0.1), 0
    );
    if r1 != 0 { return 32; };
    // step_arc
    let r2: i64 = diff_drive_step_arc(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(0.0),
        f64_to_bits(0.1), 0
    );
    if r2 != 0 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_velocities_outs();
    fails = fails + check_velocities_bad_L();
    fails = fails + check_null_wheels_outs();
    fails = fails + check_step_bad_L();
    return fails;
}
