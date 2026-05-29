// rods/dwa — Dynamic Window Approach (Fox, Burgard & Thrun 1997)
// local planner.
//
// Standard ROS-style local navigation controller for differential-
// drive robots. Selects the best (v, ω) command at each control
// step by sampling within the dynamic window of velocities
// reachable in one step given the robot's acceleration limits,
// rolling out each candidate trajectory, scoring by obstacle
// clearance + heading + velocity, and picking the highest score.
//
// Foundation for ROS-style local navigation: a global planner
// (RRT / A* / PRM) emits a path; DWA picks local commands that
// follow it while reactively avoiding obstacles the global
// planner didn't see.
//
// Workflow:
//   // user-provided obs distance callback: fn(x, y) -> i64 (bit-cast f64)
//   // returning the distance from (x, y) to the nearest obstacle.
//
//   // At each control step:
//   dwa_step(x, y, theta,
//            v_curr, w_curr,
//            goal_x, goal_y,
//            v_min, v_max, w_min, w_max,
//            a_max, alpha_max,
//            n_v_samples, n_w_samples,
//            dt, T_horizon,
//            w_clear, w_heading, w_velocity,
//            obs_dist_fp,
//            v_out_ptr, w_out_ptr);
//
// Limitations (TEB / MPC-style trajectory-level optimization
// land in v0.6 if needed):
// - Differential-drive only.
// - Constant velocity within each candidate (no piecewise
//   acceleration).
// - Brute-force grid search over (v, ω).
//
// See `stdlib/runtime/dwa_rt.c`.
#cfile "../runtime/dwa_rt.c"

extern fn nuc_dwa_step(
    x_b: i64, y_b: i64, theta_b: i64,
    v_curr_b: i64, w_curr_b: i64,
    gx_b: i64, gy_b: i64,
    v_min_b: i64, v_max_b: i64,
    w_min_b: i64, w_max_b: i64,
    a_max_b: i64, alpha_max_b: i64,
    n_v: i64, n_w: i64,
    dt_b: i64, T_horizon_b: i64,
    w_clear_b: i64, w_head_b: i64, w_vel_b: i64,
    obs_dist_fp: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64;

// One DWA step. Returns 0 on success and writes the chosen
// (v, ω) command to v_out_ptr / w_out_ptr (each a single-double
// caller-allocated buffer).
fn dwa_step(x_b: i64, y_b: i64, theta_b: i64,
    v_curr_b: i64, w_curr_b: i64,
    gx_b: i64, gy_b: i64,
    v_min_b: i64, v_max_b: i64,
    w_min_b: i64, w_max_b: i64,
    a_max_b: i64, alpha_max_b: i64,
    n_v: i64, n_w: i64,
    dt_b: i64, T_horizon_b: i64,
    w_clear_b: i64, w_head_b: i64, w_vel_b: i64,
    obs_dist_fp: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64
{
    return nuc_dwa_step(x_b, y_b, theta_b,
        v_curr_b, w_curr_b, gx_b, gy_b,
        v_min_b, v_max_b, w_min_b, w_max_b,
        a_max_b, alpha_max_b,
        n_v, n_w, dt_b, T_horizon_b,
        w_clear_b, w_head_b, w_vel_b,
        obs_dist_fp, v_out_ptr, w_out_ptr);
}
