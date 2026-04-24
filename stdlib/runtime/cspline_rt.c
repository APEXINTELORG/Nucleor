// cspline_rt.c — Natural cubic spline interpolation through
// caller-supplied waypoints `(x_0, y_0), …, (x_N, y_N)`.
//
// Builds N segments, each a cubic polynomial in `(x − x_k)`, with
// continuous first and second derivatives at every internal
// waypoint. "Natural" boundary conditions: second derivative
// vanishes at the endpoints (`y''(x_0) = y''(x_N) = 0`).
//
// Standard textbook formulation: solve a symmetric tridiagonal
// system via the Thomas algorithm for the second derivatives at
// each waypoint, then evaluate via per-segment cubic.
//
// Use cases:
//   - Smooth trajectory through joint waypoints (one spline per joint).
//   - Smooth trajectory through Cartesian waypoints (one per axis).
//   - Smoothing of measured time series for derivative estimation.
//
// Compare to:
//   - `qtraj.nr` — minimum-snap (4th derivative bounded), 7th-degree
//     per segment, more aggressive smoothness for quadrotors.
//   - `bspline.nr` — general degree-k B-splines with explicit
//     control points and knot vectors.
//   - `cspline.nr` (this rod) — simplest "smooth fit through
//     waypoints" primitive, no extra control-point machinery.
//
// **Limitations** (clamped / periodic / parametric C2 splines land
// in v0.6 if needed):
// - 1-D y over 1-D x only — call N times for N-dimensional
//   trajectories.
// - Natural BC only (second derivative = 0 at endpoints). Clamped
//   BC (specified first derivative) planned for v0.6.
// - Caller must keep waypoints in strictly increasing x order.
//
// Compile: clang -c stdlib/runtime/cspline_rt.c -o target/cspline.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n;          // n waypoints; n-1 segments
    double *x;      // n waypoints (must be strictly increasing)
    double *y;      // n values
    double *m;      // n second derivatives (computed by solve)
    int solved;
} NCSPL;

long long nuc_cspline_new(long long n_waypoints) {
    int n = (int)n_waypoints;
    if (n < 2) return 0;
    NCSPL *p = (NCSPL *)calloc(1, sizeof(NCSPL));
    p->n = n;
    p->x = (double *)calloc(n, sizeof(double));
    p->y = (double *)calloc(n, sizeof(double));
    p->m = (double *)calloc(n, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_cspline_set_waypoint(long long h, long long k_, long long x_b, long long y_b) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p) return;
    int k = (int)k_;
    if (k < 0 || k >= p->n) return;
    p->x[k] = _i2f(x_b);
    p->y[k] = _i2f(y_b);
    p->solved = 0;
}

// Solve the tridiagonal system for second derivatives.
// Standard Thomas algorithm.
long long nuc_cspline_solve(long long h) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p) return 0;
    int n = p->n;
    if (n < 2) return 0;
    // Natural BC: m[0] = m[n-1] = 0.
    if (n == 2) {
        // Linear interpolation — both second derivatives 0.
        p->m[0] = 0; p->m[1] = 0;
        p->solved = 1;
        return 1;
    }

    // Verify strict-increasing x.
    for (int i = 1; i < n; i++) {
        if (p->x[i] <= p->x[i-1]) return 0;
    }

    // Tridiagonal system for m[1..n-2] (interior second derivs):
    //   For i = 1..n-2:
    //     h_i = x_{i+1} - x_i
    //     h_{i-1} · m_{i-1} + 2(h_{i-1} + h_i) · m_i + h_i · m_{i+1}
    //         = 6 · ((y_{i+1} - y_i)/h_i - (y_i - y_{i-1})/h_{i-1})
    // Endpoints m_0 = m_{n-1} = 0 (natural).
    int int_n = n - 2;        // number of interior nodes
    double *a = (double *)malloc(int_n * sizeof(double));   // lower diag
    double *b = (double *)malloc(int_n * sizeof(double));   // main diag
    double *c = (double *)malloc(int_n * sizeof(double));   // upper diag
    double *d = (double *)malloc(int_n * sizeof(double));   // RHS

    for (int i = 0; i < int_n; i++) {
        int idx = i + 1;        // global waypoint index
        double h_lo = p->x[idx]   - p->x[idx-1];
        double h_hi = p->x[idx+1] - p->x[idx];
        a[i] = h_lo;
        b[i] = 2.0 * (h_lo + h_hi);
        c[i] = h_hi;
        d[i] = 6.0 * ( (p->y[idx+1] - p->y[idx]) / h_hi
                     - (p->y[idx]   - p->y[idx-1]) / h_lo );
    }
    // Endpoint contributions (m_0, m_{n-1} = 0) drop out.
    a[0] = 0;            // no lower-neighbor for first interior node
    c[int_n - 1] = 0;    // no upper-neighbor for last

    // Thomas algorithm.
    for (int i = 1; i < int_n; i++) {
        double w = a[i] / b[i-1];
        b[i] -= w * c[i-1];
        d[i] -= w * d[i-1];
    }
    p->m[n-1] = 0;
    p->m[int_n] = d[int_n - 1] / b[int_n - 1];      // m[n-2]
    for (int i = int_n - 2; i >= 0; i--) {
        p->m[i + 1] = (d[i] - c[i] * p->m[i + 2]) / b[i];
    }
    p->m[0] = 0;
    p->solved = 1;
    free(a); free(b); free(c); free(d);
    return 1;
}

