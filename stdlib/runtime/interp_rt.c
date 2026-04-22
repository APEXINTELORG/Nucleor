// interp_rt.c — Interpolation and Approximation for Nucleor
// Linear, cubic spline, Lagrange, Chebyshev, 2D bilinear, RBF.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/interp_rt.c -o target/interp_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ip_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ip_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } IPVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  Linear Interpolation
// ================================================================

long long nuc_interp_linear(long long xs_h, long long ys_h, long long x_bits) {
    IPVec *xs = (IPVec *)(void *)xs_h, *ys = (IPVec *)(void *)ys_h;
    double x = _ip_i2f(x_bits);
    int n = xs->len;
    if (n < 2) return (n == 1) ? ys->data[0] : _ip_f2i(0.0);

    // Find bracketing interval
    int lo = 0;
    for (int i = 1; i < n; i++) {
        if (_ip_i2f(xs->data[i]) <= x) lo = i;
        else break;
    }
    int hi = lo + 1;
    if (hi >= n) hi = n - 1;
    if (lo == hi) return ys->data[lo];

    double x0 = _ip_i2f(xs->data[lo]), x1 = _ip_i2f(xs->data[hi]);
    double y0 = _ip_i2f(ys->data[lo]), y1 = _ip_i2f(ys->data[hi]);
    double t = (fabs(x1 - x0) > 1e-15) ? (x - x0) / (x1 - x0) : 0.0;
    return _ip_f2i(y0 + t * (y1 - y0));
}

// ================================================================
//  Cubic Spline (natural, not-a-knot)
// ================================================================

long long nuc_interp_cubic_spline(long long xs_h, long long ys_h, long long x_bits) {
    IPVec *xs = (IPVec *)(void *)xs_h, *ys = (IPVec *)(void *)ys_h;
    double x = _ip_i2f(x_bits);
    int n = xs->len;
    if (n < 3) return nuc_interp_linear(xs_h, ys_h, x_bits);

    double *xd = (double *)malloc(n * sizeof(double));
    double *yd = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) { xd[i] = _ip_i2f(xs->data[i]); yd[i] = _ip_i2f(ys->data[i]); }

    // Compute second derivatives (natural spline: S''(0) = S''(n-1) = 0)
    double *h = (double *)malloc((n - 1) * sizeof(double));
    double *alpha = (double *)calloc(n, sizeof(double));
    double *l = (double *)malloc(n * sizeof(double));
    double *mu = (double *)calloc(n, sizeof(double));
    double *z = (double *)calloc(n, sizeof(double));

    for (int i = 0; i < n - 1; i++) h[i] = xd[i + 1] - xd[i];
    for (int i = 1; i < n - 1; i++)
        alpha[i] = (3.0 / h[i]) * (yd[i + 1] - yd[i]) - (3.0 / h[i - 1]) * (yd[i] - yd[i - 1]);

    l[0] = 1;
    for (int i = 1; i < n - 1; i++) {
        l[i] = 2 * (xd[i + 1] - xd[i - 1]) - h[i - 1] * mu[i - 1];
        mu[i] = h[i] / l[i];
        z[i] = (alpha[i] - h[i - 1] * z[i - 1]) / l[i];
    }
    l[n - 1] = 1;

    double *c = (double *)calloc(n, sizeof(double));
    double *b = (double *)malloc(n * sizeof(double));
    double *d = (double *)malloc(n * sizeof(double));

    for (int j = n - 2; j >= 0; j--) {
        c[j] = z[j] - mu[j] * c[j + 1];
        b[j] = (yd[j + 1] - yd[j]) / h[j] - h[j] * (c[j + 1] + 2 * c[j]) / 3;
        d[j] = (c[j + 1] - c[j]) / (3 * h[j]);
    }

    // Find interval and evaluate
    int seg = 0;
    for (int i = 0; i < n - 1; i++) {
        if (x >= xd[i]) seg = i;
    }
    double dx = x - xd[seg];
    double result = yd[seg] + b[seg] * dx + c[seg] * dx * dx + d[seg] * dx * dx * dx;

    free(xd); free(yd); free(h); free(alpha); free(l); free(mu); free(z);
    free(c); free(b); free(d);
    return _ip_f2i(result);
}

// ================================================================
//  Lagrange Interpolation
// ================================================================

long long nuc_interp_lagrange(long long xs_h, long long ys_h, long long x_bits) {
    IPVec *xs = (IPVec *)(void *)xs_h, *ys = (IPVec *)(void *)ys_h;
    double x = _ip_i2f(x_bits);
    int n = xs->len;
    double result = 0;
    for (int i = 0; i < n; i++) {
        double xi = _ip_i2f(xs->data[i]);
        double yi = _ip_i2f(ys->data[i]);
        double basis = 1.0;
        for (int j = 0; j < n; j++) {
            if (i == j) continue;
            double xj = _ip_i2f(xs->data[j]);
            basis *= (x - xj) / (xi - xj);
        }
        result += yi * basis;
    }
    return _ip_f2i(result);
}

