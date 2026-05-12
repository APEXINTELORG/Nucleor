// =====================================================
// rods/bayesian — MCMC Bayesian inference
// =====================================================
// Import: import "stdlib/rods/bayesian.nr"
// Provides: scalar and multivariate Metropolis MCMC over a user-supplied
//   log-posterior, plus credible intervals and chain summaries.
// =====================================================

#cfile "../runtime/bayesian_rt.c"

extern fn nuc_bayes_seed(seed: i64);
// Pre-2026-05-05 the rod externs declared 4 args (`log_post, x0, n_steps,
// step_size`) but the C runtime takes 5: `log_post_ptr, x0_bits,
// proposal_std_bits, n_samples, burnin`. The 4-arg call site read
// `proposal_std_bits` as `n_steps` (integer count reinterpreted as f64-bits)
// and `n_samples` as the f64-bits of step_size — silent-miscompute on every
// MCMC call. Fixed to match the C ABI exactly.
extern fn nuc_bayes_mcmc_scalar(log_post: i64, x0: i64, proposal_std: i64,
    n_samples: i64, burnin: i64) -> i64;
extern fn nuc_bayes_mcmc_multi(log_post: i64, x0: i64, proposal_std: i64,
    n_samples: i64, burnin: i64) -> i64;
extern fn nuc_bayes_credible_interval(samples: i64, level: i64) -> i64;
extern fn nuc_bayes_chain_mean(chain: i64) -> i64;
extern fn nuc_bayes_chain_std(chain: i64) -> i64;
extern fn nuc_bayes_acceptance_rate(chain: i64) -> i64;

fn bayes_seed(seed: i64) { nuc_bayes_seed(seed); }
fn bayes_mcmc_scalar(log_post: i64, x0: i64, proposal_std: i64,
    n_samples: i64, burnin: i64) -> i64
{
    return nuc_bayes_mcmc_scalar(log_post, x0, proposal_std, n_samples, burnin);
}
fn bayes_mcmc_multi(log_post: i64, x0: i64, proposal_std: i64,
    n_samples: i64, burnin: i64) -> i64
{
    return nuc_bayes_mcmc_multi(log_post, x0, proposal_std, n_samples, burnin);
}
fn bayes_ci(samples: i64, level: i64) -> i64 { return nuc_bayes_credible_interval(samples, level); }
fn bayes_mean(chain: i64) -> i64 { return nuc_bayes_chain_mean(chain); }
fn bayes_std(chain: i64) -> i64 { return nuc_bayes_chain_std(chain); }
fn bayes_acceptance(chain: i64) -> i64 { return nuc_bayes_acceptance_rate(chain); }
