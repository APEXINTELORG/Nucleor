// rods/astar — A* shortest-path search on a generic weighted graph.
//
// Caller supplies the graph as two function pointers:
//
//   - **neighbor_fn(node, out_ids_ptr, out_costs_ptr, cap) -> n** —
//     given a node id, fill the output arrays with up to `cap`
//     (neighbor_id, edge_cost) pairs and return the count actually
//     written. The arrays are i64 (ids) and i64-bit-cast f64 (costs).
//
//   - **heuristic_fn(from, to) -> i64-bit-cast f64** — admissible
//     lower-bound on the remaining cost to reach `to` from `from`.
//     Pass 0 (null fn) for Dijkstra (no heuristic).
//
// Returns 1 on success, 0 if no path exists. Path is read back via
// `astar_path_len` + `astar_path_at`.
//
// Foundation for the v0.5 PRM Dijkstra/A* query, RRT* rewiring,
// and any discrete graph search a user needs.
//
// See `stdlib/runtime/astar_rt.c`.
#cfile "../runtime/astar_rt.c"

extern fn nuc_astar_new(n_nodes: i64) -> i64;
extern fn nuc_astar_search(h: i64, start: i64, goal: i64,
                            neighbor_fp: i64, heuristic_fp: i64,
                            neighbor_cap: i64) -> i64;
extern fn nuc_astar_path_len(h: i64) -> i64;
extern fn nuc_astar_path_at(h: i64, i: i64) -> i64;
extern fn nuc_astar_g_score(h: i64, node: i64) -> i64;
extern fn nuc_astar_free(h: i64);

fn astar_new(n_nodes: i64) -> i64 { return nuc_astar_new(n_nodes); }
fn astar_search(h: i64, start: i64, goal: i64,
                neighbor_fp: i64, heuristic_fp: i64,
                neighbor_cap: i64) -> i64 {
    return nuc_astar_search(h, start, goal, neighbor_fp, heuristic_fp, neighbor_cap);
}
fn astar_path_len(h: i64) -> i64 { return nuc_astar_path_len(h); }
fn astar_path_at(h: i64, i: i64) -> i64 { return nuc_astar_path_at(h, i); }
fn astar_g_score(h: i64, node: i64) -> i64 { return nuc_astar_g_score(h, node); }
fn astar_free(h: i64) { nuc_astar_free(h); }
