// rods/mecanum — Mecanum-wheel (4-wheel omnidirectional) kinematics.
//
// Standard X-pattern roller geometry. Body velocity (vx, vy, omega)
// in body frame (+x forward, +y left); wheels FL/FR/BL/BR.
//
// Inverse kinematics (body → wheels):
//   `v_FL = vx − vy − (Lx + Ly) · ω`
//   `v_FR = vx + vy + (Lx + Ly) · ω`
//   `v_BL = vx + vy − (Lx + Ly) · ω`
//   `v_BR = vx − vy + (Lx + Ly) · ω`
//
// Forward kinematics (wheels → body):
//   `vx    = (FL + FR + BL + BR) / 4`
//   `vy    = (-FL + FR + BL − BR) / 4`
//   `omega = (-FL + FR − BL + BR) / (4 · (Lx + Ly))`
//
// where Lx is half wheelbase, Ly is half track.
//
// Workflow:
//
//   import "stdlib/rods/mecanum.nr"
//
//   let wheels: [4]double;
//   let _ = mecanum_wheels(vx_b, vy_b, w_b, Lx_b, Ly_b,
//                            f64_ptr(&wheels[0]));
//
//   let body: [3]double;   // (vx, vy, omega)
//   let _ = mecanum_velocities(fl_b, fr_b, bl_b, br_b,
//                                Lx_b, Ly_b,
//                                f64_ptr(&body[0]));
//
//   let pose: [3]double;
//   let _ = mecanum_step(x_b, y_b, th_b,
//                         vx_b, vy_b, w_b, dt_b,
//                         f64_ptr(&pose[0]));
//
// Limitations (wheel-slip / over-determined least-squares /
// roller-friction model land in v0.6 if needed):
// - Kinematic only (no slip, no roller friction).
// - X-pattern only (caller flips signs for O-pattern).
//
// See `stdlib/runtime/mecanum_rt.c`.
#cfile "../runtime/mecanum_rt.c"

extern fn nuc_mecanum_wheels(vx_b: i64, vy_b: i64, w_b: i64,
    Lx_b: i64, Ly_b: i64, out_ptr: i64) -> i64;
extern fn nuc_mecanum_velocities(fl_b: i64, fr_b: i64,
    bl_b: i64, br_b: i64, Lx_b: i64, Ly_b: i64, out_ptr: i64) -> i64;
extern fn nuc_mecanum_step(x_b: i64, y_b: i64, th_b: i64,
    vx_b: i64, vy_b: i64, w_b: i64, dt_b: i64, out_ptr: i64) -> i64;

// Inverse kinematics: body (vx, vy, omega) → 4 wheel speeds (FL, FR, BL, BR).
fn mecanum_wheels(vx_b: i64, vy_b: i64, w_b: i64,
    Lx_b: i64, Ly_b: i64, out_ptr: i64) -> i64
{
    return nuc_mecanum_wheels(vx_b, vy_b, w_b, Lx_b, Ly_b, out_ptr);
}

// Forward kinematics: 4 wheel speeds → body (vx, vy, omega).
fn mecanum_velocities(fl_b: i64, fr_b: i64,
    bl_b: i64, br_b: i64, Lx_b: i64, Ly_b: i64, out_ptr: i64) -> i64
{
    return nuc_mecanum_velocities(fl_b, fr_b, bl_b, br_b, Lx_b, Ly_b, out_ptr);
}

// Euler odometry step. Writes new (x, y, theta).
fn mecanum_step(x_b: i64, y_b: i64, th_b: i64,
    vx_b: i64, vy_b: i64, w_b: i64, dt_b: i64, out_ptr: i64) -> i64
{
    return nuc_mecanum_step(x_b, y_b, th_b, vx_b, vy_b, w_b, dt_b, out_ptr);
}
