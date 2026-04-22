// root_rt.c — Root Finding and Nonlinear Equations for Nucleor
// Bisection, Newton, secant, Brent, Newton for systems.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/root_rt.c -o target/root_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _rt_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _rt_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Bisection
// ================================================================

long long nuc_root_bisection(long long f_ptr, long long a_bits, long long b_bits, long long tol_bits) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _rt_i2f(a_bits), b = _rt_i2f(b_bits), tol = _rt_i2f(tol_bits);
    double fa = _rt_i2f(f(_rt_f2i(a)));

    for (int iter = 0; iter < 100; iter++) {
        double mid = (a + b) * 0.5;
        if (b - a < tol) return _rt_f2i(mid);
        double fm = _rt_i2f(f(_rt_f2i(mid)));
        if (fabs(fm) < 1e-15) return _rt_f2i(mid);
        if ((fa > 0) != (fm > 0)) { b = mid; }
        else { a = mid; fa = fm; }
    }
    return _rt_f2i((a + b) * 0.5);
}

// ================================================================
//  Newton's Method (scalar)
// ================================================================

long long nuc_root_newton(long long f_ptr, long long df_ptr, long long x0_bits, long long tol_bits) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    Fn df = (Fn)(void *)df_ptr;
    double x = _rt_i2f(x0_bits), tol = _rt_i2f(tol_bits);

    for (int iter = 0; iter < 100; iter++) {
        double fx = _rt_i2f(f(_rt_f2i(x)));
        if (fabs(fx) < tol) break;
        double dfx = _rt_i2f(df(_rt_f2i(x)));
        if (fabs(dfx) < 1e-30) break;
        x -= fx / dfx;
    }
    return _rt_f2i(x);
}

// ================================================================
//  Secant Method
// ================================================================

long long nuc_root_secant(long long f_ptr, long long x0_bits, long long x1_bits, long long tol_bits) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double x0 = _rt_i2f(x0_bits), x1 = _rt_i2f(x1_bits), tol = _rt_i2f(tol_bits);
    double f0 = _rt_i2f(f(_rt_f2i(x0)));

    for (int iter = 0; iter < 100; iter++) {
        double f1 = _rt_i2f(f(_rt_f2i(x1)));
        if (fabs(f1) < tol) break;
        double denom = f1 - f0;
        if (fabs(denom) < 1e-30) break;
        double x2 = x1 - f1 * (x1 - x0) / denom;
        x0 = x1; f0 = f1; x1 = x2;
    }
    return _rt_f2i(x1);
}

// ================================================================
//  Brent's Method (robust)
// ================================================================

long long nuc_root_brent(long long f_ptr, long long a_bits, long long b_bits, long long tol_bits) {
    typedef long long (*Fn)(long long);
    Fn f = (Fn)(void *)f_ptr;
    double a = _rt_i2f(a_bits), b = _rt_i2f(b_bits), tol = _rt_i2f(tol_bits);
    double fa = _rt_i2f(f(_rt_f2i(a))), fb = _rt_i2f(f(_rt_f2i(b)));

    if (fa * fb > 0) return _rt_f2i(a); // no bracket

    double c = a, fc = fa, d = b - a, e = d;
    if (fabs(fc) < fabs(fb)) {
        a = b; b = c; c = a;
        fa = fb; fb = fc; fc = fa;
    }

    for (int iter = 0; iter < 100; iter++) {
        if (fabs(fb) < tol) return _rt_f2i(b);
        if (fabs(b - c) < tol) return _rt_f2i(b);

        double m = 0.5 * (c - b);
        if (fabs(m) <= tol || fb == 0) return _rt_f2i(b);

        if (fabs(e) >= tol && fabs(fa) > fabs(fb)) {
            // Inverse quadratic interpolation
            double s;
            if (a == c) {
                s = fb / fa;
                double p = 2 * m * s, q = 1 - s;
                if (p > 0) q = -q; else p = -p;
                s = p / q;
            } else {
                double q = fa / fc, r = fb / fc;
                s = fb / fa;
                double p = s * (2 * m * q * (q - r) - (b - a) * (r - 1));
                double qq = (q - 1) * (r - 1) * (s - 1);
                if (p > 0) qq = -qq; else p = -p;
                s = (p < fabs(0.5 * qq * e) && p < fabs(m * qq)) ? p / qq : m;
            }
            e = d; d = s;
        } else {
            d = m; e = m;
        }

        a = b; fa = fb;
        b += (fabs(d) > tol) ? d : ((m > 0) ? tol : -tol);
        fb = _rt_i2f(f(_rt_f2i(b)));

        if ((fb > 0 && fc > 0) || (fb < 0 && fc < 0)) {
            c = a; fc = fa; d = b - a; e = d;
        }
    }
    return _rt_f2i(b);
}

