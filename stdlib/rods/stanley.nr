// rods/stanley — Stanley path tracker for Ackermann robots.
//
// Front-axle controller from the Stanford DARPA Grand Challenge
// vehicle (Hoffmann/Thrun 2007). Steering combines two errors
// measured at the FRONT axle:
//
//   `δ = ψ_e + atan2(k · e_ct, v_f + k_soft)`
//
//   `ψ_e`   = heading error (path tangent − vehicle heading).
//   `e_ct`  = signed cross-track error (front-axle perpendicular
//              distance to path; +ve when front is to the LEFT
//              of the path tangent).
//   `k`      = cross-track gain (typical 0.5 - 2.5).
//   `k_soft` = softening constant to keep gain finite at v→0.
//
// Pure-pursuit looks AHEAD; Stanley looks at where the front
// wheel actually IS relative to the path. Better at low speed
// and tight curvature, more sensitive to path noise.
//
// Workflow:
//
//   import "stdlib/rods/stanley.nr"
//
//   let ok = stanley_step(
//       x_b, y_b, theta_b,        // REAR axle pose
//       v_b,                       // forward speed (m/s)
//       path_x_ptr, path_y_ptr,   // double[N] waypoints
//       N,
//       k_b, k_soft_b,
//       wheelbase_b,
//       steer_out_ptr);            // double*
//
// **Limitations** (gain scheduling / yaw-rate feedforward / curvature
// preview land in v0.6 if needed):
// - No curvature feedforward (proportional only).
// - 2-D right-handed frame assumed for cross-track sign.
//
// See `stdlib/runtime/stanley_rt.c`.
#cfile "../runtime/stanley_rt.c"

extern fn nuc_stanley_step(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64,
    path_x_ptr: i64, path_y_ptr: i64, n_waypoints_: i64,
    k_b: i64, k_soft_b: i64, wheelbase_b: i64,
    steer_out_ptr: i64) -> i64;

// Compute Stanley steering command. `(x, y, theta)` is the REAR
// axle pose; the algorithm projects forward by `wheelbase` to get
// the front axle. Writes steer (rad) to `steer_out_ptr`.
// Returns 1 on success, 0 on bad input (n<2, wheelbase<=0, etc).
fn stanley_step(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64,
    path_x_ptr: i64, path_y_ptr: i64, n_waypoints_: i64,
    k_b: i64, k_soft_b: i64, wheelbase_b: i64,
    steer_out_ptr: i64) -> i64
{
    return nuc_stanley_step(x_b, y_b, theta_b, v_b,
        path_x_ptr, path_y_ptr, n_waypoints_,
        k_b, k_soft_b, wheelbase_b, steer_out_ptr);
}
