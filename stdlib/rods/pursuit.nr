// rods/pursuit — Pure pursuit path-following controller.
//
// Classical geometric controller for differential-drive (e.g.,
// AGVs, AMRs, two-wheeled balancing robots) and car-like
// (Ackermann-steered) ground vehicles. Given a path of waypoints
// and the robot's current pose, returns the steering command that
// drives a circular arc to the lookahead point.
//
// Workflow:
//   let p = pursuit_new(n_waypoints_hint);
//   for waypoint in path { pursuit_add_point(p, x_b, y_b); }
//
//   // At each control tick:
//   let omega = pursuit_step_diff_drive(p, x_b, y_b, theta_b,
//                                       v_b, lookahead_b);
//   // ... or for car-like:
//   let delta = pursuit_step_ackermann(p, x_b, y_b, theta_b,
//                                       v_b, lookahead_b, wheelbase_b);
//
//   // Goal-reached check:
//   if pursuit_distance_to_goal(p, x_b, y_b) < goal_tol { stop(); }
//
// Foundation for autonomous mobile robot control, outdoor
// delivery robots, autonomous vehicles, warehouse transports.
//
// **Limitations** (adaptive lookahead, time-based formulation,
// path pruning land in v0.6 if needed):
// - Constant lookahead distance (no velocity-adaptive scheduling).
// - No automatic completion / "near-goal" early-stop.
// - Brute-force closest-point search per call.
//
// See `stdlib/runtime/pursuit_rt.c`.
#cfile "../runtime/pursuit_rt.c"

extern fn nuc_pursuit_new(n_pts_hint: i64) -> i64;
extern fn nuc_pursuit_add_point(h: i64, x_b: i64, y_b: i64) -> i64;
extern fn nuc_pursuit_reset_progress(h: i64);
extern fn nuc_pursuit_point_count(h: i64) -> i64;
extern fn nuc_pursuit_step_diff_drive(h: i64,
    x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, lookahead_b: i64) -> i64;
extern fn nuc_pursuit_step_ackermann(h: i64,
    x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, lookahead_b: i64, wheelbase_b: i64) -> i64;
extern fn nuc_pursuit_distance_to_goal(h: i64, x_b: i64, y_b: i64) -> i64;
extern fn nuc_pursuit_free(h: i64);

fn pursuit_new(n_pts_hint: i64) -> i64 { return nuc_pursuit_new(n_pts_hint); }
fn pursuit_add_point(h: i64, x_b: i64, y_b: i64) -> i64 {
    return nuc_pursuit_add_point(h, x_b, y_b);
}
fn pursuit_reset_progress(h: i64) { nuc_pursuit_reset_progress(h); }
fn pursuit_point_count(h: i64) -> i64 { return nuc_pursuit_point_count(h); }

// Differential-drive pure pursuit step. Returns angular velocity
// command ω (rad/s, positive = CCW) as bit-cast f64.
fn pursuit_step_diff_drive(h: i64,
    x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, lookahead_b: i64) -> i64
{
    return nuc_pursuit_step_diff_drive(h, x_b, y_b, theta_b, v_b, lookahead_b);
}

// Car-like (Ackermann) pure pursuit step. Returns steering angle
// δ (rad) as bit-cast f64. The wheelbase parameter is the distance
// between front and rear axles.
fn pursuit_step_ackermann(h: i64,
    x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, lookahead_b: i64, wheelbase_b: i64) -> i64
{
    return nuc_pursuit_step_ackermann(h, x_b, y_b, theta_b, v_b, lookahead_b, wheelbase_b);
}

// Euclidean distance from (x, y) to the final waypoint, as
// bit-cast f64. Useful for goal-reached detection.
fn pursuit_distance_to_goal(h: i64, x_b: i64, y_b: i64) -> i64 {
    return nuc_pursuit_distance_to_goal(h, x_b, y_b);
}

fn pursuit_free(h: i64) { nuc_pursuit_free(h); }
