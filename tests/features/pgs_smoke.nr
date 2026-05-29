// v0.8.234 stdlib/rods/pgs.nr first test coverage.
//
// 2-D pose graph SLAM optimizer (Gauss-Newton). Pre-v0.8.234:
// zero coverage on the standalone rod (sister to ICP front-end +
// pgs3 3-D variant).
//
// Setup: 2 nodes. Node 0 fixed at origin (gauge). Node 1 starts
// at (0.5, 0, 0) but the edge measurement says it should be at
// (1, 0, 0) in node 0's frame. Initial cost > 0; after optimize,
// node 1 should move to (1, 0, 0) and cost should drop to ~0.
//
// Locks four invariants:
//
//   1. Empty graph cost is zero — no edges → no error.
//   2. Initial cost > 0 with mismatched node + edge.
//   3. Optimize iters > 0 for non-trivial problem.
//   4. Cost decreases after optimize: post < pre.
//
// pgs_get_node uses raw out-ptrs; deferred.
//
// Expected: rc=0.

import "stdlib/rods/pgs.nr"

fn check_empty_cost_zero() -> i64 {
    let g: i64 = pgs_new(2);
    let c: f64 = f64_from_bits(pgs_total_cost(g));
    pgs_free(g);
    if c != 0.0 { return 1; };
    return 0;
}

fn check_initial_cost_positive() -> i64 {
    let g: i64 = pgs_new(2);
    pgs_set_node(g, 0, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_set_node(g, 1, f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_add_edge(g, 0, 1,
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0)
    );
    let c: f64 = f64_from_bits(pgs_total_cost(g));
    pgs_free(g);
    if c <= 0.0 { return 2; };
    return 0;
}

fn check_optimize_iters_positive() -> i64 {
    let g: i64 = pgs_new(2);
    pgs_set_node(g, 0, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_set_node(g, 1, f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_add_edge(g, 0, 1,
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0)
    );
    let iters: i64 = pgs_optimize(g, 50, f64_to_bits(1e-6));
    pgs_free(g);
    if iters <= 0 { return 4; };
    return 0;
}

fn check_cost_decreases() -> i64 {
    let g: i64 = pgs_new(2);
    pgs_set_node(g, 0, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_set_node(g, 1, f64_to_bits(0.5), f64_to_bits(0.0), f64_to_bits(0.0));
    pgs_add_edge(g, 0, 1,
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0)
    );
    let pre: f64 = f64_from_bits(pgs_total_cost(g));
    pgs_optimize(g, 50, f64_to_bits(1e-9));
    let post: f64 = f64_from_bits(pgs_total_cost(g));
    pgs_free(g);
    if post >= pre { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_cost_zero();
    fails = fails + check_initial_cost_positive();
    fails = fails + check_optimize_iters_positive();
    fails = fails + check_cost_decreases();
    return fails;
}
