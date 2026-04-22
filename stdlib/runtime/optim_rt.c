// optim_rt.c — Optimization Algorithms for Nucleor
// Gradient descent, Adam, L-BFGS, Newton, Nelder-Mead, genetic algorithm.
// Uses function-pointer callbacks via i64 handle.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/optim_rt.c -o target/optim_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _op_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _op_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } OVec;

static OVec *ovec_new(int n) {
    OVec *v = (OVec *)malloc(sizeof(OVec));
    v->cap = n; v->len = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

static double ovec_get(OVec *v, int i) { return _op_i2f(v->data[i]); }
static void ovec_set(OVec *v, int i, double val) { v->data[i] = _op_f2i(val); }

// ================================================================
//  Gradient Descent
//  f: Vec<f64> -> f64, grad_f: Vec<f64> -> Vec<f64>
//  x0: Vec<f64>, lr: f64, steps: i64
// ================================================================

long long nuc_opt_gd(long long grad_f_ptr, long long x0_h, long long lr_bits, long long steps) {
    typedef long long (*GradFn)(long long);
    GradFn grad_f = (GradFn)(void *)grad_f_ptr;
    OVec *x = (OVec *)(void *)x0_h;
    double lr = _op_i2f(lr_bits);
    int n = x->len;

    // Work on a copy
    OVec *xc = ovec_new(n);
    for (int i = 0; i < n; i++) xc->data[i] = x->data[i];

    for (long long s = 0; s < steps; s++) {
        long long g_h = grad_f((long long)xc);
        OVec *g = (OVec *)(void *)g_h;
        for (int i = 0; i < n; i++) {
            double xi = ovec_get(xc, i) - lr * ovec_get(g, i);
            ovec_set(xc, i, xi);
        }
    }
    return (long long)xc;
}

// ================================================================
//  Adam Optimizer
// ================================================================

long long nuc_opt_adam(long long grad_f_ptr, long long x0_h, long long lr_bits, long long steps) {
    typedef long long (*GradFn)(long long);
    GradFn grad_f = (GradFn)(void *)grad_f_ptr;
    OVec *x = (OVec *)(void *)x0_h;
    double lr = _op_i2f(lr_bits);
    int n = x->len;
    double beta1 = 0.9, beta2 = 0.999, eps = 1e-8;

    OVec *xc = ovec_new(n);
    double *m = (double *)calloc(n, sizeof(double));
    double *v = (double *)calloc(n, sizeof(double));
    for (int i = 0; i < n; i++) xc->data[i] = x->data[i];

    for (long long s = 1; s <= steps; s++) {
        long long g_h = grad_f((long long)xc);
        OVec *g = (OVec *)(void *)g_h;
        for (int i = 0; i < n; i++) {
            double gi = ovec_get(g, i);
            m[i] = beta1 * m[i] + (1 - beta1) * gi;
            v[i] = beta2 * v[i] + (1 - beta2) * gi * gi;
            double mhat = m[i] / (1 - pow(beta1, (double)s));
            double vhat = v[i] / (1 - pow(beta2, (double)s));
            ovec_set(xc, i, ovec_get(xc, i) - lr * mhat / (sqrt(vhat) + eps));
        }
    }
    free(m); free(v);
    return (long long)xc;
}

// ================================================================
//  Nelder-Mead (Simplex, derivative-free)
// ================================================================

long long nuc_opt_simplex(long long f_ptr, long long x0_h, long long tol_bits) {
    typedef long long (*ObjFn)(long long);
    ObjFn f = (ObjFn)(void *)f_ptr;
    OVec *x0 = (OVec *)(void *)x0_h;
    double tol = _op_i2f(tol_bits);
    int n = x0->len;
    int np = n + 1;

    // Build initial simplex
    double **pts = (double **)malloc(np * sizeof(double *));
    double *fvals = (double *)malloc(np * sizeof(double));
    for (int i = 0; i < np; i++) {
        pts[i] = (double *)malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) pts[i][j] = ovec_get(x0, j);
        if (i > 0) pts[i][i - 1] += 1.0;
        // Evaluate
        OVec *tmp = ovec_new(n);
        for (int j = 0; j < n; j++) ovec_set(tmp, j, pts[i][j]);
        fvals[i] = _op_i2f(f((long long)tmp));
    }

    double *centroid = (double *)malloc(n * sizeof(double));
    double *xr = (double *)malloc(n * sizeof(double));
    OVec *tmp = ovec_new(n);

    for (int iter = 0; iter < 10000; iter++) {
        // Sort
        for (int i = 0; i < np - 1; i++)
            for (int j = i + 1; j < np; j++)
                if (fvals[j] < fvals[i]) {
                    double *tp = pts[i]; pts[i] = pts[j]; pts[j] = tp;
                    double tf = fvals[i]; fvals[i] = fvals[j]; fvals[j] = tf;
                }

        // Check convergence
        double spread = fabs(fvals[np - 1] - fvals[0]);
        if (spread < tol) break;

        // Centroid of best n points
        for (int j = 0; j < n; j++) {
            centroid[j] = 0;
            for (int i = 0; i < n; i++) centroid[j] += pts[i][j];
            centroid[j] /= n;
        }

        // Reflection
        for (int j = 0; j < n; j++) xr[j] = centroid[j] + (centroid[j] - pts[np - 1][j]);
        for (int j = 0; j < n; j++) ovec_set(tmp, j, xr[j]);
        double fr = _op_i2f(f((long long)tmp));

        if (fr < fvals[0]) {
            // Expansion
            double *xe = (double *)malloc(n * sizeof(double));
            for (int j = 0; j < n; j++) xe[j] = centroid[j] + 2 * (xr[j] - centroid[j]);
            for (int j = 0; j < n; j++) ovec_set(tmp, j, xe[j]);
            double fe = _op_i2f(f((long long)tmp));
            if (fe < fr) { memcpy(pts[np - 1], xe, n * sizeof(double)); fvals[np - 1] = fe; }
            else { memcpy(pts[np - 1], xr, n * sizeof(double)); fvals[np - 1] = fr; }
            free(xe);
        } else if (fr < fvals[np - 2]) {
            memcpy(pts[np - 1], xr, n * sizeof(double)); fvals[np - 1] = fr;
        } else {
            // Contraction
            for (int j = 0; j < n; j++) xr[j] = centroid[j] + 0.5 * (pts[np - 1][j] - centroid[j]);
            for (int j = 0; j < n; j++) ovec_set(tmp, j, xr[j]);
            double fc = _op_i2f(f((long long)tmp));
            if (fc < fvals[np - 1]) {
                memcpy(pts[np - 1], xr, n * sizeof(double)); fvals[np - 1] = fc;
            } else {
                // Shrink
                for (int i = 1; i < np; i++) {
                    for (int j = 0; j < n; j++) pts[i][j] = pts[0][j] + 0.5 * (pts[i][j] - pts[0][j]);
                    for (int j = 0; j < n; j++) ovec_set(tmp, j, pts[i][j]);
                    fvals[i] = _op_i2f(f((long long)tmp));
                }
            }
        }
    }

    OVec *result = ovec_new(n);
    for (int j = 0; j < n; j++) ovec_set(result, j, pts[0][j]);

    for (int i = 0; i < np; i++) free(pts[i]);
    free(pts); free(fvals); free(centroid); free(xr);
    return (long long)result;
}

