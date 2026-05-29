// rods/ekf — Extended Kalman Filter for nonlinear state estimation.
//
// Standard Bayesian estimator for systems with nonlinear dynamics
// f(x, u) and nonlinear measurement model h(x). Linearizes both
// around the current state estimate, then runs the standard
// Kalman filter recursion:
//
//   Predict: x⁻ = f(x, u);  F = ∂f/∂x;  P⁻ = F·P·Fᵀ + Q
//   Update:  y = z − h(x⁻); H = ∂h/∂x;  S = H·P⁻·Hᵀ + R
//            K = P⁻·Hᵀ·S⁻¹; x = x⁻ + K·y; P = (I − KH)·P⁻
//
// Foundation for sensor fusion (IMU + odometry + GPS), SLAM
// front-ends, model-based observers, and any time-varying state
// estimation.
//
// Workflow:
//   let ekf = ekf_new(n_x, n_z, n_u);
//   ekf_set_state(ekf, x0_ptr);
//   ekf_set_covariance(ekf, P0_ptr);    // initial uncertainty
//   ekf_set_process_noise(ekf, Q_ptr);  // n_x × n_x
//   ekf_set_measurement_noise(ekf, R_ptr);  // n_z × n_z
//
//   // At each step:
//   ekf_predict(ekf, u_ptr, dynamics_fp);
//   ekf_update(ekf, z_ptr, measurement_fp);
//   ekf_get_state(ekf, x_out_ptr);
//
// Callbacks:
//   dynamics_fp:    fn(x_ptr, u_ptr, x_next_ptr) -> i64
//   measurement_fp: fn(x_ptr, z_out_ptr) -> i64
//
// Both Jacobians are computed by numerical finite differences
// against the same callbacks (no analytical-Jacobian requirement).
//
// Limitations (UKF / particle filter / square-root form land
// in v0.6 if needed):
// - Standard EKF (no UKF / sigma-point variants).
// - Numerical-FD Jacobians (slower than analytical).
// - No square-root form — for very long-running filters with tight
//   covariance, prefer UKF or manually re-symmetrize P periodically.
//
// See `stdlib/runtime/ekf_rt.c`.
#cfile "../runtime/ekf_rt.c"

extern fn nuc_ekf_new(n_x: i64, n_z: i64, n_u: i64) -> i64;
extern fn nuc_ekf_set_state(h: i64, x_ptr: i64);
extern fn nuc_ekf_set_covariance(h: i64, P_ptr: i64);
extern fn nuc_ekf_set_process_noise(h: i64, Q_ptr: i64);
extern fn nuc_ekf_set_measurement_noise(h: i64, R_ptr: i64);
extern fn nuc_ekf_get_state(h: i64, x_out_ptr: i64);
extern fn nuc_ekf_get_covariance(h: i64, P_out_ptr: i64);
extern fn nuc_ekf_predict(h: i64, u_ptr: i64, dynamics_fp: i64) -> i64;
extern fn nuc_ekf_update(h: i64, z_ptr: i64, measurement_fp: i64) -> i64;
extern fn nuc_ekf_free(h: i64);

// Create an EKF for an n_x state vector, n_z measurement, n_u
// control input. Defaults: x = 0, P = I, Q = 0.01·I, R = 0.1·I.
fn ekf_new(n_x: i64, n_z: i64, n_u: i64) -> i64 {
    return nuc_ekf_new(n_x, n_z, n_u);
}

fn ekf_set_state(h: i64, x_ptr: i64) { nuc_ekf_set_state(h, x_ptr); }
fn ekf_set_covariance(h: i64, P_ptr: i64) { nuc_ekf_set_covariance(h, P_ptr); }
fn ekf_set_process_noise(h: i64, Q_ptr: i64) { nuc_ekf_set_process_noise(h, Q_ptr); }
fn ekf_set_measurement_noise(h: i64, R_ptr: i64) { nuc_ekf_set_measurement_noise(h, R_ptr); }
fn ekf_get_state(h: i64, x_out_ptr: i64) { nuc_ekf_get_state(h, x_out_ptr); }
fn ekf_get_covariance(h: i64, P_out_ptr: i64) { nuc_ekf_get_covariance(h, P_out_ptr); }

// Predict step: applies the dynamics model and propagates
// covariance. Returns 0 on success.
fn ekf_predict(h: i64, u_ptr: i64, dynamics_fp: i64) -> i64 {
    return nuc_ekf_predict(h, u_ptr, dynamics_fp);
}

// Update step: integrates a new measurement. Returns 0 on success,
// -1 if the innovation covariance is singular (indicates a
// modeling problem — measurement noise R should be positive).
fn ekf_update(h: i64, z_ptr: i64, measurement_fp: i64) -> i64 {
    return nuc_ekf_update(h, z_ptr, measurement_fp);
}

fn ekf_free(h: i64) { nuc_ekf_free(h); }
