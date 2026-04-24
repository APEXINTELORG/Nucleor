// rods/admit — Per-DOF admittance controller.
//
// Maps measured force to a position command via a virtual mass-
// spring-damper:
//
//   M · ẍ + D · ẋ + K · x = F_meas − F_des
//
// Output: the (x, ẋ) state of the virtual admittance model. Higher-
// level code typically adds `x` as a perturbation to a nominal
// position trajectory ("compliant tracking") so the robot yields
// under contact force.
//
// Compare to **impedance** control (the dual): impedance maps
// position deviation to commanded force; admittance maps measured
// force to commanded position. Use admittance for position-
// controlled robots that need force compliance.
//
// Workflow:
//
//   import "stdlib/rods/admit.nr"
//
//   let h = admit_new(n_dof);
//   for d in 0..n_dof {
//       admit_set_gains(h, d, M_b, D_b, K_b);
//       admit_set_force_target(h, d, f_des_b);   // typically 0 (free)
//   }
//
//   for tick {
//       admit_step(h, force_meas_ptr, dt_b);     // double[n_dof]
//       for d in 0..n_dof {
//           let x_b = admit_get_position(h, d);
//           // ... add x to nominal position command ...
//       }
//   }
//
//   admit_free(h);
//
// **Limitations** (full SE(3) impedance / coupling between DOFs /
// adaptive admittance land in v0.6 if needed):
// - Per-DOF independent (no off-diagonal M, D, K).
// - Linear time-invariant — no auto-gain-scheduling.
//
// See `stdlib/runtime/admit_rt.c`.
#cfile "../runtime/admit_rt.c"

extern fn nuc_admit_new(n_dof: i64) -> i64;
extern fn nuc_admit_set_gains(h: i64, dim: i64, M_b: i64, D_b: i64, K_b: i64);
extern fn nuc_admit_set_force_target(h: i64, dim: i64, f_b: i64);
extern fn nuc_admit_reset(h: i64);
extern fn nuc_admit_step(h: i64, force_meas_ptr: i64, dt_b: i64);
extern fn nuc_admit_get_position(h: i64, dim: i64) -> i64;
extern fn nuc_admit_get_velocity(h: i64, dim: i64) -> i64;
extern fn nuc_admit_free(h: i64);

// Create an admittance controller with `n_dof` independent DOFs.
// All DOFs default to M = D = K = 1.0; reset to zero state.
fn admit_new(n_dof: i64) -> i64 { return nuc_admit_new(n_dof); }

// Per-DOF gain setting.
fn admit_set_gains(h: i64, dim: i64, M_b: i64, D_b: i64, K_b: i64) {
    nuc_admit_set_gains(h, dim, M_b, D_b, K_b);
}

// Per-DOF desired force (typically 0 = "yield freely under any
// applied force").
fn admit_set_force_target(h: i64, dim: i64, f_b: i64) {
    nuc_admit_set_force_target(h, dim, f_b);
}

// Reset internal (x, ẋ) state to zero.
fn admit_reset(h: i64) { nuc_admit_reset(h); }

// One tick. `force_meas_ptr` is `double[n_dof]`; `dt_b` is timestep.
fn admit_step(h: i64, force_meas_ptr: i64, dt_b: i64) {
    nuc_admit_step(h, force_meas_ptr, dt_b);
}

// Read position perturbation / velocity for a DOF.
fn admit_get_position(h: i64, dim: i64) -> i64 { return nuc_admit_get_position(h, dim); }
fn admit_get_velocity(h: i64, dim: i64) -> i64 { return nuc_admit_get_velocity(h, dim); }

fn admit_free(h: i64) { nuc_admit_free(h); }