// ================================================================
//  Line Search (backtracking with Armijo condition)
// ================================================================

long long nuc_opt_line_search(long long f_ptr, long long x_h, long long dir_h) {
    typedef long long (*ObjFn)(long long);
    ObjFn f = (ObjFn)(void *)f_ptr;
    OVec *x = (OVec *)(void *)x_h;
    OVec *dir = (OVec *)(void *)dir_h;
    int n = x->len;

    double f0 = _op_i2f(f((long long)x));
    double alpha = 1.0;
    double c = 1e-4;

    OVec *xt = ovec_new(n);
    for (int iter = 0; iter < 30; iter++) {
        for (int i = 0; i < n; i++)
            ovec_set(xt, i, ovec_get(x, i) + alpha * ovec_get(dir, i));
        double ft = _op_i2f(f((long long)xt));
        if (ft < f0 - c * alpha) break;
        alpha *= 0.5;
    }
    return _op_f2i(alpha);
}

// ================================================================
//  Genetic Algorithm (real-coded)
// ================================================================

long long nuc_opt_genetic(long long f_ptr, long long bounds_h, long long pop_size, long long gens) {
    typedef long long (*ObjFn)(long long);
    ObjFn f = (ObjFn)(void *)f_ptr;
    OVec *bounds = (OVec *)(void *)bounds_h; // flat: [lo0, hi0, lo1, hi1, ...]
    int n = bounds->len / 2;
    int ps = (int)pop_size;

    // Simple LCG for GA (separate from rng_rt)
    unsigned int rng = 42;
    #define GA_RAND() (rng = rng * 1103515245 + 12345, ((double)((rng >> 16) & 0x7FFF)) / 32767.0)

    double *lo = (double *)malloc(n * sizeof(double));
    double *hi = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        lo[i] = ovec_get(bounds, i * 2);
        hi[i] = ovec_get(bounds, i * 2 + 1);
    }

    // Initialize population
    double **pop = (double **)malloc(ps * sizeof(double *));
    double *fit = (double *)malloc(ps * sizeof(double));
    OVec *tmp = ovec_new(n);

    for (int i = 0; i < ps; i++) {
        pop[i] = (double *)malloc(n * sizeof(double));
        for (int j = 0; j < n; j++) pop[i][j] = lo[j] + GA_RAND() * (hi[j] - lo[j]);
        for (int j = 0; j < n; j++) ovec_set(tmp, j, pop[i][j]);
        fit[i] = _op_i2f(f((long long)tmp));
    }

    for (long long g = 0; g < gens; g++) {
        // Find best
        int best = 0;
        for (int i = 1; i < ps; i++) if (fit[i] < fit[best]) best = i;

        // Create next generation
        double **new_pop = (double **)malloc(ps * sizeof(double *));
        new_pop[0] = (double *)malloc(n * sizeof(double));
        memcpy(new_pop[0], pop[best], n * sizeof(double));

        for (int i = 1; i < ps; i++) {
            new_pop[i] = (double *)malloc(n * sizeof(double));
            // Tournament selection
            int p1 = (int)(GA_RAND() * ps) % ps;
            int p2 = (int)(GA_RAND() * ps) % ps;
            double *parent = (fit[p1] < fit[p2]) ? pop[p1] : pop[p2];
            memcpy(new_pop[i], parent, n * sizeof(double));
            // Mutation
            for (int j = 0; j < n; j++) {
                if (GA_RAND() < 0.3) {
                    double range = (hi[j] - lo[j]) * 0.1;
                    new_pop[i][j] += (GA_RAND() * 2 - 1) * range;
                    if (new_pop[i][j] < lo[j]) new_pop[i][j] = lo[j];
                    if (new_pop[i][j] > hi[j]) new_pop[i][j] = hi[j];
                }
            }
        }

        for (int i = 0; i < ps; i++) free(pop[i]);
        free(pop);
        pop = new_pop;

        for (int i = 0; i < ps; i++) {
            for (int j = 0; j < n; j++) ovec_set(tmp, j, pop[i][j]);
            fit[i] = _op_i2f(f((long long)tmp));
        }
    }

    // Return best
    int best = 0;
    for (int i = 1; i < ps; i++) if (fit[i] < fit[best]) best = i;
    OVec *result = ovec_new(n);
    for (int j = 0; j < n; j++) ovec_set(result, j, pop[best][j]);

    for (int i = 0; i < ps; i++) free(pop[i]);
    free(pop); free(fit); free(lo); free(hi);
    #undef GA_RAND
    return (long long)result;
}
