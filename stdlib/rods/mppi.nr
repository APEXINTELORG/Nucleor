// rods/mppi — Model Predictive Path Integral control (Williams,
// Aldrich & Theodorou 2016/2017).
//
// Sample-based MPC variant: at each control tick, sample `K` noisy
// control sequences, roll them out through the dynamics, score
// them by stage + terminal cost, weight them by `exp(−J/λ)`, and
// use the weighted average as the new nominal sequence. Output the
// first control of the nominal, then shift.
//
// **No gradient required** — works with arbitrary non-smooth
// dynamics and costs (binary obstacle indicator costs, friction
// stick-slip transitions, etc.) where iLQR / DDP would fail.
// Naturally embarrassingly parallel (each sample is independent).
//
// Compare to:
//   - `ilqr.nr`, `mpc.nr` — gradient-based; fast for smooth problems
//     but stuck on non-smooth costs/dynamics.
//   - `cilqr.nr` — gradient-based + box constraints.
//   - `mppi.nr` (this rod) — gradient-free, sample-based; great for
//     contact-rich tasks, obstacle indicators, hybrid systems.
//
// Workflow:
//
//   import "stdlib/rods/mppi.nr"
//
//   let h = mppi_new(n_x, n_u, T, K, lambda_b, seed);
//   for d in 0..n_u { mppi_set_sigma(h, d, sigma_d_b); }
//   mppi_set_callbacks(h, dyn_fp, stage_cost_fp, terminal_cost_fp);
//
//   for tick {
//       mppi_step(h, x_ptr, u_out_ptr);
//       // ... apply u_out ...
//   }
//
//   mppi_free(h);
//
// Tuning:
//   - K ∈ [256, 4096] typical. Higher = better averaging at higher
//     compute cost.
//   - λ small ⇒ aggressive (favors best samples); λ large ⇒ smoother.
//   - σ ≈ expected control magnitude.
//
// **Limitations** (importance-sampling tricks / GPU / smoothing
// land in v0.6 if needed):
// - Single-threaded sequential sampling.
// - Diagonal (per-dim) σ only.
// - No control bounds enforcement (clamp inside dynamics callback
//   if needed, or use `cilqr.nr` for hard bounds).
//
// See `stdlib/runtime/mppi_rt.c`.
#cfile "../runtime/mppi_rt.c"

extern fn nuc_mppi_new(n_x: i64, n_u: i64, T: i64, K: i64,
    lambda_b: i64, seed: i64) -> i64;
extern fn nuc_mppi_set_callbacks(h: i64, dyn_fp: i64, sc_fp: i64, tc_fp: i64);
extern fn nuc_mppi_set_sigma(h: i64, dim: i64, sigma_b: i64);
extern fn nuc_mppi_warm_start(h: i64, u_seq_ptr: i64);
extern fn nuc_mppi_reset(h: i64);
extern fn nuc_mppi_step(h: i64, x_ptr: i64, u_out_ptr: i64) -> i64;
extern fn nuc_mppi_get_control(h: i64, t: i64, dim: i64) -> i64;
extern fn nuc_mppi_free(h: i64);

// Create an MPPI controller. `K` is the number of rollout samples
// per tick; `lambda_b` is the temperature; `seed` is the RNG seed.
// All sigma defaults to 1.0; set per-dim via `mppi_set_sigma`.
fn mppi_new(n_x: i64, n_u: i64, T: i64, K: i64, lambda_b: i64, seed: i64) -> i64 {
    return nuc_mppi_new(n_x, n_u, T, K, lambda_b, seed);
}

fn mppi_set_callbacks(h: i64, dyn_fp: i64, sc_fp: i64, tc_fp: i64) {
    nuc_mppi_set_callbacks(h, dyn_fp, sc_fp, tc_fp);
}

// Per-dim sample noise std-dev (default 1.0). Should be comparable
// to the expected control magnitude for that dim.
fn mppi_set_sigma(h: i64, dim: i64, sigma_b: i64) {
    nuc_mppi_set_sigma(h, dim, sigma_b);
}

// Optionally seed the warm-start nominal sequence
// (default all zeros).
fn mppi_warm_start(h: i64, u_seq_ptr: i64) {
    nuc_mppi_warm_start(h, u_seq_ptr);
}

// Reset nominal sequence to zeros.
fn mppi_reset(h: i64) { nuc_mppi_reset(h); }

// One tick. Reads x from `x_ptr` (double[n_x]); writes the immediate
// control to `u_out_ptr` (double[n_u]); shifts the internal nominal
// sequence by one step. Returns 0 on success.
fn mppi_step(h: i64, x_ptr: i64, u_out_ptr: i64) -> i64 {
    return nuc_mppi_step(h, x_ptr, u_out_ptr);
}

// Read the current nominal control at horizon step t (after the shift).
fn mppi_get_control(h: i64, t: i64, dim: i64) -> i64 {
    return nuc_mppi_get_control(h, t, dim);
}

fn mppi_free(h: i64) { nuc_mppi_free(h); }
