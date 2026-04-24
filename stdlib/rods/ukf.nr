// rods/ukf — Unscented Kalman Filter for nonlinear state estimation.
//
// The UKF is the standard alternative to the EKF (`ekf.nr`) for
// systems with strong nonlinearities where the local Jacobian
// linearization doesn't capture the dynamics well. Instead of
// linearizing, the UKF samples 2n+1 deterministic "sigma points"
// around the current mean, propagates each through the nonlinear
// dynamics or measurement function, and reconstructs the posterior
// mean + covariance from the propagated samples.
//
// Same callback contract as EKF:
//   dynamics_fp:    fn(x_ptr, u_ptr, x_next_ptr) -> i64
//   measurement_fp: fn(x_ptr, z_out_ptr) -> i64
//
// Workflow (identical to EKF):
//   let ukf = ukf_new(n_x, n_z, n_u);
//   ukf_set_state(ukf, x0_ptr);
//   ukf_set_covariance(ukf, P0_ptr);
//   ukf_set_process_noise(ukf, Q_ptr);
//   ukf_set_measurement_noise(ukf, R_ptr);
//
//   // At each control step:
//   ukf_predict(ukf, u_ptr, dynamics_fp);
//   ukf_update(ukf, z_ptr, measurement_fp);
//   ukf_get_state(ukf, x_out_ptr);
//
// Standard scaled-sigma-point parameters (Wan & van der Merwe 2000):
// α = 1e-3, β = 2 (Gaussian assumption), κ = 0. Built into the
// constructor; can be overridden later via setters if needed.
//
// **Limitations** (square-root form for numerical stability lands
// in v0.6 if needed):
// - Standard form. For very long-running filters with tight
//   covariance, may need periodic re-symmetrize of P.
//
// See `stdlib/runtime/ukf_rt.c`.
#cfile "../runtime/ukf_rt.c"

extern fn nuc_ukf_new(n_x: i64, n_z: i64, n_u: i64) -> i64;
extern fn nuc_ukf_set_state(h: i64, x_ptr: i64);
extern fn nuc_ukf_set_covariance(h: i64, P_ptr: i64);
extern fn nuc_ukf_set_process_noise(h: i64, Q_ptr: i64);
extern fn nuc_ukf_set_measurement_noise(h: i64, R_ptr: i64);
extern fn nuc_ukf_get_state(h: i64, x_out_ptr: i64);
extern fn nuc_ukf_get_covariance(h: i64, P_out_ptr: i64);
extern fn nuc_ukf_predict(h: i64, u_ptr: i64, dynamics_fp: i64) -> i64;
extern fn nuc_ukf_update(h: i64, z_ptr: i64, measurement_fp: i64) -> i64;
extern fn nuc_ukf_free(h: i64);

fn ukf_new(n_x: i64, n_z: i64, n_u: i64) -> i64 {
    return nuc_ukf_new(n_x, n_z, n_u);
}
fn ukf_set_state(h: i64, x_ptr: i64) { nuc_ukf_set_state(h, x_ptr); }
fn ukf_set_covariance(h: i64, P_ptr: i64) { nuc_ukf_set_covariance(h, P_ptr); }
fn ukf_set_process_noise(h: i64, Q_ptr: i64) { nuc_ukf_set_process_noise(h, Q_ptr); }
fn ukf_set_measurement_noise(h: i64, R_ptr: i64) { nuc_ukf_set_measurement_noise(h, R_ptr); }
fn ukf_get_state(h: i64, x_out_ptr: i64) { nuc_ukf_get_state(h, x_out_ptr); }
fn ukf_get_covariance(h: i64, P_out_ptr: i64) { nuc_ukf_get_covariance(h, P_out_ptr); }

fn ukf_predict(h: i64, u_ptr: i64, dynamics_fp: i64) -> i64 {
    return nuc_ukf_predict(h, u_ptr, dynamics_fp);
}
fn ukf_update(h: i64, z_ptr: i64, measurement_fp: i64) -> i64 {
    return nuc_ukf_update(h, z_ptr, measurement_fp);
}

fn ukf_free(h: i64) { nuc_ukf_free(h); }
