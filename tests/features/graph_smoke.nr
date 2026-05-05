// v0.8.193 stdlib/rods/graph.nr first test coverage (BFS / DFS /
// Dijkstra / topo-sort / connected-components).
//
// graph rod has partial coverage already: negative-cycle
// detection (v0.8.148), adjacency matrix (v0.8.148),
// gnn_circuit_to_graph (v0.8.148). This fixture locks the
// classical algorithm surface that didn't have direct coverage.
//
// Locks five textbook graph-algorithm invariants:
//
//   1. **BFS visit order**: 4-node line 0→1→2→3, BFS from 0 →
//      visit length == 4 (all reachable).
//   2. **DFS visit order**: same → length == 4.
//   3. **Dijkstra shortest path**: graph 0→1 (w=1), 1→3 (w=1),
//      0→2 (w=2), 2→3 (w=1) → dist[3] from 0 should be 2 via
//      0→1→3 (not 3 via 0→2→3).
//   4. **Topo-sort acyclic DAG**: returns valid topological order
//      of length n.
//   5. **Connected components**: 2 disjoint pairs {0-1, 2-3} →
//      2 components.
//
// Expected: rc=0.

import "stdlib/rods/graph.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_bfs() -> i64 {
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    graph_add_edge(g, 2, 3, f64_to_bits(1.0));
    let order: i64 = graph_bfs(g, 0);
    let n: i64 = vec_len(order);
    graph_free(g);
    if n != 4 { return 1; };
    return 0;
}

fn check_dfs() -> i64 {
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    graph_add_edge(g, 2, 3, f64_to_bits(1.0));
    let order: i64 = graph_dfs(g, 0);
    let n: i64 = vec_len(order);
    graph_free(g);
    if n != 4 { return 2; };
    return 0;
}

fn check_dijkstra() -> i64 {
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 3, f64_to_bits(1.0));
    graph_add_edge(g, 0, 2, f64_to_bits(2.0));
    graph_add_edge(g, 2, 3, f64_to_bits(1.0));
    let dist: i64 = graph_dijkstra(g, 0);
    // dist[3] should be 2 (via 0→1→3) not 3 (via 0→2→3)
    let d3: i64 = vec_get(dist, 3);
    graph_free(g);
    if close(d3, f64_to_bits(2.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_topo_sort_dag() -> i64 {
    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    let order: i64 = graph_topo_sort(g);
    let n: i64 = vec_len(order);
    graph_free(g);
    // Acyclic 3-node DAG → topo-sort yields valid order (length 3)
    if n != 3 { return 8; };
    return 0;
}

fn check_connected_components() -> i64 {
    let g: i64 = graph_new(4);
    // Two disjoint undirected pairs: {0-1} and {2-3}
    graph_add_edge_undirected(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge_undirected(g, 2, 3, f64_to_bits(1.0));
    let comps: i64 = graph_connected_components(g);
    // Each cell holds component-id for that node; expect 2 distinct components
    let c0: i64 = vec_get(comps, 0);
    let c1: i64 = vec_get(comps, 1);
    let c2: i64 = vec_get(comps, 2);
    let c3: i64 = vec_get(comps, 3);
    graph_free(g);
    if c0 != c1 { return 16; };
    if c2 != c3 { return 32; };
    if c0 == c2 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bfs();
    fails = fails + check_dfs();
    fails = fails + check_dijkstra();
    fails = fails + check_topo_sort_dag();
    fails = fails + check_connected_components();
    return fails;
}
