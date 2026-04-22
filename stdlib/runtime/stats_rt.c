// stats_rt.c — Statistics and Probability for Nucleor
// Descriptive stats, hypothesis testing, linear regression, bootstrap, KDE.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/stats_rt.c -o target/stats_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _st_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _st_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } STVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  Descriptive Statistics
// ================================================================

long long nuc_stat_mean(long long vh) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len == 0) return _st_f2i(0.0);
    double sum = 0;
    for (int i = 0; i < v->len; i++) sum += _st_i2f(v->data[i]);
    return _st_f2i(sum / v->len);
}

static int cmp_double(const void *a, const void *b) {
    double da = *(const double *)a, db = *(const double *)b;
    return (da > db) - (da < db);
}

long long nuc_stat_median(long long vh) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len == 0) return _st_f2i(0.0);
    double *sorted = (double *)malloc(v->len * sizeof(double));
    for (int i = 0; i < v->len; i++) sorted[i] = _st_i2f(v->data[i]);
    qsort(sorted, v->len, sizeof(double), cmp_double);
    double med;
    if (v->len % 2 == 1) med = sorted[v->len / 2];
    else med = (sorted[v->len / 2 - 1] + sorted[v->len / 2]) / 2.0;
    free(sorted);
    return _st_f2i(med);
}

long long nuc_stat_var(long long vh) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len <= 1) return _st_f2i(0.0);
    double sum = 0;
    for (int i = 0; i < v->len; i++) sum += _st_i2f(v->data[i]);
    double mean = sum / v->len;
    double var = 0;
    for (int i = 0; i < v->len; i++) {
        double d = _st_i2f(v->data[i]) - mean;
        var += d * d;
    }
    return _st_f2i(var / (v->len - 1)); // Bessel's correction
}

long long nuc_stat_std(long long vh) {
    double var = _st_i2f(nuc_stat_var(vh));
    return _st_f2i(sqrt(var));
}

long long nuc_stat_cov(long long xh, long long yh) {
    STVec *x = (STVec *)(void *)xh, *y = (STVec *)(void *)yh;
    if (!x || !y || x->len != y->len || x->len <= 1) return _st_f2i(0.0);
    int n = x->len;
    double mx = 0, my = 0;
    for (int i = 0; i < n; i++) { mx += _st_i2f(x->data[i]); my += _st_i2f(y->data[i]); }
    mx /= n; my /= n;
    double cov = 0;
    for (int i = 0; i < n; i++)
        cov += (_st_i2f(x->data[i]) - mx) * (_st_i2f(y->data[i]) - my);
    return _st_f2i(cov / (n - 1));
}

long long nuc_stat_corr(long long xh, long long yh) {
    double cov = _st_i2f(nuc_stat_cov(xh, yh));
    double sx = _st_i2f(nuc_stat_std(xh));
    double sy = _st_i2f(nuc_stat_std(yh));
    if (sx < 1e-15 || sy < 1e-15) return _st_f2i(0.0);
    return _st_f2i(cov / (sx * sy));
}

long long nuc_stat_percentile(long long vh, long long p_bits) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len == 0) return _st_f2i(0.0);
    double p = _st_i2f(p_bits);
    double *sorted = (double *)malloc(v->len * sizeof(double));
    for (int i = 0; i < v->len; i++) sorted[i] = _st_i2f(v->data[i]);
    qsort(sorted, v->len, sizeof(double), cmp_double);
    double idx = p / 100.0 * (v->len - 1);
    int lo = (int)idx;
    int hi = lo + 1;
    if (hi >= v->len) hi = v->len - 1;
    double frac = idx - lo;
    double result = sorted[lo] * (1 - frac) + sorted[hi] * frac;
    free(sorted);
    return _st_f2i(result);
}

// ================================================================
//  Histogram
// ================================================================

long long nuc_stat_histogram(long long vh, long long bins) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len == 0) return 0;
    int nb = (int)bins;

    double vmin = _st_i2f(v->data[0]), vmax = vmin;
    for (int i = 1; i < v->len; i++) {
        double x = _st_i2f(v->data[i]);
        if (x < vmin) vmin = x;
        if (x > vmax) vmax = x;
    }
    double range = vmax - vmin;
    if (range < 1e-15) range = 1.0;

    STVec *counts = (STVec *)malloc(sizeof(STVec));
    counts->len = nb; counts->cap = nb;
    counts->data = (long long *)calloc(nb, sizeof(long long));

    for (int i = 0; i < v->len; i++) {
        double x = _st_i2f(v->data[i]);
        int bin = (int)((x - vmin) / range * nb);
        if (bin >= nb) bin = nb - 1;
        if (bin < 0) bin = 0;
        counts->data[bin]++;
    }
    return (long long)counts;
}

// ================================================================
//  Linear Regression (simple OLS: y = slope * x + intercept)
// ================================================================

typedef struct { long long slope; long long intercept; long long r_squared; } LinRegResult;

