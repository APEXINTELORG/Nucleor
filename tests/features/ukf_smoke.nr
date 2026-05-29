// v0.8.244 stdlib/rods/ukf.nr first test coverage.
//
// Unscented Kalman Filter (sigma-point variant of EKF). Pre-
// v0.8.244: zero coverage on the standalone rod (sister to
// ekf.nr Jacobian-based variant covered in v0.8.238).
//
// Locks four lifecycle invariants. set_state / set_covariance /
// set_process_noise / set_measurement_noise / get_state /
// predict / update all use raw double[] pointers; deferred to
// dedicated sensor-fusion ships.
//
//   1. ukf_new with reasonable dims — non-zero handle.
//   2. n_u=0 still works — autonomous system (no control
//      input).
//   3. Multiple distinct UKFs — two constructions →
//      distinct handles.
//   4. ukf_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/ukf.nr"

fn check_new_valid() -> i64 {
    let h: i64 = ukf_new(4, 2, 1);
    if h == 0 { return 1; };
    ukf_free(h);
    return 0;
}

fn check_n_u_zero() -> i64 {
    let h: i64 = ukf_new(4, 2, 0);
    if h == 0 { return 2; };
    ukf_free(h);
    return 0;
}

fn check_distinct_handles() -> i64 {
    let a: i64 = ukf_new(2, 1, 0);
    let b: i64 = ukf_new(2, 1, 0);
    let same: i64 = if a == b { 1 } else { 0 };
    ukf_free(a);
    ukf_free(b);
    if same == 1 { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = ukf_new(3, 3, 1);
    ukf_free(h);
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