// ================================================================
//  Chebyshev Interpolation
//  Returns coefficients as Vec<f64>
// ================================================================

long long nuc_interp_chebyshev(long long f_ptr, long long n, long long a_bits, long long b_bits) {
    typedef long long (*Fn)(long long);
    Fn func = (Fn)(void *)f_ptr;
    int N = (int)n;
    double a = _ip_i2f(a_bits), b = _ip_i2f(b_bits);

    double *fvals = (double *)malloc(N * sizeof(double));
    for (int k = 0; k < N; k++) {
        double xk = cos(M_PI * (k + 0.5) / N);
        double x = 0.5 * (b - a) * xk + 0.5 * (a + b);
        fvals[k] = _ip_i2f(func(_ip_f2i(x)));
    }

    IPVec *coeffs = (IPVec *)malloc(sizeof(IPVec));
    coeffs->len = N; coeffs->cap = N;
    coeffs->data = (long long *)malloc(N * sizeof(long long));

    for (int j = 0; j < N; j++) {
        double cj = 0;
        for (int k = 0; k < N; k++)
            cj += fvals[k] * cos(M_PI * j * (k + 0.5) / N);
        cj *= 2.0 / N;
        if (j == 0) cj *= 0.5;
        coeffs->data[j] = _ip_f2i(cj);
    }
    free(fvals);
    return (long long)coeffs;
}

long long nuc_interp_eval_chebyshev(long long coeffs_h, long long x_bits,
                                      long long a_bits, long long b_bits) {
    IPVec *coeffs = (IPVec *)(void *)coeffs_h;
    double x = _ip_i2f(x_bits);
    double a = _ip_i2f(a_bits), b = _ip_i2f(b_bits);
    int N = coeffs->len;

    double xn = (2.0 * x - a - b) / (b - a); // map to [-1,1]

    // Clenshaw recurrence
    double b1 = 0, b2 = 0;
    for (int j = N - 1; j >= 1; j--) {
        double tmp = 2.0 * xn * b1 - b2 + _ip_i2f(coeffs->data[j]);
        b2 = b1; b1 = tmp;
    }
    double result = xn * b1 - b2 + _ip_i2f(coeffs->data[0]);
    return _ip_f2i(result);
}

// ================================================================
//  2D Bilinear Interpolation
//  grid is flat [Ny][Nx] row-major, x in [0, Nx-1], y in [0, Ny-1]
// ================================================================

long long nuc_interp_2d_bilinear(long long grid_h, long long Nx, long long Ny,
                                   long long x_bits, long long y_bits) {
    IPVec *grid = (IPVec *)(void *)grid_h;
    int nx = (int)Nx, ny = (int)Ny;
    double x = _ip_i2f(x_bits), y = _ip_i2f(y_bits);

    int x0 = (int)x, y0 = (int)y;
    if (x0 < 0) x0 = 0; if (x0 >= nx - 1) x0 = nx - 2;
    if (y0 < 0) y0 = 0; if (y0 >= ny - 1) y0 = ny - 2;
    int x1 = x0 + 1, y1 = y0 + 1;

    double fx = x - x0, fy = y - y0;
    double f00 = _ip_i2f(grid->data[y0 * nx + x0]);
    double f10 = _ip_i2f(grid->data[y0 * nx + x1]);
    double f01 = _ip_i2f(grid->data[y1 * nx + x0]);
    double f11 = _ip_i2f(grid->data[y1 * nx + x1]);

    double result = f00 * (1 - fx) * (1 - fy) + f10 * fx * (1 - fy) +
                    f01 * (1 - fx) * fy + f11 * fx * fy;
    return _ip_f2i(result);
}

// ================================================================
//  Radial Basis Function Interpolation
//  RBF: phi(r) = exp(-r^2 / (2*sigma^2))
// ================================================================

long long nuc_interp_rbf(long long centers_h, long long weights_h,
                          long long x_bits, long long sigma_bits) {
    IPVec *centers = (IPVec *)(void *)centers_h;
    IPVec *weights = (IPVec *)(void *)weights_h;
    double x = _ip_i2f(x_bits);
    double sigma = _ip_i2f(sigma_bits);
    double inv2s2 = 1.0 / (2.0 * sigma * sigma);

    double result = 0;
    for (int i = 0; i < centers->len; i++) {
        double r = x - _ip_i2f(centers->data[i]);
        result += _ip_i2f(weights->data[i]) * exp(-r * r * inv2s2);
    }
    return _ip_f2i(result);
}
