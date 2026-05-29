// rods/mpc — Receding-horizon Model Predictive Control wrapper
// around `ilqr.nr`.
//
// Standard MPC pattern: at each control tick, observe the current
// state, plan an optimal control sequence over a finite horizon T
// (warm-started from the previous tick's solution), execute only
// the first control, shift the warm-start sequence, and tick again.
//
// This rod is a thin persistent layer over the existing iLQR
// runtime. The dynamics + cost callbacks are the same iLQR
// callbacks (see `ilqr.nr` for their contract).
//
// Workflow:
//
//   import "stdlib/rods/mpc.nr"
//
//   // Build once.
//   let m = mpc_new(n_x, n_u, T, max_iters_per_step);
//   mpc_set_callbacks(m, dynamics_fp, stage_cost_fp, terminal_cost_fp);
//
//   // Optionally seed warm-start (else starts at all zeros).
//   //   u_seq is double[T * n_u].
//   mpc_warm_start(m, u_seq_ptr);
//
//   // Each control tick:
//   //   x_ptr is double[n_x] (current state),
//   //   u_out_ptr is double[n_u] (will receive the immediate control).
//   for tick {
//       mpc_step(m, x_ptr, u_out_ptr);
//       // ... apply u_out to the plant ...
//       // (The internal warm start has already been shifted.)
//   }
//
//   mpc_free(m);
//
// Limitations (constrained MPC / robust MPC / shrinking horizon
// land in v0.6 if needed):
// - No state or control constraints. For constrained QPs use
//   `lcp.nr` to assemble + solve the per-step QP yourself.
// - Fixed planning horizon T (set at construction).
//
// See `stdlib/runtime/mpc_rt.c`.
#cfile "../runtime/mpc_rt.c"
// MPC reuses iLQR's runtime; pull it in alongside.
#cfile "../runtime/ilqr_rt.c"

extern fn nuc_mpc_new(n_x: i64, n_u: i64, T: i64, max_iters_per_step: i64) -> i64;
extern fn nuc_mpc_set_callbacks(h: i64, dyn_fp: i64, sc_fp: i64, tc_fp: i64);
extern fn nuc_mpc_warm_start(h: i64, u_seq_ptr: i64);
extern fn nuc_mpc_reset(h: i64);
extern fn nuc_mpc_step(h: i64, x_ptr: i64, u_out_ptr: i64) -> i64;
extern fn nuc_mpc_get_control(h: i64, t: i64, dim: i64) -> i64;
extern fn nuc_mpc_last_iters(h: i64) -> i64;
extern fn nuc_mpc_last_cost(h: i64) -> i64;
extern fn nuc_mpc_free(h: i64);

// Create an MPC handle for n_x states / n_u controls / horizon T.
// `max_iters_per_step` caps iLQR iterations per tick (5–10 is
// typical with warm-starting; larger means slower-but-more-converged).
fn mpc_new(n_x: i64, n_u: i64, T: i64, max_iters_per_step: i64) -> i64 {
    return nuc_mpc_new(n_x, n_u, T, max_iters_per_step);
}

// Bind dynamics + cost callbacks (same contract as iLQR — see
// `ilqr.nr`).
fn mpc_set_callbacks(h: i64, dyn_fp: i64, sc_fp: i64, tc_fp: i64) {
    nuc_mpc_set_callbacks(h, dyn_fp, sc_fp, tc_fp);
}

// Optionally seed the warm-start control sequence from a caller-
// allocated `double[T * n_u]`. Default warm start is all zeros.
fn mpc_warm_start(h: i64, u_seq_ptr: i64) { nuc_mpc_warm_start(h, u_seq_ptr); }

// Reset the warm start to all zeros.
fn mpc_reset(h: i64) { nuc_mpc_reset(h); }

// One tick. Reads current state from `x_ptr` (double[n_x]); writes
// the immediate control to `u_out_ptr` (double[n_u]). Internally
// shifts the warm start by one step (drops u_0, repeats u_{T-1}).
// Returns the number of iLQR iterations performed.
fn mpc_step(h: i64, x_ptr: i64, u_out_ptr: i64) -> i64 {
    return nuc_mpc_step(h, x_ptr, u_out_ptr);
}

// Read the current planned control at horizon step t, dim component.
// Useful for plotting the planned trajectory.
fn mpc_get_control(h: i64, t: i64, dim: i64) -> i64 {
    return nuc_mpc_get_control(h, t, dim);
}

// Diagnostics from the last `mpc_step`.
fn mpc_last_iters(h: i64) -> i64 { return nuc_mpc_last_iters(h); }
fn mpc_last_cost(h: i64) -> i64 { return nuc_mpc_last_cost(h); }

fn mpc_free(h: i64) { nuc_mpc_free(h); }
