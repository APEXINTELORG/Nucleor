// rods/prm — Probabilistic Roadmap motion planner.
//
// Build a graph in joint space by sampling random configurations
// (nodes) and connecting nearby pairs with collision-free edges
// (k-nearest neighbors). The roadmap is a one-time investment;
// every subsequent (start, goal) query reuses it via graph search.
//
// **Multi-query** advantage vs RRT (single-query): roadmap is built
// once. Use PRM when the same robot is doing many planning queries
// in the same workspace; use RRT when the world changes between
// queries.
//
// The collision check is supplied by the caller as a function
// pointer (same contract as `rrt.nr`): given a Vec3 direction
// handle (3 doubles malloc'd), the user fn returns 1 if collision-
// free, 0 if in collision.
//
// **Query function** — building the roadmap is the main cost; the
// (start, goal) query is just two k-NN connections + Dijkstra.
// The Dijkstra query lands in v0.5 alongside RRT-Connect / RRT*;
// v0.2 ships the roadmap-build path so applications can adopt the
// precomputation pattern now.
//
// See `stdlib/runtime/prm_rt.c`.
#cfile "../runtime/prm_rt.c"

extern fn nuc_prm_new(n_dim: i64, seed: i64) -> i64;
extern fn nuc_prm_set_bounds(h: i64, dim: i64, lo_b: i64, hi_b: i64);
extern fn nuc_prm_build(h: i64, n_samples: i64, k_neighbors: i64,
                       step_b: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_prm_node_count(h: i64) -> i64;
extern fn nuc_prm_edge_count(h: i64) -> i64;
extern fn nuc_prm_free(h: i64);

fn prm_new(n_dim: i64, seed: i64) -> i64 { return nuc_prm_new(n_dim, seed); }
fn prm_set_bounds(h: i64, dim: i64, lo_b: i64, hi_b: i64) {
    nuc_prm_set_bounds(h, dim, lo_b, hi_b);
}
fn prm_build(h: i64, n_samples: i64, k_neighbors: i64,
             step_b: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_prm_build(h, n_samples, k_neighbors, step_b, is_collision_free_fp);
}
fn prm_node_count(h: i64) -> i64 { return nuc_prm_node_count(h); }
fn prm_edge_count(h: i64) -> i64 { return nuc_prm_edge_count(h); }
fn prm_free(h: i64) { nuc_prm_free(h); }
