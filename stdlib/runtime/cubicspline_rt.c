// cubicspline_rt.c — Natural cubic spline interpolation through
// N control points. Pre-computes second-derivative coefficients
// via tridiagonal solve, then samples C² piecewise polynomials.
//
// Standard reference: Numerical Recipes §3.3 / Press et al. The
// "natural" boundary condition fixes the second derivatives at
// the endpoints to zero (zero curvature → tangent line at edges).
//
// Two-call API:
//   nuc_cubicspline_fit(xs, ys, n, y2_out)
//      Pre-computes the y2[] second-derivative table for later
//      sampling. xs MUST be strictly increasing.
//
//   nuc_cubicspline_sample(xs, ys, y2, n, x, out_ptr)
//      Sample y at x. Caller passes the precomputed y2[] from fit.
//
// Use:
//   - Path smoothing through waypoints (xs = arc-length, ys = pose
//     component).
//   - Sensor calibration table interpolation.
//   - Visualization curve fitting.
//
// Limitations (clamped / not-a-knot / monotone Hermite
// boundary conditions land in v0.6 if needed):
// - "Natural" boundary only (y''_0 = y''_{N-1} = 0).
// - O(N) sample via binary search; ok for ≤ 10K knots.
// - Requires strictly increasing xs (asserts non-monotonic via
//   return 0).
//
// Compile: clang -c stdlib/runtime/cubicspline_rt.c -o target/cubicspline.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Pre-compute the second-derivative table y2[]. Caller allocates
// y2_out as double[n]. Returns 1 on success, 0 if n<2 or xs not
// strictly increasing.
long long nuc_cubicspline_fit(long long xs_ptr, long long ys_ptr,
                                long long n_, long long y2_out_ptr)
{
    int n = (int)n_;
    if (n < 2) return 0;
    const double *xs = (const double *)(void *)(size_t)xs_ptr;
    const double *ys = (const double *)(void *)(size_t)ys_ptr;
    double *y2 = (double *)(void *)(size_t)y2_out_ptr;
    if (!xs || !ys || !y2) return 0;
    // Verify monotonic.
    for (int i = 1; i < n; i++) {
        if (xs[i] <= xs[i-1]) return 0;
    }
    if (n == 2) { y2[0] = 0; y2[1] = 0; return 1; }
    double *u = (double *)malloc(sizeof(double) * (n - 1));
    if (!u) return 0;
    // Natural boundary: y2[0] = 0, y2[n-1] = 0.
    y2[0] = 0;
    u[0] = 0;
    for (int i = 1; i < n - 1; i++) {
        double sig = (xs[i] - xs[i-1]) / (xs[i+1] - xs[i-1]);
        double p = sig * y2[i-1] + 2.0;
        y2[i] = (sig - 1.0) / p;
        double a = (ys[i+1] - ys[i]) / (xs[i+1] - xs[i]);
        double b = (ys[i] - ys[i-1]) / (xs[i] - xs[i-1]);
        u[i] = (6.0 * (a - b) / (xs[i+1] - xs[i-1]) - sig * u[i-1]) / p;
    }
    y2[n-1] = 0;
    for (int k = n - 2; k >= 0; k--) {
        y2[k] = y2[k] * y2[k+1] + u[k];
    }
    free(u);
    return 1;
}

// Sample y at position x. Writes one f64 to out_ptr. Returns 1
// on success, 0 on bad input. x outside [xs[0], xs[n-1]] is
// linearly extrapolated from the nearest spline segment.
long long nuc_cubicspline_sample(long long xs_ptr, long long ys_ptr,
                                   long long y2_ptr, long long n_,
                                   long long x_b, long long out_ptr)
{
    int n = (int)n_;
    if (n < 2) return 0;
    const double *xs = (const double *)(void *)(size_t)xs_ptr;
    const double *ys = (const double *)(void *)(size_t)ys_ptr;
    const double *y2 = (const double *)(void *)(size_t)y2_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!xs || !ys || !y2 || !out) return 0;
    double x = _i2f(x_b);
    // Binary search for klo such that xs[klo] <= x < xs[khi].
    int klo = 0, khi = n - 1;
    while (khi - klo > 1) {
        int k = (khi + klo) >> 1;
        if (xs[k] > x) khi = k; else klo = k;
    }
    double h = xs[khi] - xs[klo];
    if (h == 0.0) return 0;
    double a = (xs[khi] - x) / h;
    double b = (x - xs[klo]) / h;
    double y = a * ys[klo] + b * ys[khi]
             + ((a*a*a - a) * y2[klo] + (b*b*b - b) * y2[khi]) * (h * h) / 6.0;
    *out = y;
    return 1;
}
