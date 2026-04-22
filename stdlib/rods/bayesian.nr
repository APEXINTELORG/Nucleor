// =====================================================
// rods/bayesian — MCMC Bayesian inference
// =====================================================
// Import: import "stdlib/rods/bayesian.nr"
// Provides: scalar and multivariate Metropolis MCMC over a user-supplied
//   log-posterior, plus credible intervals and chain summaries.
// =====================================================

#cfile "../runtime/bayesian_rt.c"

extern fn nuc_bayes_seed(seed: i64);
extern fn nuc_bayes_mcmc_scalar(log_post: i64, x0: i64, n_steps: i64, step_size: i64) -> i64;
extern fn nuc_bayes_mcmc_multi(log_post: i64, x0: i64, n_steps: i64, step_size: i64) -> i64;
extern fn nuc_bayes_credible_interval(samples: i64, level: i64) -> i64;
extern fn nuc_bayes_chain_mean(chain: i64) -> i64;
extern fn nuc_bayes_chain_std(chain: i64) -> i64;
extern fn nuc_bayes_acceptance_rate(chain: i64) -> i64;

fn bayes_seed(seed: i64) { nuc_bayes_seed(seed); }
fn bayes_mcmc_scalar(log_post: i64, x0: i64, n_steps: i64, step: i64) -> i64 {
    return nuc_bayes_mcmc_scalar(log_post, x0, n_steps, step);
}
fn bayes_mcmc_multi(log_post: i64, x0: i64, n_steps: i64, step: i64) -> i64 {
    return nuc_bayes_mcmc_multi(log_post, x0, n_steps, step);
}
fn bayes_ci(samples: i64, level: i64) -> i64 { return nuc_bayes_credible_interval(samples, level); }
fn bayes_mean(chain: i64) -> i64 { return nuc_bayes_chain_mean(chain); }
fn bayes_std(chain: i64) -> i64 { return nuc_bayes_chain_std(chain); }
fn bayes_acceptance(chain: i64) -> i64 { return nuc_bayes_acceptance_rate(chain); }
