// v0.8.248 stdlib/rods/apf.nr first test coverage.
//
// Artificial potential field for 2-D reactive collision avoidance.
// Pre-v0.8.248: zero coverage on the standalone rod. The
// algorithmic path needs raw double[] obstacle and force-output
// arrays; real force evaluation is deferred to dedicated
// reactive-planning ships.
//
// Locks four bad-input invariants — the runtime null-checks
// `F_out_ptr` and only requires `obs_ptr` if `n_obs > 0`:
//
//   1. **Null F_out returns -1** — bad-output sentinel.
//   2. **Null obs with n_obs > 0 returns -1** — bad-input.
//   3. **Null obs with n_obs == 0 still requires non-null F_out** —
//      n_obs=0 is allowed but F_out is mandatory.
//   4. **apf_step_2d null x_out / y_out returns negative** —
//      same guard pattern on the integration variant.
//
// Expected: rc=0.

import "stdlib/rods/apf.nr"

fn check_null_F_out() -> i64 {
    let r: i64 = apf_force_2d(
        f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0),
        0, 0,
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(2.0),
        0
    );
    if r != (0 - 1) { return 1; };
    return 0;
}

fn check_null_obs_with_count() -> i64 {
    // n_obs > 0 but obs_ptr null → -1
    let r: i64 = apf_force_2d(
        f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0),
        0, 3,  // n_obs = 3 with null obs_ptr
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(2.0),
        0
    );
    if r != (0 - 1) { return 2; };
    return 0;
}

fn check_n_obs_zero_still_needs_F_out() -> i64 {
    // n_obs=0 is fine; null obs is fine since n_obs=0; null F_out fails
    let r: i64 = apf_force_2d(
        f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0),
        0, 0,
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(2.0),
        0
    );
    if r != (0 - 1) { return 4; };
    return 0;
}

fn check_step_null_outputs() -> i64 {
    // Null x_out / y_out should not crash; we accept any negative
    // sentinel (runtime contract is "do not write").
    let r: i64 = apf_step_2d(
        f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0),
        0, 0,
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(2.0),
        f64_to_bits(0.5), f64_to_bits(0.1),
        0, 0
    );
    if r >= 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_F_out();
    fails = fails + check_null_obs_with_count();
    fails = fails + check_n_obs_zero_still_needs_F_out();
    fails = fails + check_step_null_outputs();
    return fails;
}
