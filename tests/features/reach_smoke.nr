// v0.8.239 stdlib/rods/reach.nr first test coverage.
//
// Monte Carlo reachability mapper for arm robots. Pre-v0.8.239:
// zero coverage on the standalone rod. reach_compute needs an
// fk_fp callback; reach_workspace_extent uses raw out_ptr; both
// deferred to dedicated workspace-analysis ships.
//
// Locks four lifecycle invariants:
//
//   1. **reach_new returns valid handle** — non-zero.
//   2. **Empty sampler** — count == 0 before reach_compute.
//   3. **set_joint_limit on each dim** — no crash exercising
//      the per-joint bounds-setter.
//   4. **reach_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/reach.nr"

fn check_new_valid() -> i64 {
    let h: i64 = reach_new(6, 1000, 42);
    if h == 0 { return 1; };
    reach_free(h);
    return 0;
}

fn check_count_zero_pre_compute() -> i64 {
    let h: i64 = reach_new(6, 1000, 42);
    if reach_count(h) != 0 { reach_free(h); return 2; };
    reach_free(h);
    return 0;
}

fn check_set_joint_limit_each_dim() -> i64 {
    let h: i64 = reach_new(3, 100, 1);
    reach_set_joint_limit(h, 0,
        f64_to_bits(0.0 - 3.14159), f64_to_bits(3.14159));
    reach_set_joint_limit(h, 1,
        f64_to_bits(0.0 - 1.5), f64_to_bits(1.5));
    reach_set_joint_limit(h, 2,
        f64_to_bits(0.0), f64_to_bits(2.0));
    reach_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = reach_new(2, 50, 999);
    reach_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_count_zero_pre_compute();
    fails = fails + check_set_joint_limit_each_dim();
    fails = fails + check_free_non_crashing();
    return fails;
}
