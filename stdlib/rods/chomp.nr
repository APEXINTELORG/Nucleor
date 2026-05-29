// rods/chomp — Covariant Hamiltonian Optimization for Motion
// Planning (CHOMP, Ratliff et al. 2009).
//
// Gradient-based trajectory optimizer that smooths an initial path
// while pushing it away from obstacles. Common workflow:
//
//   1. Run RRT / PRM to get a discretely-collision-free path.
//   2. Run CHOMP to smooth the result while keeping it clear of
//      obstacles.
//   3. Run TOPP (`stdlib/rods/trajectory.nr`) to time-parameterize
//      the smoothed path against actuator limits.
//
// The cost function is:
//
//     F(ξ) = w_smooth · F_smooth(ξ) + w_obs · F_obs(ξ)
//
// where F_smooth is integrated acceleration squared (penalizes
// jerky paths) and F_obs is the user-supplied obstacle cost
// integrated along the trajectory. Endpoints are clamped (start
// and goal never move); only interior waypoints are optimized.
//
// The default `chomp_optimize` surface is the legacy clamped-gradient
// optimizer. Use `chomp_optimize_covariant` when the path needs the
// full inverse smoothness-metric preconditioner used by CHOMP-proper.
//
// Limitations:
// - Generic high-DOF Cartesian optimization still needs a callback
//   or robot-model wrapper. `chomp_optimize_cartesian_planar_2link`
//   provides the first analytical FK/Jacobian Cartesian variant for
//   planar 2-link manipulators.
// - Obstacle gradient via numerical finite differences (slower
//   than exact gradients on signed-distance fields).
//
// See `stdlib/runtime/chomp_rt.c`.
#cfile "../runtime/chomp_rt.c"

extern fn nuc_chomp_optimize(
    path_ptr: i64, N: i64, n_dim: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64) -> i64;

extern fn nuc_chomp_optimize_covariant(
    path_ptr: i64, N: i64, n_dim: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64,
    metric_reg_b: i64, max_step_b: i64) -> i64;

extern fn nuc_chomp_cost(
    path_ptr: i64, N: i64, n_dim: i64,
    w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64) -> i64;

extern fn nuc_chomp_optimize_cartesian_planar_2link(
    path_ptr: i64, N: i64,
    target_xy_ptr: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_cart_b: i64,
    l1_b: i64, l2_b: i64,
    metric_reg_b: i64, max_step_b: i64) -> i64;

extern fn nuc_chomp_cartesian_planar_2link_cost(
    path_ptr: i64, N: i64,
    target_xy_ptr: i64,
    w_smooth_b: i64, w_cart_b: i64,
    l1_b: i64, l2_b: i64) -> i64;

// Optimize a path in place. `path_ptr` is a `double[N * n_dim]`
// caller-allocated buffer; the function modifies the interior
// waypoints (indices 1..N-2). Returns the number of iterations
// actually performed. `obs_cost_fp` may be 0 for pure-smoothness
// optimization; otherwise it's a function pointer to a callback
// `fn(config_ptr: i64) -> i64` that returns the bit-cast f64
// cost at a given joint configuration.
fn chomp_optimize(path_ptr: i64, N: i64, n_dim: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64) -> i64
{
    return nuc_chomp_optimize(path_ptr, N, n_dim, max_iters,
        alpha_b, w_smooth_b, w_obs_b, obs_cost_fp);
}

// Optimize a path in place using the CHOMP covariant update:
// `A^-1 grad` over the interior waypoints, where A is the clamped
// endpoint smoothness metric. `metric_reg_b` adds diagonal damping to
// A; `max_step_b` may be <= 0.0 to disable coordinate step clamping.
fn chomp_optimize_covariant(path_ptr: i64, N: i64, n_dim: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64,
    metric_reg_b: i64, max_step_b: i64) -> i64
{
    return nuc_chomp_optimize_covariant(path_ptr, N, n_dim, max_iters,
        alpha_b, w_smooth_b, w_obs_b, obs_cost_fp,
        metric_reg_b, max_step_b);
}

// Diagnostic: total trajectory cost (smoothness + obstacle).
// Useful for verifying that CHOMP actually decreased the cost.
fn chomp_cost(path_ptr: i64, N: i64, n_dim: i64,
    w_smooth_b: i64, w_obs_b: i64, obs_cost_fp: i64) -> i64
{
    return nuc_chomp_cost(path_ptr, N, n_dim, w_smooth_b, w_obs_b, obs_cost_fp);
}

// Cartesian CHOMP Phase 1 for planar 2-link manipulators.
// `path_ptr` is double[N * 2] joint waypoints (q1, q2), and
// `target_xy_ptr` is double[N * 2] desired end-effector positions.
// Interior joint waypoints are optimized by analytical FK/Jacobian
// task-space tracking plus joint smoothness; endpoints stay clamped.
fn chomp_optimize_cartesian_planar_2link(
    path_ptr: i64, N: i64,
    target_xy_ptr: i64,
    max_iters: i64,
    alpha_b: i64, w_smooth_b: i64, w_cart_b: i64,
    l1_b: i64, l2_b: i64,
    metric_reg_b: i64, max_step_b: i64) -> i64
{
    return nuc_chomp_optimize_cartesian_planar_2link(path_ptr, N,
        target_xy_ptr, max_iters, alpha_b, w_smooth_b, w_cart_b,
        l1_b, l2_b, metric_reg_b, max_step_b);
}

fn chomp_cartesian_planar_2link_cost(
    path_ptr: i64, N: i64,
    target_xy_ptr: i64,
    w_smooth_b: i64, w_cart_b: i64,
    l1_b: i64, l2_b: i64) -> i64
{
    return nuc_chomp_cartesian_planar_2link_cost(path_ptr, N,
        target_xy_ptr, w_smooth_b, w_cart_b, l1_b, l2_b);
}

// === Limitation diagnostic ===
//
// Surfaces CHOMP's documented approximations as a queryable string.
fn chomp_limitations() -> str {
    return "CHOMP limitations (ROBO-8/ROBO-9): (1) legacy chomp_optimize remains joint-space; chomp_optimize_cartesian_planar_2link now provides analytical planar FK/Jacobian Cartesian tracking, but generic high-DOF Cartesian models remain future work; (2) obstacle gradient via finite differences (slower than exact SDF gradients); (3) chomp_optimize_covariant provides A^-1 grad-F preconditioning; (4) endpoints clamped -- start and goal never move.";
}
