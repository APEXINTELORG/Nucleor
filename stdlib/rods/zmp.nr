// rods/zmp — Zero Moment Point (ZMP) tracking via cart-table
// inverse dynamics + finite-horizon LQR (Kajita 2003 / 2014).
//
// Bipedal locomotion convention: model the robot as a single-mass
// inverted pendulum (the "cart-table"). The ZMP — the point where
// the ground reaction force passes — must stay inside the support
// polygon for static stability. The relationship between the
// horizontal CoM trajectory `c(t)` and the ZMP `p(t)` is
//
//   p = c − (h / g) · c̈
//
// where `h` is the constant CoM height and `g` is gravity. Given
// a desired ZMP reference `p_ref(t)` (typically inside the support
// polygon at each step), this rod inverts the cart-table dynamics
// to compute the CoM trajectory `c(t)` whose induced ZMP best
// tracks `p_ref(t)`.
//
// The two horizontal axes (x and y) are decoupled under the
// linear cart-table model — call this rod twice (one handle
// for x, one for y) sharing the same `dt`, `h`, and step count.
//
// Workflow:
//
//   import "stdlib/rods/zmp.nr"
//
//   let h_x = zmp_new(h_b, dt_b, n_steps);
//   let h_y = zmp_new(h_b, dt_b, n_steps);
//
//   for k in 0..n_steps {
//       zmp_set_zmp_ref(h_x, k, x_ref_b);
//       zmp_set_zmp_ref(h_y, k, y_ref_b);
//   }
//   zmp_set_initial_state(h_x, c0_x_b, cdot0_x_b, cddot0_x_b);
//   zmp_set_initial_state(h_y, c0_y_b, cdot0_y_b, cddot0_y_b);
//
//   zmp_solve(h_x, R_b);
//   zmp_solve(h_y, R_b);
//
//   for k in 0..(n_steps + 1) {
//       let cx_b = zmp_com(h_x, k);
//       let cy_b = zmp_com(h_y, k);
//       // ... drive whole-body controller with this CoM trajectory ...
//   }
//
//   zmp_free(h_x);  zmp_free(h_y);
//
// Limitations (3-D / online preview / variable-height land in
// v0.6 if needed):
// - 1-D per call (call twice for x and y).
// - Constant CoM height `h`. Variable-height (LIPM with vertical
//   motion) requires a different model.
// - Offline (whole-trajectory) — for online MPC, feed each window
//   of `p_ref` through this rod with a rolling horizon.
//
// See `stdlib/runtime/zmp_rt.c`.
#cfile "../runtime/zmp_rt.c"

extern fn nuc_zmp_new(h_b: i64, dt_b: i64, n_steps: i64) -> i64;
extern fn nuc_zmp_set_zmp_ref(h: i64, k: i64, v_b: i64);
extern fn nuc_zmp_set_initial_state(h: i64, c_b: i64, cdot_b: i64, cddot_b: i64);
extern fn nuc_zmp_solve(h: i64, R_b: i64) -> i64;
extern fn nuc_zmp_com(h: i64, k: i64) -> i64;
extern fn nuc_zmp_com_velocity(h: i64, k: i64) -> i64;
extern fn nuc_zmp_com_accel(h: i64, k: i64) -> i64;
extern fn nuc_zmp_zmp_actual(h: i64, k: i64) -> i64;
extern fn nuc_zmp_jerk(h: i64, k: i64) -> i64;
extern fn nuc_zmp_free(h: i64);

// Create a ZMP-tracking handle for one horizontal axis. `h_b` is
// the constant CoM height; `dt_b` is the timestep; `n_steps` is
// the number of timesteps in the trajectory.
fn zmp_new(h_b: i64, dt_b: i64, n_steps: i64) -> i64 {
    return nuc_zmp_new(h_b, dt_b, n_steps);
}

// Set the desired ZMP at step k (0-indexed, k ∈ [0, n_steps)).
fn zmp_set_zmp_ref(h: i64, k: i64, v_b: i64) {
    nuc_zmp_set_zmp_ref(h, k, v_b);
}

// Set the initial CoM state (position, velocity, acceleration).
fn zmp_set_initial_state(h: i64, c_b: i64, cdot_b: i64, cddot_b: i64) {
    nuc_zmp_set_initial_state(h, c_b, cdot_b, cddot_b);
}

// Solve the finite-horizon tracking LQR. `R_b` is the jerk-cost
// weight (small, e.g. 1e-6). Returns 1 on success.
fn zmp_solve(h: i64, R_b: i64) -> i64 { return nuc_zmp_solve(h, R_b); }

// CoM position / velocity / acceleration at step k ∈ [0, n_steps].
fn zmp_com(h: i64, k: i64)          -> i64 { return nuc_zmp_com(h, k); }
fn zmp_com_velocity(h: i64, k: i64) -> i64 { return nuc_zmp_com_velocity(h, k); }
fn zmp_com_accel(h: i64, k: i64)    -> i64 { return nuc_zmp_com_accel(h, k); }

// Induced ZMP at step k ∈ [0, n_steps).
fn zmp_zmp_actual(h: i64, k: i64) -> i64 { return nuc_zmp_zmp_actual(h, k); }

// Jerk command at step k ∈ [0, n_steps).
fn zmp_jerk(h: i64, k: i64) -> i64 { return nuc_zmp_jerk(h, k); }

fn zmp_free(h: i64) { nuc_zmp_free(h); }
