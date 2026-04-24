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
// **Query function** (v0.2.200) — once the roadmap is built, every
// `(start, goal)` query is two k-NN connections + Dijkstra. Reuses
// the same roadmap; no rebuild needed between queries. Returns the
// number of nodes on the resulting path (≥ 2 on success, 0 if no
// path was found). Read the path back via `prm_path_at`.
//
// See `stdlib/runtime/prm_rt.c`.
#cfile "../runtime/prm_rt.c"

extern fn nuc_prm_new(n_dim: i64, seed: i64) -> i64;
extern fn nuc_prm_set_bounds(h: i64, dim: i64, lo_b: i64, hi_b: i64);
extern fn nuc_prm_build(h: i64, n_samples: i64, k_neighbors: i64,
                       step_b: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_prm_query(h: i64, start_ptr: i64, goal_ptr: i64,
                       k_neighbors: i64, step_b: i64,
                       is_collision_free_fp: i64) -> i64;
extern fn nuc_prm_path_len(h: i64) -> i64;
extern fn nuc_prm_path_node(h: i64, idx: i64) -> i64;
extern fn nuc_prm_path_at(h: i64, idx: i64, dim: i64) -> i64;
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

// Plan a path from `start_ptr` to `goal_ptr` through the existing
// roadmap. Connects start and goal to their k nearest collision-free
// roadmap neighbors, runs Dijkstra. Returns the path length (number
// of waypoints, ≥ 2 on success; 0 if no path exists or if the
// endpoints can't connect to the roadmap).
//
// `start_ptr` and `goal_ptr` are handles to caller-allocated
// `double[n_dim]` arrays. `step_b` controls collision-check
// granularity along the connecting segments.
fn prm_query(h: i64, start_ptr: i64, goal_ptr: i64,
             k_neighbors: i64, step_b: i64,
             is_collision_free_fp: i64) -> i64 {
    return nuc_prm_query(h, start_ptr, goal_ptr, k_neighbors,
                         step_b, is_collision_free_fp);
}

// Number of waypoints on the most recent successful query path.
// Includes both virtual endpoints (start at idx=0, goal at idx=len-1).
fn prm_path_len(h: i64) -> i64 { return nuc_prm_path_len(h); }

// Roadmap node index for path waypoint `idx`. Returns the literal
// virtual indices (n_nodes for start, n_nodes+1 for goal) at the
// endpoints; real roadmap node indices in between.
fn prm_path_node(h: i64, idx: i64) -> i64 { return nuc_prm_path_node(h, idx); }

// Coordinate `dim` of path waypoint `idx`, as bit-cast f64. Virtual
// endpoints return 0.0 (the caller already knows the start/goal
// coordinates they passed in).
fn prm_path_at(h: i64, idx: i64, dim: i64) -> i64 {
    return nuc_prm_path_at(h, idx, dim);
}

fn prm_node_count(h: i64) -> i64 { return nuc_prm_node_count(h); }
fn prm_edge_count(h: i64) -> i64 { return nuc_prm_edge_count(h); }
fn prm_free(h: i64) { nuc_prm_free(h); }
