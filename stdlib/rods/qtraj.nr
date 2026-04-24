// rods/qtraj — Minimum-snap polynomial trajectory generator for
// quadrotors and other differentially-flat systems.
//
// Mellinger & Kumar 2011. Quadrotor dynamics are differentially
// flat in the four outputs (x, y, z, yaw): given a sufficiently
// smooth trajectory in those outputs, the full 12-state + 4-input
// sequence is recoverable in closed form. Minimum-snap trajectories
// (minimizing the integral of squared 4th derivative of position)
// translate to low control effort and are the canonical choice
// for quadrotor trajectory generation.
//
// One handle = one flat output (one axis). Call this rod four
// times — sharing the same waypoint count + segment times — to
// generate a full quadrotor trajectory:
//
//   import "stdlib/rods/qtraj.nr"
//
//   let tx = qtraj_new(n_seg);
//   let ty = qtraj_new(n_seg);
//   let tz = qtraj_new(n_seg);
//   let tyaw = qtraj_new(n_seg);
//
//   for k in 0..n_seg {
//       qtraj_set_segment_time(tx, k, dt_b);  // (same on all four)
//       qtraj_set_segment_time(ty, k, dt_b);
//       ...
//   }
//   for k in 0..(n_seg + 1) {
//       qtraj_set_waypoint(tx, k, x_b);
//       qtraj_set_waypoint(ty, k, y_b);
//       qtraj_set_waypoint(tz, k, z_b);
//       qtraj_set_waypoint(tyaw, k, yaw_b);
//   }
//   // optional non-zero start/end derivatives (default 0):
//   //   qtraj_set_start_boundary(tx, 1, vx0_b);   // start velocity
//   //   qtraj_set_end_boundary  (tx, 1, vxT_b);   // end velocity
//
//   qtraj_solve(tx);  qtraj_solve(ty);  qtraj_solve(tz);  qtraj_solve(tyaw);
//
//   // Evaluate at absolute time t (auto-finds segment):
//   let pos_b = qtraj_evaluate_total(tx, 0, t_b);
//   let vel_b = qtraj_evaluate_total(tx, 1, t_b);
//   let acc_b = qtraj_evaluate_total(tx, 2, t_b);
//   // ...similarly for ty, tz, tyaw
//
//   qtraj_free(tx);  qtraj_free(ty);  qtraj_free(tz);  qtraj_free(tyaw);
//
// Algorithm: degree-7 polynomial per segment (8 coefficients per
// segment) with KKT-system solve over the snap-cost QP.
//
// **Limitations** (corridor constraints / yaw alignment / general
// degree settings land in v0.6 if needed):
// - Fixed degree 7 (snap-minimizing). Higher orders would minimize
//   crackle (5th derivative) etc.
// - No corridor / obstacle constraints (these turn the QP into a
//   QCQP requiring a more sophisticated solver).
// - No automatic time allocation (segment times are user-specified).
// - Single flat output per handle — call four times for quadrotor.
//
// See `stdlib/runtime/qtraj_rt.c`.
#cfile "../runtime/qtraj_rt.c"

extern fn nuc_qtraj_new(n_seg: i64) -> i64;
extern fn nuc_qtraj_set_waypoint(h: i64, k: i64, x_b: i64);
extern fn nuc_qtraj_set_segment_time(h: i64, k: i64, t_b: i64);
extern fn nuc_qtraj_set_start_boundary(h: i64, deriv: i64, v_b: i64);
extern fn nuc_qtraj_set_end_boundary(h: i64, deriv: i64, v_b: i64);
extern fn nuc_qtraj_n_segments(h: i64) -> i64;
extern fn nuc_qtraj_total_time(h: i64) -> i64;
extern fn nuc_qtraj_solve(h: i64) -> i64;
extern fn nuc_qtraj_evaluate(h: i64, k: i64, deriv: i64, t_b: i64) -> i64;
extern fn nuc_qtraj_evaluate_total(h: i64, deriv: i64, t_b: i64) -> i64;
extern fn nuc_qtraj_free(h: i64);

// Create a new trajectory handle for one flat output, with `n_seg`
// segments (so n_seg + 1 waypoints from start to end).
fn qtraj_new(n_seg: i64) -> i64 { return nuc_qtraj_new(n_seg); }

// Set the position waypoint at boundary `k` (0 = start, n_seg = end).
fn qtraj_set_waypoint(h: i64, k: i64, x_b: i64) {
    nuc_qtraj_set_waypoint(h, k, x_b);
}

// Set the duration of segment `k` (default 1.0 s if not set).
fn qtraj_set_segment_time(h: i64, k: i64, t_b: i64) {
    nuc_qtraj_set_segment_time(h, k, t_b);
}

// Set boundary derivative at the trajectory start. `deriv` ∈ [1, 3]
// for velocity, acceleration, jerk (deriv=0 is taken from the first
// waypoint and is never settable here). Defaults to 0.
fn qtraj_set_start_boundary(h: i64, deriv: i64, v_b: i64) {
    nuc_qtraj_set_start_boundary(h, deriv, v_b);
}

// Set boundary derivative at the trajectory end. Same semantics as
// `qtraj_set_start_boundary`.
fn qtraj_set_end_boundary(h: i64, deriv: i64, v_b: i64) {
    nuc_qtraj_set_end_boundary(h, deriv, v_b);
}

fn qtraj_n_segments(h: i64) -> i64 { return nuc_qtraj_n_segments(h); }
fn qtraj_total_time(h: i64) -> i64 { return nuc_qtraj_total_time(h); }

// Solve the minimum-snap QP. Returns 1 on success, 0 on linear-
// solve failure (typically singular if you specified contradictory
// boundary conditions). Must be called before any `evaluate`.
fn qtraj_solve(h: i64) -> i64 { return nuc_qtraj_solve(h); }

// Evaluate the polynomial trajectory inside segment `k` at relative
// time `t ∈ [0, segment_time(k)]`. `deriv` selects the derivative
// order (0 = position, 1 = velocity, 2 = accel, 3 = jerk, ...).
// Returns the value as bit-cast f64.
fn qtraj_evaluate(h: i64, k: i64, deriv: i64, t_b: i64) -> i64 {
    return nuc_qtraj_evaluate(h, k, deriv, t_b);
}

// Evaluate at absolute time `t ∈ [0, total_time]` — the function
// finds the right segment for you.
fn qtraj_evaluate_total(h: i64, deriv: i64, t_b: i64) -> i64 {
    return nuc_qtraj_evaluate_total(h, deriv, t_b);
}

fn qtraj_free(h: i64) { nuc_qtraj_free(h); }
