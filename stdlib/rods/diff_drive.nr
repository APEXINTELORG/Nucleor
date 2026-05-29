// rods/diff_drive — Differential-drive (2-wheel) kinematics +
// odometry.
//
// Two-wheel platform with track width L. Standard kinematic
// model:
//
//   `v     = (v_l + v_r) / 2`
//   `omega = (v_r − v_l) / L`
//   `ẋ = v cos(θ)`,  `ẏ = v sin(θ)`,  `θ̇ = omega`
//
// API:
//   `diff_drive_velocities(v_l, v_r, L, v_out, w_out)`
//      Forward kinematics: wheel speeds → body velocity.
//   `diff_drive_wheels(v, w, L, vl_out, vr_out)`
//      Inverse kinematics: body velocity → wheel speeds.
//   `diff_drive_step(x, y, θ, v_l, v_r, L, dt, out)`
//      Euler odometry step. Best for small dt.
//   `diff_drive_step_arc(x, y, θ, v_l, v_r, L, dt, out)`
//      Exact constant-curvature arc integration. Use for large
//      dt or tight turns.
//
// Workflow:
//
//   import "stdlib/rods/diff_drive.nr"
//
//   let pose: [3]double;
//   let _ = diff_drive_step_arc(x_b, y_b, th_b,
//                                 vl_b, vr_b, L_b, dt_b,
//                                 f64_ptr(&pose[0]));
//
// Limitations (wheel-slip / encoder-tick odometry / IMU-fused
// pose update land in v0.6 if needed):
// - Kinematic only (no slip).
// - Caller supplies wheel speeds (not encoder ticks).
//
// See `stdlib/runtime/diff_drive_rt.c`.
#cfile "../runtime/diff_drive_rt.c"

extern fn nuc_diff_drive_velocities(vl_b: i64, vr_b: i64, L_b: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64;
extern fn nuc_diff_drive_wheels(v_b: i64, w_b: i64, L_b: i64,
    vl_out_ptr: i64, vr_out_ptr: i64) -> i64;
extern fn nuc_diff_drive_step(x_b: i64, y_b: i64, th_b: i64,
    vl_b: i64, vr_b: i64, L_b: i64, dt_b: i64, out_ptr: i64) -> i64;
extern fn nuc_diff_drive_step_arc(x_b: i64, y_b: i64, th_b: i64,
    vl_b: i64, vr_b: i64, L_b: i64, dt_b: i64, out_ptr: i64) -> i64;

// Forward kinematics: wheel speeds (v_l, v_r) → body (v, omega).
fn diff_drive_velocities(vl_b: i64, vr_b: i64, L_b: i64,
    v_out_ptr: i64, w_out_ptr: i64) -> i64
{
    return nuc_diff_drive_velocities(vl_b, vr_b, L_b, v_out_ptr, w_out_ptr);
}

// Inverse kinematics: body (v, omega) → wheel speeds (v_l, v_r).
fn diff_drive_wheels(v_b: i64, w_b: i64, L_b: i64,
    vl_out_ptr: i64, vr_out_ptr: i64) -> i64
{
    return nuc_diff_drive_wheels(v_b, w_b, L_b, vl_out_ptr, vr_out_ptr);
}

// Euler odometry step. Writes new (x, y, theta) to out_ptr (3 doubles).
fn diff_drive_step(x_b: i64, y_b: i64, th_b: i64,
    vl_b: i64, vr_b: i64, L_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_diff_drive_step(x_b, y_b, th_b, vl_b, vr_b, L_b, dt_b, out_ptr);
}

// Constant-curvature arc integration step. More accurate than Euler
// when omega*dt is non-small.
fn diff_drive_step_arc(x_b: i64, y_b: i64, th_b: i64,
    vl_b: i64, vr_b: i64, L_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_diff_drive_step_arc(x_b, y_b, th_b, vl_b, vr_b, L_b, dt_b, out_ptr);
}
