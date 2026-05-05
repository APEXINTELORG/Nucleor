// v0.8.255 stdlib/rods/bayesian.nr first test coverage + arity FIX.
//
// MCMC Bayesian inference. Pre-v0.8.255: zero coverage AND broken ABI.
//
// **Drift fix.** Pre-v0.8.255 the rod declared 4-arg
// `bayes_mcmc_scalar(log_post, x0, n_steps, step_size)` but the C
// runtime took 5: `(log_post, x0, proposal_std, n_samples, burnin)`.
// The mismatch was doubly broken — even the matching-arity slots
// disagreed on meaning (rod's `n_steps` integer was read as C's
// `proposal_std_bits` f64; rod's `step_size` f64-bits was read as
// C's `n_samples` integer). Every MCMC call silently miscomputed.
// Same bug class as v0.8.45 ML-1, v0.8.252 kv_cache, v0.8.254
// transformer. Surfaced by parallel-agent TRACK A
// `extern_arity_drift_bayesian_2026-05-05`.
//
// Fix: rod ABI corrected to match C exactly — 5-arg
// `(log_post, x0, proposal_std, n_samples, burnin)`. NOT a
// non-breaking shim because the old rod API was producing garbage
// anyway; no real adopter could be using it correctly. No external
// callers existed in-tree.
//
// Locks four chain-statistic invariants (the MCMC integrator path
// itself requires a function-pointer log-posterior, deferred to
// follow-up coverage):
//
//   1. **Lifecycle** — `bayes_seed(42)` does not crash.
//   2. **chain_mean** — mean of [1,2,3,4] = 2.5.
//   3. **chain_std** — population std of [1,2,3,4] ≈ sqrt(1.25) ≈ 1.1180.
//   4. **acceptance_rate** — all-distinct chain → 1.0; all-equal chain → 0.0.
//
// Expected: rc=0.

import "stdlib/rods/bayesian.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_chain_distinct() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(4.0));
    return v;
}

fn make_chain_constant() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(7.0));
    v.push(f64_to_bits(7.0));
    v.push(f64_to_bits(7.0));
    v.push(f64_to_bits(7.0));
    return v;
}

fn check_seed_lifecycle() -> i64 {
    bayes_seed(42);
    bayes_seed(0);
    bayes_seed(0 - 1);
    return 0;
}

fn check_chain_mean() -> i64 {
    let ch: Vec<i64> = make_chain_distinct();
    let m: i64 = bayes_mean(ch);
    if close(m, f64_to_bits(2.5), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_chain_std() -> i64 {
    let ch: Vec<i64> = make_chain_distinct();
    let s: i64 = bayes_std(ch);
    // population std of [1,2,3,4] = sqrt((1+4+9+16)/4 - (10/4)^2) = sqrt(7.5 - 6.25) = sqrt(1.25)
    if close(s, f64_to_bits(1.1180339887498949), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_acceptance_rate() -> i64 {
    let ch_distinct: Vec<i64> = make_chain_distinct();
    let r1: i64 = bayes_acceptance(ch_distinct);
    if close(r1, f64_to_bits(1.0), 1e-9) != 1 { return 4; };
    let ch_const: Vec<i64> = make_chain_constant();
    let r0: i64 = bayes_acceptance(ch_const);
    if close(r0, f64_to_bits(0.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_seed_lifecycle();
    fails = fails + check_chain_mean();
    fails = fails + check_chain_std();
    fails = fails + check_acceptance_rate();
    return fails;
}
