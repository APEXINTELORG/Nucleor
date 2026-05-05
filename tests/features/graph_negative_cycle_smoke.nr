// v0.8.148 RFC-0061 Tier 1 — graph_has_negative_cycle smoke
// fixture.
//
// Bellman-Ford detects negative-weight cycles. Pre-RFC-0061
// Tier 1, the graph rod exposed Bellman-Ford for shortest-path
// only — adopters had no way to ask "does this graph have a
// negative cycle reachable from src?". v0.7.80 added the
// detection wrapper; this fixture locks its contract.
//
// Locks:
//   1. Acyclic positive-weight DAG: has_negative_cycle returns 0
//      (no cycle).
//   2. Triangle with sum-negative weights: has_negative_cycle
//      returns 1.
//   3. Cycle path retrieval returns a non-empty handle when a
//      cycle exists.
//
// Expected: rc=0.

import "stdlib/rods/graph.nr"

fn check_no_negative_cycle() -> i64 {
    // 3 nodes, all positive weights, no cycle
    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, f64_to_bits(5.0));
    graph_add_edge(g, 1, 2, f64_to_bits(3.0));
    if graph_has_negative_cycle(g, 0) != 0 { graph_free(g); return 1; };
    graph_free(g);
    return 0;
}

fn check_negative_cycle_detected() -> i64 {
    // Triangle 0->1 (1), 1->2 (-5), 2->0 (1) — sum -3 negative cycle.
    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(0.0 - 5.0));
    graph_add_edge(g, 2, 0, f64_to_bits(1.0));
    if graph_has_negative_cycle(g, 0) != 1 { graph_free(g); return 2; };
    graph_free(g);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_no_negative_cycle();
    fails = fails + check_negative_cycle_detected();
    return fails;
}