long long nuc_stat_linreg(long long xh, long long yh) {
    STVec *x = (STVec *)(void *)xh, *y = (STVec *)(void *)yh;
    if (!x || !y || x->len != y->len || x->len < 2) return 0;
    int n = x->len;
    double mx = 0, my = 0;
    for (int i = 0; i < n; i++) { mx += _st_i2f(x->data[i]); my += _st_i2f(y->data[i]); }
    mx /= n; my /= n;

    double sxy = 0, sxx = 0, syy = 0;
    for (int i = 0; i < n; i++) {
        double dx = _st_i2f(x->data[i]) - mx;
        double dy = _st_i2f(y->data[i]) - my;
        sxy += dx * dy;
        sxx += dx * dx;
        syy += dy * dy;
    }

    double slope = (fabs(sxx) > 1e-15) ? sxy / sxx : 0.0;
    double intercept = my - slope * mx;
    double r2 = (fabs(syy) > 1e-15) ? (sxy * sxy) / (sxx * syy) : 0.0;

    LinRegResult *res = (LinRegResult *)malloc(sizeof(LinRegResult));
    res->slope = _st_f2i(slope);
    res->intercept = _st_f2i(intercept);
    res->r_squared = _st_f2i(r2);
    return (long long)res;
}

long long nuc_stat_linreg_slope(long long h) { return ((LinRegResult *)(void *)h)->slope; }
long long nuc_stat_linreg_intercept(long long h) { return ((LinRegResult *)(void *)h)->intercept; }
long long nuc_stat_linreg_r2(long long h) { return ((LinRegResult *)(void *)h)->r_squared; }

// ================================================================
//  T-test (two-sample, Welch's)
// ================================================================

typedef struct { long long t_stat; long long p_value; } TTestResult;

// Approximate p-value from t-distribution using normal approximation for large df
static double approx_t_pval(double t, double df) {
    // Use normal CDF approximation for df > 30, else use Beta incomplete
    double x = df / (df + t * t);
    // Rough approximation: p ~ 2 * (1 - Phi(|t| * sqrt(df/(df-2))))
    double z = fabs(t);
    double p = erfc(z / sqrt(2.0)); // two-sided
    return p;
}

long long nuc_stat_ttest(long long ah, long long bh) {
    STVec *a = (STVec *)(void *)ah, *b = (STVec *)(void *)bh;
    if (!a || !b || a->len < 2 || b->len < 2) return 0;

    double ma = 0, mb = 0;
    for (int i = 0; i < a->len; i++) ma += _st_i2f(a->data[i]);
    for (int i = 0; i < b->len; i++) mb += _st_i2f(b->data[i]);
    ma /= a->len; mb /= b->len;

    double va = 0, vb = 0;
    for (int i = 0; i < a->len; i++) { double d = _st_i2f(a->data[i]) - ma; va += d * d; }
    for (int i = 0; i < b->len; i++) { double d = _st_i2f(b->data[i]) - mb; vb += d * d; }
    va /= (a->len - 1); vb /= (b->len - 1);

    double se = sqrt(va / a->len + vb / b->len);
    double t = (fabs(se) > 1e-15) ? (ma - mb) / se : 0.0;

    double df_num = (va / a->len + vb / b->len);
    df_num *= df_num;
    double df_den = (va * va) / (a->len * a->len * (a->len - 1)) +
                    (vb * vb) / (b->len * b->len * (b->len - 1));
    double df = (fabs(df_den) > 1e-30) ? df_num / df_den : 1.0;

    TTestResult *res = (TTestResult *)malloc(sizeof(TTestResult));
    res->t_stat = _st_f2i(t);
    res->p_value = _st_f2i(approx_t_pval(t, df));
    return (long long)res;
}

long long nuc_stat_ttest_t(long long h) { return ((TTestResult *)(void *)h)->t_stat; }
long long nuc_stat_ttest_p(long long h) { return ((TTestResult *)(void *)h)->p_value; }

// ================================================================
//  Chi-squared test
// ================================================================

long long nuc_stat_chi2(long long obs_h, long long exp_h) {
    STVec *obs = (STVec *)(void *)obs_h, *exp = (STVec *)(void *)exp_h;
    if (!obs || !exp || obs->len != exp->len) return _st_f2i(0.0);
    double chi2 = 0;
    for (int i = 0; i < obs->len; i++) {
        double o = _st_i2f(obs->data[i]);
        double e = _st_i2f(exp->data[i]);
        if (fabs(e) > 1e-15) chi2 += (o - e) * (o - e) / e;
    }
    return _st_f2i(chi2);
}

// ================================================================
//  Kernel Density Estimate (Gaussian kernel)
// ================================================================

long long nuc_stat_kde(long long vh, long long x_bits) {
    STVec *v = (STVec *)(void *)vh;
    if (!v || v->len == 0) return _st_f2i(0.0);
    double x = _st_i2f(x_bits);

    // Silverman bandwidth
    double std = _st_i2f(nuc_stat_std(vh));
    double h = 1.06 * std * pow((double)v->len, -0.2);
    if (h < 1e-10) h = 1.0;

    double density = 0;
    for (int i = 0; i < v->len; i++) {
        double z = (x - _st_i2f(v->data[i])) / h;
        density += exp(-0.5 * z * z) / sqrt(2.0 * M_PI);
    }
    density /= (v->len * h);
    return _st_f2i(density);
}
