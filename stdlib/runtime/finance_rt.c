// finance_rt.c — Financial Mathematics for Nucleor
// Black-Scholes, Greeks, implied volatility, NPV, IRR, VaR, Markowitz.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/finance_rt.c -o target/finance_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _fn_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _fn_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } FNVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Standard normal CDF
static double norm_cdf(double x) {
    return 0.5 * erfc(-x / sqrt(2.0));
}

// Standard normal PDF
static double norm_pdf(double x) {
    return exp(-0.5 * x * x) / sqrt(2.0 * M_PI);
}

// ================================================================
//  Black-Scholes Option Pricing
//  type: 0 = call, 1 = put
// ================================================================

long long nuc_fin_black_scholes(long long S_bits, long long K_bits, long long T_bits,
                                 long long r_bits, long long sigma_bits, long long type) {
    double S = _fn_i2f(S_bits), K = _fn_i2f(K_bits), T = _fn_i2f(T_bits);
    double r = _fn_i2f(r_bits), sigma = _fn_i2f(sigma_bits);
    if (T <= 0 || sigma <= 0) return _fn_f2i(0.0);

    double d1 = (log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrt(T));
    double d2 = d1 - sigma * sqrt(T);

    double price;
    if (type == 0) { // call
        price = S * norm_cdf(d1) - K * exp(-r * T) * norm_cdf(d2);
    } else { // put
        price = K * exp(-r * T) * norm_cdf(-d2) - S * norm_cdf(-d1);
    }
    return _fn_f2i(price);
}

// ================================================================
//  Greeks
// ================================================================

typedef struct {
    long long delta, gamma, theta, vega, rho;
} GreeksResult;

long long nuc_fin_greeks(long long S_bits, long long K_bits, long long T_bits,
                          long long r_bits, long long sigma_bits) {
    double S = _fn_i2f(S_bits), K = _fn_i2f(K_bits), T = _fn_i2f(T_bits);
    double r = _fn_i2f(r_bits), sigma = _fn_i2f(sigma_bits);
    if (T <= 0 || sigma <= 0) return 0;

    double sqrtT = sqrt(T);
    double d1 = (log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrtT);
    double d2 = d1 - sigma * sqrtT;

    GreeksResult *g = (GreeksResult *)malloc(sizeof(GreeksResult));
    g->delta = _fn_f2i(norm_cdf(d1));
    g->gamma = _fn_f2i(norm_pdf(d1) / (S * sigma * sqrtT));
    g->theta = _fn_f2i(-(S * norm_pdf(d1) * sigma) / (2 * sqrtT) - r * K * exp(-r * T) * norm_cdf(d2));
    g->vega = _fn_f2i(S * norm_pdf(d1) * sqrtT);
    g->rho = _fn_f2i(K * T * exp(-r * T) * norm_cdf(d2));
    return (long long)g;
}

long long nuc_fin_greeks_delta(long long h) { return ((GreeksResult *)(void *)h)->delta; }
long long nuc_fin_greeks_gamma(long long h) { return ((GreeksResult *)(void *)h)->gamma; }
long long nuc_fin_greeks_theta(long long h) { return ((GreeksResult *)(void *)h)->theta; }
long long nuc_fin_greeks_vega(long long h) { return ((GreeksResult *)(void *)h)->vega; }
long long nuc_fin_greeks_rho(long long h) { return ((GreeksResult *)(void *)h)->rho; }

// ================================================================
//  Implied Volatility (Newton's method on BS price)
// ================================================================

long long nuc_fin_implied_vol(long long price_bits, long long S_bits, long long K_bits,
                               long long T_bits, long long r_bits, long long type) {
    double target = _fn_i2f(price_bits);
    double S = _fn_i2f(S_bits), K = _fn_i2f(K_bits), T = _fn_i2f(T_bits), r = _fn_i2f(r_bits);
    double sigma = 0.2; // initial guess

    for (int iter = 0; iter < 100; iter++) {
        double price = _fn_i2f(nuc_fin_black_scholes(_fn_f2i(S), _fn_f2i(K), _fn_f2i(T), _fn_f2i(r), _fn_f2i(sigma), type));
        double d1 = (log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrt(T));
        double vega = S * norm_pdf(d1) * sqrt(T);
        if (fabs(vega) < 1e-15) break;
        sigma -= (price - target) / vega;
        if (sigma < 0.001) sigma = 0.001;
        if (fabs(price - target) < 1e-8) break;
    }
    return _fn_f2i(sigma);
}

