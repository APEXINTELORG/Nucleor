// v0.8.243 stdlib/rods/fsp.nr first test coverage.
//
// Bipedal footstep planner — discrete A* over reachable footstep
// poses. Pre-v0.8.243: zero coverage on the standalone rod. plan
// uses fn-pointer valid_fp; deferred to dedicated locomotion ships.
//
// Locks four lifecycle invariants:
//
//   1. fsp_new returns valid handle — non-zero.
//   2. path_len before plan is 0 — no plan → no path.
//   3. set_resolution + set_goal_tolerance + add_action
//      do not crash on the scalar-only path.
//   4. fsp_free does not crash on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/fsp.nr"

fn check_new_valid() -> i64 {
    let h: i64 = fsp_new();
    if h == 0 { return 1; };
    fsp_free(h);
    return 0;
}

fn check_path_len_zero_pre_plan() -> i64 {
    let h: i64 = fsp_new();
    if fsp_path_len(h) != 0 { fsp_free(h); return 2; };
    fsp_free(h);
    return 0;
}

fn check_setters_do_not_crash() -> i64 {
    let h: i64 = fsp_new();
    fsp_set_resolution(h, f64_to_bits(0.05), f64_to_bits(0.087));
    fsp_set_goal_tolerance(h, f64_to_bits(0.10), f64_to_bits(0.17));
    fsp_add_action(h,
        f64_to_bits(0.20), f64_to_bits(0.10), f64_to_bits(0.0),
        f64_to_bits(1.0)
    );
    fsp_add_action(h,
        f64_to_bits(0.0), f64_to_bits(0.10), f64_to_bits(0.0),
        f64_to_bits(0.5)
    );
    fsp_free(h);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = fsp_new();
    fsp_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_path_len_zero_pre_plan();
    fails = fails + check_setters_do_not_crash();
    fails = fails + check_free_non_crashing();
    return fails;
}
