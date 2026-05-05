// v0.8.238 stdlib/rods/astar.nr first test coverage.
//
// A* shortest-path search on a generic weighted graph. Pre-
// v0.8.238: zero coverage on the standalone rod.
//
// Locks four lifecycle invariants. astar_search needs fn-pointer
// callbacks (neighbor_fn / heuristic_fn) which require closure
// surface; deferred to dedicated graph-search ships.
//
//   1. **astar_new returns valid handle** — non-zero for
//      reasonable n_nodes.
//   2. **path_len before search is 0** — no search → no path.
//   3. **path_at on empty path returns -1** — out-of-bounds /
//      pre-search is the runtime's "no-such-path-step" sentinel.
//   4. **astar_free does not crash** on a freshly constructed
//      handle.
//
// Expected: rc=0.

import "stdlib/rods/astar.nr"

fn check_new_valid() -> i64 {
    let h: i64 = astar_new(8);
    if h == 0 { return 1; };
    astar_free(h);
    return 0;
}

fn check_path_len_zero_pre_search() -> i64 {
    let h: i64 = astar_new(8);
    if astar_path_len(h) != 0 { astar_free(h); return 2; };
    astar_free(h);
    return 0;
}

fn check_path_at_pre_search() -> i64 {
    let h: i64 = astar_new(8);
    let v: i64 = astar_path_at(h, 0);
    astar_free(h);
    if v != (0 - 1) { return 4; };
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let h: i64 = astar_new(4);
    astar_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_path_len_zero_pre_search();
    fails = fails + check_path_at_pre_search();
    fails = fails + check_free_non_crashing();
    return fails;
}
