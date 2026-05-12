// bayesian_rt.c — Bayesian Inference for Nucleor
// MCMC Metropolis-Hastings, credible intervals, prior/posterior sampling.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/bayesian_rt.c -o target/bayesian_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _by_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _by_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } BYVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Simple RNG for MCMC (separate from rng_rt.c)
static unsigned long long by_rng = 0x12345678DEADBEEF;
static double by_uniform(void) {
    by_rng ^= by_rng << 13; by_rng ^= by_rng >> 7; by_rng ^= by_rng << 17;
    return (double)(by_rng & 0xFFFFFFFFFFFFF) / (double)0xFFFFFFFFFFFFF;
}
static double by_normal(void) {
    double u1 = by_uniform(), u2 = by_uniform();
    if (u1 < 1e-15) u1 = 1e-15;
    return sqrt(-2 * log(u1)) * cos(2 * M_PI * u2);
}

void nuc_bayes_seed(long long seed) {
    by_rng = (unsigned long long)seed;
    if (by_rng == 0) by_rng = 1;
}

// ================================================================
//  MCMC Metropolis-Hastings (scalar)
//  log_posterior: fn(x) -> log p(x|data) (up to constant)
//  Returns chain as Vec<f64>
// ================================================================

long long nuc_bayes_mcmc_scalar(long long log_post_ptr, long long x0_bits,
                                 long long proposal_std_bits, long long n_samples, long long burnin) {
    typedef long long (*LogPostFn)(long long);
    LogPostFn lp = (LogPostFn)(void *)log_post_ptr;
    double x = _by_i2f(x0_bits);
    double sigma = _by_i2f(proposal_std_bits);
    int ns = (int)n_samples, nb = (int)burnin;

    BYVec *chain = (BYVec *)malloc(sizeof(BYVec));
    chain->len = 0; chain->cap = ns;
    chain->data = (long long *)malloc(ns * sizeof(long long));

    double lp_x = _by_i2f(lp(_by_f2i(x)));

    for (int i = 0; i < ns + nb; i++) {
        double x_prop = x + sigma * by_normal();
        double lp_prop = _by_i2f(lp(_by_f2i(x_prop)));
        double log_alpha = lp_prop - lp_x;

        if (log_alpha >= 0 || log(by_uniform()) < log_alpha) {
            x = x_prop;
            lp_x = lp_prop;
        }

        if (i >= nb) chain->data[chain->len++] = _by_f2i(x);
    }
    return (long long)chain;
}

// ================================================================
//  MCMC Metropolis-Hastings (multivariate)
//  log_posterior: fn(Vec<f64>) -> f64
// ================================================================

long long nuc_bayes_mcmc_multi(long long log_post_ptr, long long x0_h,
                                long long proposal_std_bits, long long n_samples, long long burnin) {
    typedef long long (*LogPostFn)(long long);
    LogPostFn lp = (LogPostFn)(void *)log_post_ptr;
    BYVec *x0 = (BYVec *)(void *)x0_h;
    double sigma = _by_i2f(proposal_std_bits);
    int ns = (int)n_samples, nb = (int)burnin, dim = x0->len;

    double *x = (double *)malloc(dim * sizeof(double));
    for (int i = 0; i < dim; i++) x[i] = _by_i2f(x0->data[i]);

    BYVec *xvec = (BYVec *)malloc(sizeof(BYVec));
    xvec->len = dim; xvec->cap = dim;
    xvec->data = (long long *)malloc(dim * sizeof(long long));
    for (int i = 0; i < dim; i++) xvec->data[i] = _by_f2i(x[i]);
    double lp_x = _by_i2f(lp((long long)xvec));

    // Output: flat [n_samples * dim]
    BYVec *chain = (BYVec *)malloc(sizeof(BYVec));
    chain->len = 0; chain->cap = ns * dim;
    chain->data = (long long *)malloc((size_t)ns * dim * sizeof(long long));

    double *x_prop = (double *)malloc(dim * sizeof(double));
    for (int i = 0; i < ns + nb; i++) {
        for (int d = 0; d < dim; d++) x_prop[d] = x[d] + sigma * by_normal();
        for (int d = 0; d < dim; d++) xvec->data[d] = _by_f2i(x_prop[d]);
        double lp_prop = _by_i2f(lp((long long)xvec));
        double log_alpha = lp_prop - lp_x;

        if (log_alpha >= 0 || log(by_uniform()) < log_alpha) {
            for (int d = 0; d < dim; d++) x[d] = x_prop[d];
            lp_x = lp_prop;
        }

        if (i >= nb) {
            for (int d = 0; d < dim; d++) chain->data[chain->len++] = _by_f2i(x[d]);
        }
    }
    free(x); free(x_prop);
    return (long long)chain;
}

// ================================================================
//  Credible Interval from samples
// ================================================================

long long nuc_bayes_credible_interval(long long samples_h, long long level_bits) {
    BYVec *samp = (BYVec *)(void *)samples_h;
    double level = _by_i2f(level_bits); // e.g. 0.95
    int n = samp->len;

    // Sort
    double *sorted = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) sorted[i] = _by_i2f(samp->data[i]);
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (sorted[j] < sorted[i]) { double t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }

    double alpha = (1 - level) / 2;
    int lo_idx = (int)(alpha * n);
    int hi_idx = (int)((1 - alpha) * n);
    if (lo_idx < 0) lo_idx = 0;
    if (hi_idx >= n) hi_idx = n - 1;

    BYVec *result = (BYVec *)malloc(sizeof(BYVec));
    result->len = 2; result->cap = 2;
    result->data = (long long *)malloc(2 * sizeof(long long));
    result->data[0] = _by_f2i(sorted[lo_idx]);
    result->data[1] = _by_f2i(sorted[hi_idx]);
    free(sorted);
    return (long long)result;
}

// ================================================================
//  Sample mean and standard deviation from chain
// ================================================================

long long nuc_bayes_chain_mean(long long chain_h) {
    BYVec *ch = (BYVec *)(void *)chain_h;
    double sum = 0;
    for (int i = 0; i < ch->len; i++) sum += _by_i2f(ch->data[i]);
    return _by_f2i(sum / ch->len);
}

long long nuc_bayes_chain_std(long long chain_h) {
    BYVec *ch = (BYVec *)(void *)chain_h;
    double sum = 0, sum2 = 0;
    for (int i = 0; i < ch->len; i++) {
        double x = _by_i2f(ch->data[i]);
        sum += x; sum2 += x * x;
    }
    double mean = sum / ch->len;
    double var = sum2 / ch->len - mean * mean;
    return _by_f2i(sqrt(var > 0 ? var : 0));
}

// ================================================================
//  Acceptance rate diagnostic
// ================================================================

long long nuc_bayes_acceptance_rate(long long chain_h) {
    BYVec *ch = (BYVec *)(void *)chain_h;
    int changes = 0;
    for (int i = 1; i < ch->len; i++) {
        if (ch->data[i] != ch->data[i - 1]) changes++;
    }
    return _by_f2i((double)changes / (ch->len - 1));
}
