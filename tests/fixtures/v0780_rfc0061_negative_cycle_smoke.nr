// v0.7.80 RFC-0061 Tier 1 smoke fixture — negative-cycle
// detection. Builds a 3-node directed graph with a negative
// cycle 0->1->2->0 (weights -1, -2, -3 = sum -6) and verifies:
//   - graph_has_negative_cycle returns 1
//   - graph_negative_cycle_path returns a non-empty cycle vec
// Then builds a positive-only graph and verifies has_negative
// returns 0.
import "stdlib/rods/graph.nr"
import "stdlib/rods/complex.nr"

fn main() -> i64 {
    let neg1: i64 = f64_neg(f64_from_int(1));
    let neg2: i64 = f64_neg(f64_from_int(2));
    let neg3: i64 = f64_neg(f64_from_int(3));
    let pos1: i64 = f64_from_int(1);
    let pos2: i64 = f64_from_int(2);

    let g: i64 = graph_new(3);
    graph_add_edge(g, 0, 1, neg1);
    graph_add_edge(g, 1, 2, neg2);
    graph_add_edge(g, 2, 0, neg3);
    let has: i64 = graph_has_negative_cycle(g, 0);
    if has != 1 { graph_free(g); return 1; };
    let cycle: i64 = graph_negative_cycle_path(g, 0);
    if vec_len(cycle) < 2 { graph_free(g); return 2; };
    graph_free(g);

    let g2: i64 = graph_new(3);
    graph_add_edge(g2, 0, 1, pos1);
    graph_add_edge(g2, 1, 2, pos2);
    let has2: i64 = graph_has_negative_cycle(g2, 0);
    graph_free(g2);
    if has2 != 0 { return 3; };

    return 0;
}
