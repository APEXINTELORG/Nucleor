// v0.8.239 stdlib/rods/prm.nr first test coverage.
//
// Probabilistic Roadmap motion planner. Pre-v0.8.239: zero
// coverage on the standalone rod. prm_build / prm_query need
// fn-pointer collision-check callbacks; deferred to dedicated
// motion-planning ships.
//
// Locks four lifecycle invariants:
//
//   1. prm_new returns valid handle — non-zero.
//   2. Empty roadmap — node_count and edge_count both 0
//      before build.
//   3. path_len before query is 0 — no query → no path.
//   4. set_bounds + free do not crash — exercises the
//      scalar bounds-setter path on every dimension.
//
// Expected: rc=0.

import "stdlib/rods/prm.nr"

fn check_new_valid() -> i64 {
    let h: i64 = prm_new(3, 42);
    if h == 0 { return 1; };
    prm_free(h);
    return 0;
}

fn check_empty_roadmap() -> i64 {
    let h: i64 = prm_new(3, 42);
    if prm_node_count(h) != 0 { prm_free(h); return 2; };
    if prm_edge_count(h) != 0 { prm_free(h); return 4; };
    prm_free(h);
    return 0;
}

fn check_path_len_zero_pre_query() -> i64 {
    let h: i64 = prm_new(3, 42);
    if prm_path_len(h) != 0 { prm_free(h); return 8; };
    prm_free(h);
    return 0;
}

fn check_set_bounds_each_dim() -> i64 {
    let h: i64 = prm_new(3, 42);
    prm_set_bounds(h, 0, f64_to_bits(0.0 - 1.0), f64_to_bits(1.0));
    prm_set_bounds(h, 1, f64_to_bits(0.0 - 2.0), f64_to_bits(2.0));
    prm_set_bounds(h, 2, f64_to_bits(0.0), f64_to_bits(10.0));
    prm_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_empty_roadmap();
    fails = fails + check_path_len_zero_pre_query();
    fails = fails + check_set_bounds_each_dim();
    return fails;
}
