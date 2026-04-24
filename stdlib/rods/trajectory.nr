// rods/trajectory — Smooth time-parameterized joint trajectories.
//
// Quintic (5th order) polynomial: given start (q, v, a) and goal
// (q, v, a) over duration T, produce a polynomial that hits both
// boundary conditions exactly with C² continuity (smooth velocity
// and acceleration). Good for actuator-limited systems.
//
//   q(t)  = a0 + a1·t + a2·t² + a3·t³ + a4·t⁴ + a5·t⁵
//   q'(t) =      a1 + 2·a2·t + 3·a3·t² + 4·a4·t³ + 5·a5·t⁴
//   q''(t)=             2·a2 + 6·a3·t + 12·a4·t² + 20·a5·t³
//
// Trapezoidal velocity profiles, S-curves, DMPs, and TOPP-RA
// (time-optimal path parameterization) ship in v0.5 alongside the
// URDF integration.
//
// See `stdlib/runtime/trajectory_rt.c`.
#cfile "../runtime/trajectory_rt.c"

extern fn nuc_quintic_new(
    T_bits: i64,
    q0_bits: i64, v0_bits: i64, a0_bits: i64,
    qT_bits: i64, vT_bits: i64, aT_bits: i64) -> i64;
extern fn nuc_quintic_duration(h: i64) -> i64;
extern fn nuc_quintic_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_vel_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_acc_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_quintic_free(h: i64);

fn quintic_new(T_bits: i64,
    q0_bits: i64, v0_bits: i64, a0_bits: i64,
    qT_bits: i64, vT_bits: i64, aT_bits: i64) -> i64 {
    return nuc_quintic_new(T_bits, q0_bits, v0_bits, a0_bits, qT_bits, vT_bits, aT_bits);
}
fn quintic_duration(h: i64) -> i64 { return nuc_quintic_duration(h); }
fn quintic_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_pos_at(h, t_bits); }
fn quintic_vel_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_vel_at(h, t_bits); }
fn quintic_acc_at(h: i64, t_bits: i64) -> i64 { return nuc_quintic_acc_at(h, t_bits); }
fn quintic_free(h: i64) { nuc_quintic_free(h); }

// === Trapezoidal velocity profile (v0.2.181) ===
//
// Three-phase profile with constant-acceleration ramp-up, constant-
// velocity cruise, constant-deceleration ramp-down. Respects explicit
// `v_max` and `a_max` limits. If the displacement is too small to
// reach `v_max`, automatically collapses to a triangular (two-phase)
// profile with a lower reachable peak velocity.
//
// Best for actuator-limited systems where hitting velocity /
// acceleration ceilings would saturate the motor controller.
extern fn nuc_trapezoid_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64) -> i64;
extern fn nuc_trapezoid_duration(h: i64) -> i64;
extern fn nuc_trapezoid_peak_v(h: i64) -> i64;
extern fn nuc_trapezoid_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_trapezoid_vel_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_trapezoid_free(h: i64);

fn trapezoid_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64) -> i64 {
    return nuc_trapezoid_new(q0_bits, qT_bits, vmax_bits, amax_bits);
}
fn trapezoid_duration(h: i64) -> i64 { return nuc_trapezoid_duration(h); }
fn trapezoid_peak_v(h: i64) -> i64 { return nuc_trapezoid_peak_v(h); }
fn trapezoid_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_trapezoid_pos_at(h, t_bits); }
fn trapezoid_vel_at(h: i64, t_bits: i64) -> i64 { return nuc_trapezoid_vel_at(h, t_bits); }
fn trapezoid_free(h: i64) { nuc_trapezoid_free(h); }

// === S-curve (bounded-jerk) profile (v0.2.191) ===
//
// Seven-phase profile that respects velocity, acceleration, AND
// jerk limits. Smoother than trapezoidal — no acceleration step;
// the acceleration itself ramps up and down via a constant-jerk
// phase. Industrial CNC, pick-and-place, any system where
// acceleration discontinuities cause residual vibration or
// position overshoot.
//
// For long enough motions, the profile reaches the requested
// `v_max`, `a_max`, and `j_max` plateaus. For shorter motions,
// the profile auto-collapses (constant-accel phase shrinks to
// zero, then cruise phase shrinks to zero) and the actual peak
// v / peak a are reduced. Read back via `scurve_peak_v` /
// `scurve_peak_a`.
extern fn nuc_scurve_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64, jmax_bits: i64) -> i64;
extern fn nuc_scurve_duration(h: i64) -> i64;
extern fn nuc_scurve_peak_v(h: i64) -> i64;
extern fn nuc_scurve_peak_a(h: i64) -> i64;
extern fn nuc_scurve_pos_at(h: i64, t_bits: i64) -> i64;
extern fn nuc_scurve_free(h: i64);

fn scurve_new(q0_bits: i64, qT_bits: i64, vmax_bits: i64, amax_bits: i64, jmax_bits: i64) -> i64 {
    return nuc_scurve_new(q0_bits, qT_bits, vmax_bits, amax_bits, jmax_bits);
}
fn scurve_duration(h: i64) -> i64 { return nuc_scurve_duration(h); }
fn scurve_peak_v(h: i64) -> i64 { return nuc_scurve_peak_v(h); }
fn scurve_peak_a(h: i64) -> i64 { return nuc_scurve_peak_a(h); }
fn scurve_pos_at(h: i64, t_bits: i64) -> i64 { return nuc_scurve_pos_at(h, t_bits); }
fn scurve_free(h: i64) { nuc_scurve_free(h); }
