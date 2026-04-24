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
