// rods/rrt — Rapidly-exploring Random Tree motion planner.
//
// LaValle 1998. Build a tree rooted at the start configuration in
// joint space, repeatedly sample random configurations, extend
// the nearest tree node toward the sample by a small step. When
// any tree node is within step_size of the goal, success.
//
// The collision check is supplied by the caller as a function
// pointer (`is_collision_free_fp`). Given a pointer to a
// double[n_dim] joint configuration, the user fn returns 1 if
// collision-free, 0 if in collision.
//
// 10% goal-biased sampling for better convergence near the goal.
//
// **RRT-Connect** and **RRT*** (asymptotically optimal) ship in
// v0.5 alongside the URDF + frame-chain integration.
//
// See `stdlib/runtime/rrt_rt.c`.
#cfile "../runtime/rrt_rt.c"

extern fn nuc_rrt_new(n_dim: i64, seed: i64) -> i64;
extern fn nuc_rrt_set_bounds(h: i64, dim: i64, lo_bits: i64, hi_bits: i64);
extern fn nuc_rrt_set_root(h: i64, start_ptr: i64) -> i64;
extern fn nuc_rrt_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_connect_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_path_len(h: i64) -> i64;
extern fn nuc_rrt_path_at(h: i64, path_idx: i64, dim: i64) -> i64;
extern fn nuc_rrt_node_count(h: i64) -> i64;
extern fn nuc_rrt_shortcut_path(h: i64, iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_free(h: i64);

fn rrt_new(n_dim: i64, seed: i64) -> i64 { return nuc_rrt_new(n_dim, seed); }
fn rrt_set_bounds(h: i64, dim: i64, lo_bits: i64, hi_bits: i64) {
    nuc_rrt_set_bounds(h, dim, lo_bits, hi_bits);
}
fn rrt_set_root(h: i64, start_ptr: i64) -> i64 { return nuc_rrt_set_root(h, start_ptr); }
fn rrt_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_rrt_plan(h, goal_ptr, max_iters, step_bits, is_collision_free_fp);
}

// RRT-Connect (Kuffner & LaValle 2000). Bidirectional variant
// that grows two trees and tries to connect them — typically
// 5-10x faster than vanilla RRT on hard problems. Same callback
// contract; on success, the path is read back via rrt_path_len /
// rrt_path_at as for vanilla rrt_plan.
fn rrt_connect_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_rrt_connect_plan(h, goal_ptr, max_iters, step_bits, is_collision_free_fp);
}
fn rrt_path_len(h: i64) -> i64 { return nuc_rrt_path_len(h); }
fn rrt_path_at(h: i64, path_idx: i64, dim: i64) -> i64 {
    return nuc_rrt_path_at(h, path_idx, dim);
}
fn rrt_node_count(h: i64) -> i64 { return nuc_rrt_node_count(h); }

// Path shortcutting (post-RRT smoothing). Repeatedly samples
// random index pairs (i, j) on the current path; if the
// straight-line segment from path[i] to path[j] is collision-free
// at every intermediate step-spaced sample, replaces path[i+1..j-1]
// with that segment. Returns the new path length.
fn rrt_shortcut_path(h: i64, iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_rrt_shortcut_path(h, iters, step_bits, is_collision_free_fp);
}

fn rrt_free(h: i64) { nuc_rrt_free(h); }
