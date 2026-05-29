// rods/mobile — Differential-drive and Ackermann mobile-robot
// kinematics + arc-integrated pose update.
//
// Differential drive:
//   v_body  = (vL + vR) · wheel_radius / 2
//   ω_body  = (vR − vL) · wheel_radius / wheelbase
//
// Ackermann (bicycle model):
//   v_body  = v
//   ω_body  = v / wheelbase · tan(δ)        (δ = steering angle)
//
// Exact arc-integrated pose update from `(x, y, θ)` with
// `(v, ω)` over `dt`:
//   if |ω| > ε: arc with radius `R = v / ω`
//   else      : straight-line integration
//
// Workflow:
//
//   import "stdlib/rods/mobile.nr"
//
//   // Differential drive forward kinematics (wheels → body):
//   mobile_diff_fwd_kin(vL_b, vR_b, wheel_radius_b, wheelbase_b,
//                        v_out_ptr, w_out_ptr);
//   // Inverse (body → wheels):
//   mobile_diff_inv_kin(v_b, w_b, wheel_radius_b, wheelbase_b,
//                        vL_out_ptr, vR_out_ptr);
//
//   // Ackermann forward (steer + speed → body):
//   mobile_ackermann_fwd_kin(v_b, delta_b, wheelbase_b,
//                             v_out_ptr, w_out_ptr);
//   // Inverse (compute steering from body):
//   let delta_b = mobile_ackermann_inv_steer(v_b, w_b, wheelbase_b);
//
//   // Pose update with arc integration:
//   mobile_pose_step(x_b, y_b, theta_b, v_b, w_b, dt_b,
//                    x_out_ptr, y_out_ptr, theta_out_ptr);
//
// Limitations (slip / wheel-acceleration limits / mecanum /
// omnidirectional models land in v0.6 if needed):
// - No wheel slip / friction.
// - No actuator dynamics (instant velocity tracking).
// - Single-track (bicycle) Ackermann only.
//
// See `stdlib/runtime/mobile_rt.c`.
#cfile "../runtime/mobile_rt.c"

extern fn nuc_mobile_diff_fwd_kin(vL_b: i64, vR_b: i64,
    r_b: i64, L_b: i64, v_out_ptr: i64, w_out_ptr: i64);
extern fn nuc_mobile_diff_inv_kin(v_b: i64, w_b: i64,
    r_b: i64, L_b: i64, vL_out_ptr: i64, vR_out_ptr: i64);
extern fn nuc_mobile_ackermann_fwd_kin(v_b: i64, delta_b: i64, L_b: i64,
    v_out_ptr: i64, w_out_ptr: i64);
extern fn nuc_mobile_ackermann_inv_steer(v_b: i64, w_b: i64, L_b: i64) -> i64;
extern fn nuc_mobile_pose_step(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, w_b: i64, dt_b: i64,
    x_out_ptr: i64, y_out_ptr: i64, theta_out_ptr: i64);

// Differential-drive forward: (left wheel speed, right wheel speed,
// wheel radius, wheelbase) → (linear, angular) body velocity.
fn mobile_diff_fwd_kin(vL_b: i64, vR_b: i64, r_b: i64, L_b: i64,
    v_out_ptr: i64, w_out_ptr: i64)
{
    nuc_mobile_diff_fwd_kin(vL_b, vR_b, r_b, L_b, v_out_ptr, w_out_ptr);
}

// Differential-drive inverse: (linear, angular) body velocity →
// (left, right) wheel angular speed.
fn mobile_diff_inv_kin(v_b: i64, w_b: i64, r_b: i64, L_b: i64,
    vL_out_ptr: i64, vR_out_ptr: i64)
{
    nuc_mobile_diff_inv_kin(v_b, w_b, r_b, L_b, vL_out_ptr, vR_out_ptr);
}

// Ackermann (bicycle) forward: (speed, steering angle, wheelbase)
// → (linear, angular) body velocity.
fn mobile_ackermann_fwd_kin(v_b: i64, delta_b: i64, L_b: i64,
    v_out_ptr: i64, w_out_ptr: i64)
{
    nuc_mobile_ackermann_fwd_kin(v_b, delta_b, L_b, v_out_ptr, w_out_ptr);
}

// Ackermann inverse: given (v, ω), recover steering angle δ.
// Returns δ as bit-cast f64.
fn mobile_ackermann_inv_steer(v_b: i64, w_b: i64, L_b: i64) -> i64 {
    return nuc_mobile_ackermann_inv_steer(v_b, w_b, L_b);
}

// Arc-integrated pose update: (x, y, θ, v, ω, dt) →
// (x', y', θ'). Closed form along the constant-curvature arc.
fn mobile_pose_step(x_b: i64, y_b: i64, theta_b: i64,
    v_b: i64, w_b: i64, dt_b: i64,
    x_out_ptr: i64, y_out_ptr: i64, theta_out_ptr: i64)
{
    nuc_mobile_pose_step(x_b, y_b, theta_b, v_b, w_b, dt_b,
        x_out_ptr, y_out_ptr, theta_out_ptr);
}