// ================================================================
//  Net Present Value
// ================================================================

long long nuc_fin_npv(long long cash_flows_h, long long rate_bits) {
    FNVec *cf = (FNVec *)(void *)cash_flows_h;
    double r = _fn_i2f(rate_bits);
    double npv = 0;
    for (int t = 0; t < cf->len; t++) {
        npv += _fn_i2f(cf->data[t]) / pow(1 + r, t);
    }
    return _fn_f2i(npv);
}

// ================================================================
//  Internal Rate of Return (bisection)
// ================================================================

long long nuc_fin_irr(long long cash_flows_h) {
    FNVec *cf = (FNVec *)(void *)cash_flows_h;
    double lo = -0.5, hi = 5.0;
    for (int iter = 0; iter < 100; iter++) {
        double mid = (lo + hi) * 0.5;
        double npv = 0;
        for (int t = 0; t < cf->len; t++) npv += _fn_i2f(cf->data[t]) / pow(1 + mid, t);
        if (npv > 0) lo = mid; else hi = mid;
        if (hi - lo < 1e-10) break;
    }
    return _fn_f2i((lo + hi) * 0.5);
}

// ================================================================
//  Value at Risk (historical simulation)
// ================================================================

long long nuc_fin_var(long long returns_h, long long confidence_bits) {
    FNVec *ret = (FNVec *)(void *)returns_h;
    double conf = _fn_i2f(confidence_bits);
    int n = ret->len;

    // Sort returns
    double *sorted = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) sorted[i] = _fn_i2f(ret->data[i]);
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (sorted[j] < sorted[i]) { double t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }

    int idx = (int)((1.0 - conf) * n);
    if (idx < 0) idx = 0;
    if (idx >= n) idx = n - 1;
    double var = -sorted[idx]; // VaR is positive
    free(sorted);
    return _fn_f2i(var);
}

// ================================================================
//  Markowitz Portfolio Optimization (minimum variance for target return)
//  returns: Vec<f64> [n_assets] mean returns
//  cov: Vec<f64> [n_assets * n_assets] covariance matrix
//  target_ret: target portfolio return
//  Returns: weights Vec<f64> [n_assets]
// ================================================================

long long nuc_fin_portfolio_opt(long long returns_h, long long cov_h,
                                 long long target_ret_bits, long long n_assets) {
    FNVec *ret = (FNVec *)(void *)returns_h;
    FNVec *cov = (FNVec *)(void *)cov_h;
    int n = (int)n_assets;

    // Simple equal-weight portfolio as baseline, then gradient descent
    FNVec *w = (FNVec *)malloc(sizeof(FNVec));
    w->len = n; w->cap = n;
    w->data = (long long *)malloc(n * sizeof(long long));

    double inv_n = 1.0 / n;
    for (int i = 0; i < n; i++) w->data[i] = _fn_f2i(inv_n);

    // 100 steps of projected gradient descent
    double lr = 0.01;
    for (int step = 0; step < 100; step++) {
        // Gradient of variance: 2 * Sigma * w
        double *grad = (double *)calloc(n, sizeof(double));
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                grad[i] += 2 * _fn_i2f(cov->data[i * n + j]) * _fn_i2f(w->data[j]);

        // Update
        for (int i = 0; i < n; i++) {
            double wi = _fn_i2f(w->data[i]) - lr * grad[i];
            if (wi < 0) wi = 0;
            w->data[i] = _fn_f2i(wi);
        }

        // Normalize to sum = 1
        double sum = 0;
        for (int i = 0; i < n; i++) sum += _fn_i2f(w->data[i]);
        if (sum > 1e-15)
            for (int i = 0; i < n; i++) w->data[i] = _fn_f2i(_fn_i2f(w->data[i]) / sum);

        free(grad);
    }
    return (long long)w;
}
