// v0.8.240 stdlib/rods/mpc.nr first test coverage.
//
// Receding-horizon MPC wrapper around iLQR. Pre-v0.8.240: zero
// coverage on the standalone rod. set_callbacks / warm_start /
// step all use fn-pointers or raw double[]; deferred to dedicated
// control-loop ships.
//
// Locks four lifecycle invariants:
//
//   1. mpc_new returns valid handle — non-zero.
//   2. last_iters == 0 pre-step — no MPC ticks yet.
//   3. mpc_reset does not crash — re-zero the warm-start
//      sequence.
//   4. mpc_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/mpc.nr"

fn check_new_valid() -> i64 {
    let m: i64 = mpc_new(4, 2, 20, 10);
    if m == 0 { return 1; };
    nuc_mpc_free(m);
    return 0;
}

fn check_last_iters_zero_pre_step() -> i64 {
    let m: i64 = mpc_new(4, 2, 20, 10);
    if nuc_mpc_last_iters(m) != 0 { nuc_mpc_free(m); return 2; };
    nuc_mpc_free(m);
    return 0;
}

fn check_reset_no_crash() -> i64 {
    let m: i64 = mpc_new(4, 2, 20, 10);
    nuc_mpc_reset(m);
    nuc_mpc_free(m);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let m: i64 = mpc_new(2, 1, 5, 3);
    nuc_mpc_free(m);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_last_iters_zero_pre_step();
    fails = fails + check_reset_no_crash();
    fails = fails + check_free_non_crashing();
    return fails;
}
