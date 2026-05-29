// rods/pf — Particle filter (sequential Monte Carlo) for nonlinear,
// non-Gaussian state estimation.
//
// Represents the posterior `p(x | z_1:t)` by a swarm of weighted
// particles. At each step: predict via dynamics, weight via the
// user's likelihood, resample when effective N drops below a
// threshold.
//
// Foundation for:
// - Kidnapped-robot localization (multi-modal posterior over the
//   entire map until enough observations narrow it down).
// - Multi-target tracking with data association ambiguity.
// - Strongly nonlinear tracking where EKF / UKF fail.
// - Bayesian filtering on non-vector state spaces (orientation
//   manifolds, Lie groups) — particles can be any state type.
//
// Workflow:
//   let pf = pf_new(n_x, n_z, n_particles, seed);
//   pf_init_uniform(pf, lo_ptr, hi_ptr);   // OR pf_set_initial(...)
//
//   // At each control step:
//   pf_predict(pf, u_ptr, dynamics_fp, noise_std_ptr);
//   pf_update(pf, z_ptr, likelihood_fp, eff_threshold_b);
//   pf_get_mean(pf, x_out_ptr);   // or pf_get_particle for individual draws
//
// Callbacks:
//   dynamics_fp:    fn(x_ptr, u_ptr, x_next_ptr) -> i64
//   likelihood_fp:  fn(x_ptr, z_ptr) -> i64 (bit-cast f64 likelihood ≥ 0)
//
// Limitations (Rao-Blackwellized PF, auxiliary-variable PF,
// adaptive particle count land in v0.6 if needed):
// - Systematic resampling only.
// - Caller supplies process noise as a diagonal stddev vector
//   (Gaussian assumption); for arbitrary noise, sample within the
//   user's dynamics callback.
//
// See `stdlib/runtime/pf_rt.c`.
#cfile "../runtime/pf_rt.c"

extern fn nuc_pf_new(n_x: i64, n_z: i64, n_particles: i64, seed: i64) -> i64;
extern fn nuc_pf_set_initial(h: i64, x_array_ptr: i64);
extern fn nuc_pf_init_uniform(h: i64, lo_ptr: i64, hi_ptr: i64) -> i64;
extern fn nuc_pf_predict(h: i64, u_ptr: i64,
    dynamics_fp: i64, noise_std_ptr: i64) -> i64;
extern fn nuc_pf_update(h: i64, z_ptr: i64,
    likelihood_fp: i64, eff_threshold_b: i64) -> i64;
extern fn nuc_pf_get_mean(h: i64, x_out_ptr: i64);
extern fn nuc_pf_get_particle(h: i64, i: i64, x_out_ptr: i64);
extern fn nuc_pf_particle_count(h: i64) -> i64;
extern fn nuc_pf_free(h: i64);

fn pf_new(n_x: i64, n_z: i64, n_particles: i64, seed: i64) -> i64 {
    return nuc_pf_new(n_x, n_z, n_particles, seed);
}

// Initialize particles from a caller-allocated double[n_particles * n_x]
// array. All weights set to 1/N.
fn pf_set_initial(h: i64, x_array_ptr: i64) {
    nuc_pf_set_initial(h, x_array_ptr);
}

// Initialize particles uniformly in a per-dim box [lo[j], hi[j]].
// `lo_ptr` and `hi_ptr` are double[n_x] arrays. Useful for global
// localization where the prior is uniform over a known region.
fn pf_init_uniform(h: i64, lo_ptr: i64, hi_ptr: i64) -> i64 {
    return nuc_pf_init_uniform(h, lo_ptr, hi_ptr);
}

// Predict step: propagate each particle through f(x, u), then add
// Gaussian noise per the diagonal `noise_std` (n_x doubles). Pass
// 0 to skip noise.
fn pf_predict(h: i64, u_ptr: i64,
    dynamics_fp: i64, noise_std_ptr: i64) -> i64
{
    return nuc_pf_predict(h, u_ptr, dynamics_fp, noise_std_ptr);
}

// Update step: weight particles by the user's likelihood callback,
// renormalize, resample if effective N < eff_threshold · N. Typical
// eff_threshold = 0.5.
fn pf_update(h: i64, z_ptr: i64,
    likelihood_fp: i64, eff_threshold_b: i64) -> i64
{
    return nuc_pf_update(h, z_ptr, likelihood_fp, eff_threshold_b);
}

// Read the weighted-mean state estimate. `x_out_ptr` is double[n_x].
fn pf_get_mean(h: i64, x_out_ptr: i64) { nuc_pf_get_mean(h, x_out_ptr); }
fn pf_get_particle(h: i64, i: i64, x_out_ptr: i64) {
    nuc_pf_get_particle(h, i, x_out_ptr);
}
fn pf_particle_count(h: i64) -> i64 { return nuc_pf_particle_count(h); }
fn pf_free(h: i64) { nuc_pf_free(h); }
