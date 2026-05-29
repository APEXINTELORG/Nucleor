// rods/apf — Artificial potential field for reactive collision
// avoidance (Khatib 1986).
//
// The simplest reactive controller. Combines an attractive
// potential pulling the robot toward the goal with repulsive
// potentials pushing it away from nearby obstacles. The gradient
// (force) at the robot's current position gives the desired
// direction of motion.
//
//   F_att(q) = -k_att · (q − q_goal)
//   F_rep(q) = Σ_obs (1/d − 1/d_max)·(1/d²) · (q − q_obs)/|...|
//
// Common baseline alongside DWA / pure pursuit. Works well for
// sparse obstacles with open goal direction; struggles with
// local minima (concave obstacles, narrow passages).
//
// Workflow:
//   // Get the raw force (Fx, Fy) for use in your own dynamics
//   // integrator:
//   apf_force_2d(x, y, gx, gy, obs_ptr, n_obs,
//                k_att, k_rep, d_max, F_out_ptr);
//
//   // Or do a quick step with v · dt motion along the force:
//   apf_step_2d(x, y, gx, gy, obs_ptr, n_obs,
//               k_att, k_rep, d_max, v, dt,
//               x_out_ptr, y_out_ptr);
//
// Limitations (Vector Field Histogram / Navigation Functions
// land in v0.6 if needed for narrow-passage scenarios):
// - 2D only.
// - Caller supplies obstacle list as point obstacles.
// - No local-minimum escape — gets stuck in concave obstacles.
//
// See `stdlib/runtime/apf_rt.c`.
#cfile "../runtime/apf_rt.c"

extern fn nuc_apf_force_2d(
    x_b: i64, y_b: i64, gx_b: i64, gy_b: i64,
    obs_ptr: i64, n_obs: i64,
    k_att_b: i64, k_rep_b: i64, d_max_b: i64,
    F_out_ptr: i64) -> i64;

extern fn nuc_apf_step_2d(
    x_b: i64, y_b: i64, gx_b: i64, gy_b: i64,
    obs_ptr: i64, n_obs: i64,
    k_att_b: i64, k_rep_b: i64, d_max_b: i64,
    v_b: i64, dt_b: i64,
    x_out_ptr: i64, y_out_ptr: i64) -> i64;

// Compute the 2D potential-field force at point (x, y). `obs_ptr`
// is `double[n_obs * 2]`; `F_out_ptr` is `double[2]` for (Fx, Fy).
fn apf_force_2d(x_b: i64, y_b: i64, gx_b: i64, gy_b: i64,
    obs_ptr: i64, n_obs: i64,
    k_att_b: i64, k_rep_b: i64, d_max_b: i64,
    F_out_ptr: i64) -> i64
{
    return nuc_apf_force_2d(x_b, y_b, gx_b, gy_b,
        obs_ptr, n_obs, k_att_b, k_rep_b, d_max_b, F_out_ptr);
}

// Convenience: step the robot by `v · dt` along the (normalized)
// APF force direction. Writes new (x', y') to x_out_ptr / y_out_ptr.
fn apf_step_2d(x_b: i64, y_b: i64, gx_b: i64, gy_b: i64,
    obs_ptr: i64, n_obs: i64,
    k_att_b: i64, k_rep_b: i64, d_max_b: i64,
    v_b: i64, dt_b: i64,
    x_out_ptr: i64, y_out_ptr: i64) -> i64
{
    return nuc_apf_step_2d(x_b, y_b, gx_b, gy_b,
        obs_ptr, n_obs, k_att_b, k_rep_b, d_max_b,
        v_b, dt_b, x_out_ptr, y_out_ptr);
}
