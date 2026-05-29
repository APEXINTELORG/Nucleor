// v0.8.240 stdlib/rods/mppi.nr first test coverage.
//
// Model Predictive Path Integral control — sample-based MPC.
// Pre-v0.8.240: zero coverage on the standalone rod (sister to
// mpc.nr gradient-based receding-horizon control).
//
// Locks four lifecycle invariants. set_callbacks / warm_start /
// step all use fn-pointers / raw double[]; deferred to dedicated
// control-loop ships.
//
//   1. mppi_new returns valid handle — non-zero.
//   2. set_sigma per dim — exercises the scalar per-dim
//      noise-stddev setter.
//   3. mppi_reset does not crash — re-zero the warm-start
//      nominal.
//   4. mppi_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/mppi.nr"

fn check_new_valid() -> i64 {
    let h: i64 = mppi_new(4, 2, 20, 256, f64_to_bits(1.0), 42);
    if h == 0 { return 1; };
    nuc_mppi_free(h);
    return 0;
}

fn check_set_sigma_per_dim() -> i64 {
    let h: i64 = mppi_new(4, 3, 20, 256, f64_to_bits(1.0), 42);
    mppi_set_sigma(h, 0, f64_to_bits(0.5));
    mppi_set_sigma(h, 1, f64_to_bits(1.0));
    mppi_set_sigma(h, 2, f64_to_bits(2.0));
    nuc_mppi_free(h);
    return 0;
}

fn check_reset_no_crash() -> i64 {
    let h: i64 = mppi_new(2, 1, 10, 64, f64_to_bits(1.0), 0);
    nuc_mppi_reset(h);
    nuc_mppi_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = mppi_new(2, 1, 5, 32, f64_to_bits(1.0), 999);
    nuc_mppi_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_set_sigma_per_dim();
    fails = fails + check_reset_no_crash();
    fails = fails + check_free_non_crashing();
    return fails;
}
