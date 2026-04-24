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
// **Limitations** (full covariant pre-conditioning A⁻¹∇F lands
// in v0.6 if needed; here we approximate by clamping per-step
// move magnitude — much simpler, similar empirical behavior on
// typical paths):
// - Joint-space optimization only (Cartesian-space variant
//   would need an FK + Jacobian wrapper).
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

extern fn nuc_chomp_cost(
    path_ptr: i64, N: i64, n_dim: i64,
    w_smooth_b: i64, w_obs_b: i64,
    obs_cost_fp: i64) -> i64;

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

// Diagnostic: total trajectory cost (smoothness + obstacle).
// Useful for verifying that CHOMP actually decreased the cost.
fn chomp_cost(path_ptr: i64, N: i64, n_dim: i64,
    w_smooth_b: i64, w_obs_b: i64, obs_cost_fp: i64) -> i64
{
    return nuc_chomp_cost(path_ptr, N, n_dim, w_smooth_b, w_obs_b, obs_cost_fp);
}
