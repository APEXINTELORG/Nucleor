// rods/pidc — Classic PID controller with anti-windup integral
// clamp + output clamp. Drop-in replacement for the simpler
// pid_new/pid_update/pid_reset trio in `control.nr` (which lacks
// clamps). Named `pidc` to avoid the C-symbol collision with
// `control.nr`'s `nuc_pid_*` functions.
//
//   u(t) = Kp · e(t) + Ki · ∫₀^t e(τ) dτ + Kd · de/dt
//
// Discrete update each call:
//   error    = setpoint − measurement
//   integral = clamp(integral + error · dt, i_lo, i_hi)
//   deriv    = (error − last_error) / dt
//   u        = clamp(Kp·error + Ki·integral + Kd·deriv, u_lo, u_hi)
//
// Anti-windup: integral is clamped to a user-set range so it does
// not run away during output saturation. Output is clamped after
// the sum so the caller can see the actual command.
//
// Workflow:
//
//   import "stdlib/rods/pid.nr"
//
//   let p = pidc_new(kp_b, ki_b, kd_b);
//   pidc_set_integral_clamp(p, i_lo_b, i_hi_b);   // optional
//   pidc_set_output_clamp  (p, u_lo_b, u_hi_b);   // optional
//
//   for tick {
//       let u_b = pidc_step(p, setpoint_b, meas_b, dt_b);
//       // ... apply u to the plant ...
//   }
//   pidc_reset(p);   // when starting a new run
//   pidc_free(p);
//
// Limitations (gain scheduling / derivative-on-measurement /
// setpoint weighting land in v0.6 if needed):
// - Single SISO controller. For multi-DOF coordination use a stack
//   of independent PIDs or a model-based controller (`wbc.nr`,
//   `ilqr.nr`).
// - Derivative is on the error signal (can spike at setpoint
//   changes). "Derivative on measurement" planned for v0.6.
//
// See `stdlib/runtime/pidc_rt.c`.
#cfile "../runtime/pidc_rt.c"

extern fn nuc_pidc_new(kp_b: i64, ki_b: i64, kd_b: i64) -> i64;
extern fn nuc_pidc_set_gains(h: i64, kp_b: i64, ki_b: i64, kd_b: i64);
extern fn nuc_pidc_set_integral_clamp(h: i64, lo_b: i64, hi_b: i64);
extern fn nuc_pidc_set_output_clamp(h: i64, lo_b: i64, hi_b: i64);
extern fn nuc_pidc_reset(h: i64);
extern fn nuc_pidc_step(h: i64, setpoint_b: i64, meas_b: i64, dt_b: i64) -> i64;
extern fn nuc_pidc_integral(h: i64) -> i64;
extern fn nuc_pidc_last_error(h: i64) -> i64;
extern fn nuc_pidc_free(h: i64);

// Create a PID controller with the given gains (bit-cast f64).
fn pidc_new(kp_b: i64, ki_b: i64, kd_b: i64) -> i64 {
    return nuc_pidc_new(kp_b, ki_b, kd_b);
}

// Update gains in place (e.g. for live tuning).
fn pidc_set_gains(h: i64, kp_b: i64, ki_b: i64, kd_b: i64) {
    nuc_pidc_set_gains(h, kp_b, ki_b, kd_b);
}

// Set anti-windup bounds on the integral term. Default ±∞ (no clamp).
fn pidc_set_integral_clamp(h: i64, lo_b: i64, hi_b: i64) {
    nuc_pidc_set_integral_clamp(h, lo_b, hi_b);
}

// Set bounds on the output. Default ±∞ (no clamp).
fn pidc_set_output_clamp(h: i64, lo_b: i64, hi_b: i64) {
    nuc_pidc_set_output_clamp(h, lo_b, hi_b);
}

// Reset integral and derivative state. Call at the start of each run.
fn pidc_reset(h: i64) { nuc_pidc_reset(h); }

// One control step. Returns the (clamped) command as bit-cast f64.
fn pidc_step(h: i64, setpoint_b: i64, meas_b: i64, dt_b: i64) -> i64 {
    return nuc_pidc_step(h, setpoint_b, meas_b, dt_b);
}

// Read internal state (diagnostics).
fn pidc_integral(h: i64) -> i64 { return nuc_pidc_integral(h); }
fn pidc_last_error(h: i64) -> i64 { return nuc_pidc_last_error(h); }

fn pidc_free(h: i64) { nuc_pidc_free(h); }
