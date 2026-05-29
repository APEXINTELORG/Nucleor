// v0.8.244 stdlib/rods/rrt.nr first test coverage.
//
// Rapidly-exploring Random Tree motion planner. Pre-v0.8.244:
// zero coverage on the standalone rod. plan / connect_plan /
// star_plan / star_plan_informed / shortcut_path all need fn-
// pointer collision callbacks; deferred to dedicated motion-
// planning ships.
//
// Locks four lifecycle invariants:
//
//   1. rrt_new returns valid handle — non-zero.
//   2. path_len before plan is 0 — no plan → no path.
//   3. node_count before plan is 0 — empty tree.
//   4. set_bounds + free do not crash — exercises the
//      scalar bounds-setter on every dimension.
//
// Expected: rc=0.

import "stdlib/rods/rrt.nr"

fn check_new_valid() -> i64 {
    let h: i64 = rrt_new(3, 42);
    if h == 0 { return 1; };
    nuc_rrt_free(h);
    return 0;
}

fn check_path_len_zero_pre_plan() -> i64 {
    let h: i64 = rrt_new(3, 42);
    if nuc_rrt_path_len(h) != 0 { nuc_rrt_free(h); return 2; };
    nuc_rrt_free(h);
    return 0;
}

fn check_node_count_zero_pre_plan() -> i64 {
    let h: i64 = rrt_new(3, 42);
    if nuc_rrt_node_count(h) != 0 { nuc_rrt_free(h); return 4; };
    nuc_rrt_free(h);
    return 0;
}

fn check_set_bounds_each_dim() -> i64 {
    let h: i64 = rrt_new(3, 42);
    rrt_set_bounds(h, 0, f64_to_bits(0.0 - 1.0), f64_to_bits(1.0));
    rrt_set_bounds(h, 1, f64_to_bits(0.0 - 2.0), f64_to_bits(2.0));
    rrt_set_bounds(h, 2, f64_to_bits(0.0), f64_to_bits(10.0));
    nuc_rrt_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_path_len_zero_pre_plan();
    fails = fails + check_node_count_zero_pre_plan();
    fails = fails + check_set_bounds_each_dim();
    return fails;
}
