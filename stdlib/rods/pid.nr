// rods/pid — Classic PID controller with anti-windup.
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
//   let p = pid_new(kp_b, ki_b, kd_b);
//   pid_set_integral_clamp(p, i_lo_b, i_hi_b);   // optional
//   pid_set_output_clamp  (p, u_lo_b, u_hi_b);   // optional
//
//   for tick {
//       let u_b = pid_step(p, setpoint_b, meas_b, dt_b);
//       // ... apply u to the plant ...
//   }
//   pid_reset(p);   // when starting a new run
//   pid_free(p);
//
// **Limitations** (gain scheduling / derivative-on-measurement /
// setpoint weighting land in v0.6 if needed):
// - Single SISO controller. For multi-DOF coordination use a stack
//   of independent PIDs or a model-based controller (`wbc.nr`,
//   `ilqr.nr`).
// - Derivative is on the error signal (can spike at setpoint
//   changes). "Derivative on measurement" planned for v0.6.
//
// See `stdlib/runtime/pid_rt.c`.
#cfile "../runtime/pid_rt.c"

extern fn nuc_pid_new(kp_b: i64, ki_b: i64, kd_b: i64) -> i64;
extern fn nuc_pid_set_gains(h: i64, kp_b: i64, ki_b: i64, kd_b: i64);
extern fn nuc_pid_set_integral_clamp(h: i64, lo_b: i64, hi_b: i64);
extern fn nuc_pid_set_output_clamp(h: i64, lo_b: i64, hi_b: i64);
extern fn nuc_pid_reset(h: i64);
extern fn nuc_pid_step(h: i64, setpoint_b: i64, meas_b: i64, dt_b: i64) -> i64;
extern fn nuc_pid_integral(h: i64) -> i64;
extern fn nuc_pid_last_error(h: i64) -> i64;
extern fn nuc_pid_free(h: i64);

// Create a PID controller with the given gains (bit-cast f64).
fn pid_new(kp_b: i64, ki_b: i64, kd_b: i64) -> i64 {
    return nuc_pid_new(kp_b, ki_b, kd_b);
}

// Update gains in place (e.g. for live tuning).
fn pid_set_gains(h: i64, kp_b: i64, ki_b: i64, kd_b: i64) {
    nuc_pid_set_gains(h, kp_b, ki_b, kd_b);
}

// Set anti-windup bounds on the integral term. Default ±∞ (no clamp).
fn pid_set_integral_clamp(h: i64, lo_b: i64, hi_b: i64) {
    nuc_pid_set_integral_clamp(h, lo_b, hi_b);
}

// Set bounds on the output. Default ±∞ (no clamp).
fn pid_set_output_clamp(h: i64, lo_b: i64, hi_b: i64) {
    nuc_pid_set_output_clamp(h, lo_b, hi_b);
}

// Reset integral and derivative state. Call at the start of each run.
fn pid_reset(h: i64) { nuc_pid_reset(h); }

// One control step. Returns the (clamped) command as bit-cast f64.
fn pid_step(h: i64, setpoint_b: i64, meas_b: i64, dt_b: i64) -> i64 {
    return nuc_pid_step(h, setpoint_b, meas_b, dt_b);
}

// Read internal state (diagnostics).
fn pid_integral(h: i64) -> i64 { return nuc_pid_integral(h); }
fn pid_last_error(h: i64) -> i64 { return nuc_pid_last_error(h); }

fn pid_free(h: i64) { nuc_pid_free(h); }