// ================================================================
//  Newton for Systems: F(x) = 0, J is Jacobian
//  F: Vec<f64> -> Vec<f64>, J: Vec<f64> -> flat matrix Vec<f64>
// ================================================================

long long nuc_root_system(long long F_ptr, long long J_ptr, long long x0_h, long long tol_bits) {
    typedef long long (*VecFn)(long long);
    typedef struct { long long *data; int len; int cap; } NVec;
    VecFn F = (VecFn)(void *)F_ptr;
    VecFn J = (VecFn)(void *)J_ptr;
    NVec *x0 = (NVec *)(void *)x0_h;
    double tol = _rt_i2f(tol_bits);
    int n = x0->len;

    NVec *x = (NVec *)malloc(sizeof(NVec));
    x->len = n; x->cap = n;
    x->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++) x->data[i] = x0->data[i];

    for (int iter = 0; iter < 50; iter++) {
        long long Fh = F((long long)x);
        NVec *Fv = (NVec *)(void *)Fh;

        // Check convergence
        double norm = 0;
        for (int i = 0; i < n; i++) { double fi = _rt_i2f(Fv->data[i]); norm += fi * fi; }
        if (sqrt(norm) < tol) break;

        // Get Jacobian
        long long Jh = J((long long)x);
        NVec *Jv = (NVec *)(void *)Jh;

        // Solve J * dx = -F via Gaussian elimination
        double *A = (double *)malloc(n * n * sizeof(double));
        double *b = (double *)malloc(n * sizeof(double));
        for (int i = 0; i < n * n; i++) A[i] = _rt_i2f(Jv->data[i]);
        for (int i = 0; i < n; i++) b[i] = -_rt_i2f(Fv->data[i]);

        for (int k = 0; k < n; k++) {
            int max_row = k;
            double max_val = fabs(A[k * n + k]);
            for (int i = k + 1; i < n; i++)
                if (fabs(A[i * n + k]) > max_val) { max_val = fabs(A[i * n + k]); max_row = i; }
            if (max_row != k) {
                for (int j = 0; j < n; j++) {
                    double tmp = A[k * n + j]; A[k * n + j] = A[max_row * n + j]; A[max_row * n + j] = tmp;
                }
                double tmp = b[k]; b[k] = b[max_row]; b[max_row] = tmp;
            }
            if (fabs(A[k * n + k]) < 1e-30) continue;
            for (int i = k + 1; i < n; i++) {
                double factor = A[i * n + k] / A[k * n + k];
                for (int j = k + 1; j < n; j++) A[i * n + j] -= factor * A[k * n + j];
                b[i] -= factor * b[k];
            }
        }
        // Back substitution
        double *dx = (double *)calloc(n, sizeof(double));
        for (int i = n - 1; i >= 0; i--) {
            dx[i] = b[i];
            for (int j = i + 1; j < n; j++) dx[i] -= A[i * n + j] * dx[j];
            if (fabs(A[i * n + i]) > 1e-30) dx[i] /= A[i * n + i];
        }

        for (int i = 0; i < n; i++)
            x->data[i] = _rt_f2i(_rt_i2f(x->data[i]) + dx[i]);

        free(A); free(b); free(dx);
    }
    return (long long)x;
}
