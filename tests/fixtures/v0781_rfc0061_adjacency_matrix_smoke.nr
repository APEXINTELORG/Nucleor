// v0.7.81 RFC-0061 Tier 1 smoke fixture — adjacency-matrix view.
// Builds a 4-node directed graph with 5 edges (density = 5/12),
// extracts the adjacency matrix as a flat Vec<i64>, rebuilds a
// Graph from the matrix, then compares densities.
import "stdlib/rods/graph.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let g: i64 = graph_new(4);
    graph_add_edge(g, 0, 1, f64_from_int(2));
    graph_add_edge(g, 0, 2, f64_from_int(3));
    graph_add_edge(g, 1, 2, f64_from_int(1));
    graph_add_edge(g, 2, 3, f64_from_int(7));
    graph_add_edge(g, 3, 0, f64_from_int(4));

    let m: i64 = graph_to_adjacency_matrix(g);
    if vec_len(m) != 16 { graph_free(g); return 1; };

    let dens_a: i64 = graph_adjacency_density(g);
    let g2: i64 = graph_from_adjacency_matrix(m, 4);
    let dens_b: i64 = graph_adjacency_density(g2);

    if f64_eq(dens_a, dens_b) == 0 { graph_free(g); graph_free(g2); return 2; };

    let zero: i64 = f64_from_int(0);
    if f64_gt(dens_a, zero) == 0 { graph_free(g); graph_free(g2); return 3; };
    let one: i64 = f64_from_int(1);
    if f64_lt(dens_a, one) == 0 { graph_free(g); graph_free(g2); return 4; };

    graph_free(g);
    graph_free(g2);
    return 0;
}
