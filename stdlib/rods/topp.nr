// rods/topp — Trapezoidal time-parameterization for a 1-D
// arc-length path.
//
// Given a path total length `L`, max velocity `v_max`, and max
// acceleration `a_max`, computes the minimum-time trajectory
// `s(t)` along the path with `|ṡ| ≤ v_max` and `|s̈| ≤ a_max`:
//
//   - Accelerate at `a_max` until reaching `v_max`
//     (duration `t1 = v_max / a_max`).
//   - Cruise at `v_max` for the middle (skipped if path too short).
//   - Decelerate symmetrically.
//
// If the cruise phase doesn't fit, falls back to a triangular
// profile peaking at `√(L · a_max) < v_max`.
//
// Use to time-parameterize a geometric path (e.g. minimum-snap
// polynomial from `qtraj.nr`): the user gets `t → s(t)` and maps
// `s` back to robot configuration via the original path.
//
// Workflow:
//
//   import "stdlib/rods/topp.nr"
//
//   let h = topp_trap_new(L_b, v_max_b, a_max_b);
//   let T = topp_trap_total_time(h);
//
//   for t in 0..N {
//       let s_b = topp_trap_position(h, t_b);
//       let v_b = topp_trap_velocity(h, t_b);
//       let a_b = topp_trap_acceleration(h, t_b);
//       // ... map s(t) back to robot config via geometric path ...
//   }
//
//   topp_trap_free(h);
//
// **Limitations** (full phase-plane TOPP / curvature-dependent
// limits / s-curve land in v0.6 if needed):
// - Single global v_max + a_max (no path-dependent limits). For
//   joint-space paths, conservatively pick
//   `v_max = min over (s, dof) of  v_max_dof / |path_velocity_dof(s)|`.
// - Symmetric ramp; no asymmetric accel/decel limits.
// - Trapezoidal — jerk is a δ-spike at corners. For jerk-limited
//   profiles use s-curves (planned for v0.6).
//
// See `stdlib/runtime/topp_rt.c`.
#cfile "../runtime/topp_rt.c"

extern fn nuc_topp_trap_new(L_b: i64, v_max_b: i64, a_max_b: i64) -> i64;
extern fn nuc_topp_trap_total_time(h: i64) -> i64;
extern fn nuc_topp_trap_path_length(h: i64) -> i64;
extern fn nuc_topp_trap_peak_velocity(h: i64) -> i64;
extern fn nuc_topp_trap_position(h: i64, t_b: i64) -> i64;
extern fn nuc_topp_trap_velocity(h: i64, t_b: i64) -> i64;
extern fn nuc_topp_trap_acceleration(h: i64, t_b: i64) -> i64;
extern fn nuc_topp_trap_free(h: i64);

// Build a trapezoidal time-parameterization for a path of length L
// with velocity ceiling v_max and acceleration ceiling a_max.
// Returns 0 on bad input (any non-positive value).
fn topp_trap_new(L_b: i64, v_max_b: i64, a_max_b: i64) -> i64 {
    return nuc_topp_trap_new(L_b, v_max_b, a_max_b);
}

// Total trajectory time T (so path is fully traversed at t = T).
fn topp_trap_total_time(h: i64) -> i64 { return nuc_topp_trap_total_time(h); }

// Path length (echoed for convenience).
fn topp_trap_path_length(h: i64) -> i64 { return nuc_topp_trap_path_length(h); }

// Peak velocity reached during the trajectory. Equals v_max for a
// trapezoidal profile, less than v_max for a triangular one.
fn topp_trap_peak_velocity(h: i64) -> i64 { return nuc_topp_trap_peak_velocity(h); }

// Position s(t) ∈ [0, L]. Clipped to [0, L] outside [0, T].
fn topp_trap_position(h: i64, t_b: i64) -> i64 {
    return nuc_topp_trap_position(h, t_b);
}

// First and second derivatives (along path).
fn topp_trap_velocity(h: i64, t_b: i64) -> i64 {
    return nuc_topp_trap_velocity(h, t_b);
}
fn topp_trap_acceleration(h: i64, t_b: i64) -> i64 {
    return nuc_topp_trap_acceleration(h, t_b);
}

fn topp_trap_free(h: i64) { nuc_topp_trap_free(h); }
