// rods/purepursuit — Pure-pursuit geometric path tracker for
// Ackermann (car-like) robots.
//
// Given current pose `(x, y, θ)`, a 2-D waypoint path, lookahead
// distance `L_d`, and wheelbase `L`, computes the steering angle
// that drives the vehicle along an arc to the lookahead point on
// the path.
//
// Algorithm (Coulter 1992):
//   1. Find closest path waypoint to robot.
//   2. Walk forward along path, accumulating arc length, until
//      total distance reaches `L_d`. Interpolate within the final
//      segment.
//   3. `α = angle from robot heading to lookahead point`.
//   4. `δ = atan(2 L sin(α) / L_d)`.
//
// Use:
//   - Mobile-base navigation following a planned path.
//   - Closed-loop tracking under any planner (RRT, A*, vgraph,
//     Dubins).
//
// Workflow:
//
//   import "stdlib/rods/purepursuit.nr"
//
//   for tick {
//       let steer: double;
//       let ok = purepursuit_step(x_b, y_b, theta_b,
//                                  path_x_ptr, path_y_ptr, n,
//                                  lookahead_b, wheelbase_b,
//                                  steer_out_ptr);
//       // apply steer + forward velocity to vehicle
//   }
//
// Limitations (adaptive lookahead / curvature-based gain
// scheduling land in v0.6 if needed):
// - Fixed lookahead.
// - No velocity output (caller decides forward speed).
// - Path must be dense enough for lookahead to be well-defined.
//
// See `stdlib/runtime/purepursuit_rt.c`.
#cfile "../runtime/purepursuit_rt.c"

extern fn nuc_purepursuit_step(x_b: i64, y_b: i64, theta_b: i64,
    path_x_ptr: i64, path_y_ptr: i64, n_waypoints: i64,
    lookahead_b: i64, wheelbase_b: i64,
    steer_out_ptr: i64) -> i64;

// Compute steering command. Returns 1 on success (steer angle
// written to `steer_out_ptr`), 0 if path is empty or invalid.
fn purepursuit_step(x_b: i64, y_b: i64, theta_b: i64,
    path_x_ptr: i64, path_y_ptr: i64, n_waypoints: i64,
    lookahead_b: i64, wheelbase_b: i64,
    steer_out_ptr: i64) -> i64
{
    return nuc_purepursuit_step(x_b, y_b, theta_b,
        path_x_ptr, path_y_ptr, n_waypoints,
        lookahead_b, wheelbase_b,
        steer_out_ptr);
}
