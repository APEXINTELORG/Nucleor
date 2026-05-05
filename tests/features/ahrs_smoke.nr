// v0.8.236 stdlib/rods/ahrs.nr first test coverage.
//
// Attitude & Heading Reference System via Mahony quaternion
// complementary filter. Pre-v0.8.236: zero coverage on the
// standalone rod.
//
// Locks four lifecycle invariants. set_orientation /
// get_orientation / get_euler / get_bias / update all use raw
// double[] pointers (q[4], rpy[3], gyro[3], accel[3]); deferred
// to dedicated IMU-fusion ships.
//
//   1. **ahrs_new returns valid handle** — non-zero for sensible
//      Kp/Ki gains.
//   2. **set_gains does not crash** — typical (Kp=1.0, Ki=0.05).
//   3. **set_gains with zero Ki (pure complementary)** — the
//      common default (Ki disables bias estimation).
//   4. **ahrs_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/ahrs.nr"

fn check_new_valid() -> i64 {
    let h: i64 = ahrs_new(f64_to_bits(1.0), f64_to_bits(0.05));
    if h == 0 { return 1; };
    ahrs_free(h);
    return 0;
}

fn check_set_gains_typical() -> i64 {
    let h: i64 = ahrs_new(f64_to_bits(1.0), f64_to_bits(0.05));
    ahrs_set_gains(h, f64_to_bits(2.0), f64_to_bits(0.1));
    ahrs_free(h);
    return 0;
}

fn check_set_gains_zero_ki() -> i64 {
    let h: i64 = ahrs_new(f64_to_bits(1.0), f64_to_bits(0.05));
    ahrs_set_gains(h, f64_to_bits(1.0), f64_to_bits(0.0));
    ahrs_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = ahrs_new(f64_to_bits(1.0), f64_to_bits(0.0));
    ahrs_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_set_gains_typical();
    fails = fails + check_set_gains_zero_ki();
    fails = fails + check_free_non_crashing();
    return fails;
}
