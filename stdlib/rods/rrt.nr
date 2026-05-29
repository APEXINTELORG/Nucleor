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
// RRT-Connect and RRT* (asymptotically optimal) ship in
// v0.5 alongside the URDF + frame-chain integration.
//
// See `stdlib/runtime/rrt_rt.c`.
#cfile "../runtime/rrt_rt.c"

extern fn nuc_rrt_new(n_dim: i64, seed: i64) -> i64;
extern fn nuc_rrt_set_bounds(h: i64, dim: i64, lo_bits: i64, hi_bits: i64);
extern fn nuc_rrt_set_root(h: i64, start_ptr: i64) -> i64;
extern fn nuc_rrt_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_connect_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_star_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, radius_bits: i64, is_collision_free_fp: i64) -> i64;
extern fn nuc_rrt_plan_region(h: i64, region_lo_ptr: i64, region_hi_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64;

// Informed RRT* (v0.2.248, Gammell, Srinivasa, Barfoot 2014).
// After finding a first solution with cost c_best, restricts
// subsequent samples to the prolate hyperspheroid (ellipsoid)
// with foci at start/goal and major axis c_best. As c_best
// shrinks via rewiring, the ellipsoid shrinks too, focusing
// sampling on the region that could improve the path.
extern fn nuc_rrt_star_plan_informed(h: i64,
    start_ptr: i64, goal_ptr: i64,
    max_iters: i64, step_bits: i64, radius_bits: i64,
    is_collision_free_fp: i64) -> i64;
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

// RRT* (Karaman & Frazzoli 2011). Asymptotically optimal: each new
// node is connected to its lowest-cost neighbor within `radius`,
// then nearby nodes are rewired through it if that improves their
// cost. Path quality converges to optimum as iterations grow.
//
// Cost is path length in joint space. Use a `radius` of about
// 2-3× `step` for good rewire opportunities without too much
// per-iteration overhead.
fn rrt_star_plan(h: i64, goal_ptr: i64, max_iters: i64, step_bits: i64, radius_bits: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_rrt_star_plan(h, goal_ptr, max_iters, step_bits, radius_bits, is_collision_free_fp);
}

// Informed RRT* — accepts BOTH start and goal because the
// ellipsoid sampler needs the start position. (`rrt_set_root`
// already specifies the start internally; passing start here is
// for the ellipsoid math.)
fn rrt_star_plan_informed(h: i64, start_ptr: i64, goal_ptr: i64,
    max_iters: i64, step_bits: i64, radius_bits: i64,
    is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_star_plan_informed(h, start_ptr, goal_ptr,
        max_iters, step_bits, radius_bits, is_collision_free_fp);
}

// Goal-region planning (v0.2.198). Instead of a single goal point,
// `region_lo_ptr` and `region_hi_ptr` are double[n_dim] arrays
// defining a per-dim [lo, hi] acceptable goal region. Useful when
// the exact goal pose is approximate or there's a tolerance bubble
// around the desired end-effector position. 10% goal-bias samples
// inside the region.
fn rrt_plan_region(h: i64, region_lo_ptr: i64, region_hi_ptr: i64, max_iters: i64, step_bits: i64, is_collision_free_fp: i64) -> i64 {
    return nuc_rrt_plan_region(h, region_lo_ptr, region_hi_ptr, max_iters, step_bits, is_collision_free_fp);
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

// === Ergonomic f64 wrappers (v0.4.265) ===
//
// Same pattern as units/kinematics/linalg/csv_table/kdt/
// trajectory — hide the i64-bits-ABI behind f64-typed surface
// for the eight RRT fns whose i64 carries an f64 bit pattern
// (joint-bound endpoints, step / radius, path coordinates).
// Pointer args (goal_ptr, region_*_ptr, fn-ptr collision check)
// stay as i64 — they're memory addresses, not f64. The bits-
// ABI fns above remain — purely additive.

fn rrt_set_bounds_f64(h: i64, dim: i64, lo: f64, hi: f64) {
    nuc_rrt_set_bounds(h, dim, f64_to_bits(lo), f64_to_bits(hi));
}
fn rrt_plan_f64(h: i64, goal_ptr: i64, max_iters: i64, step: f64,
    is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_plan(h, goal_ptr, max_iters, f64_to_bits(step),
        is_collision_free_fp);
}
fn rrt_connect_plan_f64(h: i64, goal_ptr: i64, max_iters: i64, step: f64,
    is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_connect_plan(h, goal_ptr, max_iters, f64_to_bits(step),
        is_collision_free_fp);
}
fn rrt_star_plan_f64(h: i64, goal_ptr: i64, max_iters: i64, step: f64,
    radius: f64, is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_star_plan(h, goal_ptr, max_iters, f64_to_bits(step),
        f64_to_bits(radius), is_collision_free_fp);
}
fn rrt_star_plan_informed_f64(h: i64, start_ptr: i64, goal_ptr: i64,
    max_iters: i64, step: f64, radius: f64,
    is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_star_plan_informed(h, start_ptr, goal_ptr, max_iters,
        f64_to_bits(step), f64_to_bits(radius), is_collision_free_fp);
}
fn rrt_plan_region_f64(h: i64, region_lo_ptr: i64, region_hi_ptr: i64,
    max_iters: i64, step: f64, is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_plan_region(h, region_lo_ptr, region_hi_ptr, max_iters,
        f64_to_bits(step), is_collision_free_fp);
}
fn rrt_shortcut_path_f64(h: i64, iters: i64, step: f64,
    is_collision_free_fp: i64) -> i64
{
    return nuc_rrt_shortcut_path(h, iters, f64_to_bits(step),
        is_collision_free_fp);
}
fn rrt_path_at_f64(h: i64, path_idx: i64, dim: i64) -> f64 {
    return f64_from_bits(nuc_rrt_path_at(h, path_idx, dim));
}
