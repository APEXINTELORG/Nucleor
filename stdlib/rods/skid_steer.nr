// rods/skid_steer — 4-wheel skid-steer kinematics + odometry.
//
// All wheels on each side drive at the same speed. Turning
// happens by skidding (left side faster → robot turns right).
// Used by Husky, Jackal, big agricultural / mining vehicles,
// and tracked platforms.
//
// Effectively differential-drive applied to the AVERAGE per-side
// speed, with an effective track width `L_eff` accounting for
// wheel-vs-ground slip:
//   - Indoor wheels on hard floor: `L_eff ≈ 1.5 × L_phys`
//   - Outdoor wheels on soft soil: `L_eff ≈ 1.0 × L_phys`
//
// API:
//   `skid_steer_velocities(fl, fr, bl, br, L_eff, v_out, w_out)`
//      Forward kinematics: 4 wheel speeds → body (v, omega).
//   `skid_steer_wheels(v, w, L_eff, vL_out, vR_out)`
//      Inverse kinematics: body → per-side wheel speed.
//   `skid_steer_step(x, y, θ, fl, fr, bl, br, L_eff, dt, out)`
//      Euler odometry update. Writes new (x, y, theta).
//
// Workflow:
//
//   import "stdlib/rods/skid_steer.nr"
//
//   let pose: [3]double;
//   let _ = skid_steer_step(x_b, y_b, th_b,
//                            fl_b, fr_b, bl_b, br_b,
//                            L_eff_b, dt_b,
//                            f64_ptr(&pose[0]));
//
// Limitations (slip-aware odometry / yaw-rate fusion / ICR-
// estimation from history land in v0.6 if needed):
// - Caller supplies L_eff (no auto-fit from data).
// - Kinematic only.
//
// See `stdlib/runtime/skid_steer_rt.c`.
#cfile "../runtime/skid_steer_rt.c"

extern fn nuc_skid_steer_velocities(fl_b: i64, fr_b: i64,
    bl_b: i64, br_b: i64, L_eff_b: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64;
extern fn nuc_skid_steer_wheels(v_b: i64, w_b: i64,
    L_eff_b: i64, vL_out_ptr: i64, vR_out_ptr: i64) -> i64;
extern fn nuc_skid_steer_step(x_b: i64, y_b: i64, th_b: i64,
    fl_b: i64, fr_b: i64, bl_b: i64, br_b: i64,
    L_eff_b: i64, dt_b: i64, out_ptr: i64) -> i64;

// Forward kinematics: 4 wheel speeds → body (v, omega).
fn skid_steer_velocities(fl_b: i64, fr_b: i64,
    bl_b: i64, br_b: i64, L_eff_b: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64
{
    return nuc_skid_steer_velocities(fl_b, fr_b, bl_b, br_b, L_eff_b,
        v_out_ptr, w_out_ptr);
}

// Inverse kinematics: body (v, omega) → per-side wheel speed.
fn skid_steer_wheels(v_b: i64, w_b: i64,
    L_eff_b: i64, vL_out_ptr: i64, vR_out_ptr: i64) -> i64
{
    return nuc_skid_steer_wheels(v_b, w_b, L_eff_b, vL_out_ptr, vR_out_ptr);
}

// Euler odometry step.
fn skid_steer_step(x_b: i64, y_b: i64, th_b: i64,
    fl_b: i64, fr_b: i64, bl_b: i64, br_b: i64,
    L_eff_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_skid_steer_step(x_b, y_b, th_b, fl_b, fr_b, bl_b, br_b,
        L_eff_b, dt_b, out_ptr);
}