// Find the segment k such that x[k] ≤ x ≤ x[k+1]; binary search.
static int _find_seg(const NCSPL *p, double x) {
    int n = p->n;
    if (x <= p->x[0]) return 0;
    if (x >= p->x[n-1]) return n - 2;
    int lo = 0, hi = n - 1;
    while (hi - lo > 1) {
        int mid = (lo + hi) / 2;
        if (p->x[mid] <= x) lo = mid; else hi = mid;
    }
    return lo;
}

long long nuc_cspline_eval(long long h, long long x_b) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    double x = _i2f(x_b);
    int k = _find_seg(p, x);
    double h_k = p->x[k+1] - p->x[k];
    double t = x - p->x[k];
    // y(x) = m_k/(6 h_k)·(x_{k+1}-x)³ + m_{k+1}/(6 h_k)·(x-x_k)³
    //      + (y_k/h_k - m_k h_k/6)·(x_{k+1}-x)
    //      + (y_{k+1}/h_k - m_{k+1} h_k/6)·(x-x_k)
    double a_lo = p->x[k+1] - x;
    double a_hi = t;
    double y = (p->m[k]   / (6.0 * h_k)) * a_lo*a_lo*a_lo
             + (p->m[k+1] / (6.0 * h_k)) * a_hi*a_hi*a_hi
             + (p->y[k]   / h_k - p->m[k]   * h_k / 6.0) * a_lo
             + (p->y[k+1] / h_k - p->m[k+1] * h_k / 6.0) * a_hi;
    return _f2i(y);
}

long long nuc_cspline_eval_derivative(long long h, long long x_b) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    double x = _i2f(x_b);
    int k = _find_seg(p, x);
    double h_k = p->x[k+1] - p->x[k];
    double a_lo = p->x[k+1] - x;
    double a_hi = x - p->x[k];
    // y'(x) = -m_k/(2 h_k)·(x_{k+1}-x)² + m_{k+1}/(2 h_k)·(x-x_k)²
    //         - (y_k/h_k - m_k h_k/6) + (y_{k+1}/h_k - m_{k+1} h_k/6)
    double yp = -(p->m[k]   / (2.0 * h_k)) * a_lo*a_lo
              +  (p->m[k+1] / (2.0 * h_k)) * a_hi*a_hi
              -  (p->y[k]   / h_k - p->m[k]   * h_k / 6.0)
              +  (p->y[k+1] / h_k - p->m[k+1] * h_k / 6.0);
    return _f2i(yp);
}

long long nuc_cspline_eval_second_derivative(long long h, long long x_b) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    double x = _i2f(x_b);
    int k = _find_seg(p, x);
    double h_k = p->x[k+1] - p->x[k];
    double a_lo = p->x[k+1] - x;
    double a_hi = x - p->x[k];
    // y''(x) = m_k·(x_{k+1}-x)/h_k + m_{k+1}·(x-x_k)/h_k
    return _f2i((p->m[k] * a_lo + p->m[k+1] * a_hi) / h_k);
}

void nuc_cspline_free(long long h) {
    NCSPL *p = (NCSPL *)(void *)(size_t)h;
    if (!p) return;
    if (p->x) free(p->x);
    if (p->y) free(p->y);
    if (p->m) free(p->m);
    free(p);
}
