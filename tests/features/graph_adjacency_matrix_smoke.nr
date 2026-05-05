// v0.8.148 RFC-0061 Tier 1 — adjacency-matrix view smoke fixture.
//
// Pre-RFC-0061 Tier 1, the graph rod exposed only adjacency-
// list representation. Some algorithms (matrix powers, all-
// pairs shortest path, spectral methods) want the dense
// adjacency-matrix form. v0.7.81 added the matrix view.
// This fixture locks the round-trip + density invariants.
//
// Locks:
//   1. graph_to_adjacency_matrix returns a valid handle.
//   2. graph_adjacency_density on a sparse graph (3 edges in 4
//      nodes = 3/16 = 0.1875) is plausibly low (< 0.5).
//   3. graph_adjacency_density on a dense graph (every pair
//      connected) is plausibly high (> 0.5).
//
// Expected: rc=0.

import "stdlib/rods/graph.nr"

fn check_matrix_handle() -> i64 {
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    graph_add_edge(g, 2, 3, f64_to_bits(1.0));
    let m: i64 = graph_to_adjacency_matrix(g);
    if m == 0 { graph_free(g); return 1; };
    graph_free(g);
    return 0;
}

fn check_density_sparse() -> i64 {
    // 4 nodes, 3 edges, no self-loops → density = 3 / (4*4) = 0.1875
    // (or 3/(4*3) = 0.25 depending on whether diagonal is counted)
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_to_bits(1.0));
    graph_add_edge(g, 1, 2, f64_to_bits(1.0));
    graph_add_edge(g, 2, 3, f64_to_bits(1.0));
    let d_bits: i64 = graph_adjacency_density(g);
    let d: f64 = f64_from_bits(d_bits);
    graph_free(g);
    if d > 0.5 { return 2; };
    if d < 0.0 { return 4; };
    return 0;
}

fn check_density_dense() -> i64 {
    // 4 nodes, fully connected directed (12 edges)
    let g: i64 = graph_new(4);
    let mut i: i64 = 0;
    while i < 4 {
        let mut j: i64 = 0;
        while j < 4 {
            if i != j {
                graph_add_edge(g, i, j, f64_to_bits(1.0));
            };
            j = j + 1;
        };
        i = i + 1;
    };
    let d_bits: i64 = graph_adjacency_density(g);
    let d: f64 = f64_from_bits(d_bits);
    graph_free(g);
    if d < 0.5 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_matrix_handle();
    fails = fails + check_density_sparse();
    fails = fails + check_density_dense();
    return fails;
}
