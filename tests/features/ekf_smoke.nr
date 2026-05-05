// v0.8.238 stdlib/rods/ekf.nr first test coverage.
//
// Extended Kalman Filter for nonlinear state estimation. Pre-
// v0.8.238: zero coverage on the standalone rod. set_state /
// set_covariance / set_process_noise / set_measurement_noise /
// get_state / predict / update all use raw double[] pointers;
// deferred to dedicated SLAM / sensor-fusion ships.
//
// Locks four lifecycle invariants on the n_x / n_z / n_u
// constructor variants:
//
//   1. **ekf_new with reasonable dims** — non-zero handle.
//   2. **State/measurement-only filter** — n_u=0 still returns
//      a valid handle (autonomous system, no control input).
//   3. **Multiple distinct EKFs** — two constructions return
//      distinct handles (no aliased state).
//   4. **ekf_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/ekf.nr"

fn check_new_valid() -> i64 {
    let h: i64 = ekf_new(4, 2, 1);
    if h == 0 { return 1; };
    ekf_free(h);
    return 0;
}

fn check_n_u_zero() -> i64 {
    let h: i64 = ekf_new(4, 2, 0);
    if h == 0 { return 2; };
    ekf_free(h);
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = ekf_new(2, 1, 0);
    let b: i64 = ekf_new(2, 1, 0);
    let same: i64 = if a == b { 1 } else { 0 };
    ekf_free(a);
    ekf_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = ekf_new(3, 3, 1);
    ekf_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_n_u_zero();
    fails = fails + check_distinct_handles();
    fails = fails + check_free_non_crashing();
    return fails;
}
