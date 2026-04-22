// =====================================================
// rods/control — Control Systems
// =====================================================
// Import: import "stdlib/rods/control.nr"
// Provides: PID controller, state-space model, Kalman filter
//   (predict + update + state extraction).
// =====================================================

#cfile "../runtime/control_rt.c"

extern fn nuc_pid_new(Kp: i64, Ki: i64, Kd: i64) -> i64;
extern fn nuc_pid_update(h: i64, setpoint: i64, measurement: i64, dt: i64) -> i64;
extern fn nuc_pid_reset(h: i64);
extern fn nuc_ss_new(A: i64, B: i64, C: i64, D: i64, n: i64, m: i64, p: i64) -> i64;
extern fn nuc_ss_step(h: i64, u: i64, dt: i64) -> i64;
extern fn nuc_kalman_new(A: i64, B: i64, C: i64, Q: i64, R: i64, n: i64, m_in: i64, m_obs: i64) -> i64;
extern fn nuc_kalman_predict(h: i64, u: i64);
extern fn nuc_kalman_update(h: i64, z: i64) -> i64;
extern fn nuc_kalman_state(h: i64) -> i64;

fn pid_new(Kp: i64, Ki: i64, Kd: i64) -> i64 { return nuc_pid_new(Kp, Ki, Kd); }
fn pid_update(h: i64, setpoint: i64, measurement: i64, dt: i64) -> i64 {
    return nuc_pid_update(h, setpoint, measurement, dt);
}
fn pid_reset(h: i64) { nuc_pid_reset(h); }
fn ss_new(A: i64, B: i64, C: i64, D: i64, n: i64, m: i64, p: i64) -> i64 { return nuc_ss_new(A, B, C, D, n, m, p); }
fn ss_step(h: i64, u: i64, dt: i64) -> i64 { return nuc_ss_step(h, u, dt); }
fn kalman_new(A: i64, B: i64, C: i64, Q: i64, R: i64, n: i64, m_in: i64, m_obs: i64) -> i64 {
    return nuc_kalman_new(A, B, C, Q, R, n, m_in, m_obs);
}
fn kalman_predict(h: i64, u: i64) { nuc_kalman_predict(h, u); }
fn kalman_update(h: i64, z: i64) -> i64 { return nuc_kalman_update(h, z); }
fn kalman_state(h: i64) -> i64 { return nuc_kalman_state(h); }
