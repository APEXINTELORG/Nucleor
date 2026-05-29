// bezier_rt.c — Bezier curve evaluation in 2-D and 3-D.
//
// Given N control points (degree N-1), evaluates the Bezier
// curve at parameter t ∈ [0, 1] using the de Casteljau
// recurrence — numerically stable and works for arbitrary
// degree.
//
// API:
//   nuc_bezier_eval_2d(ctrl_xy_ptr, n_ctrl, t, out_ptr)
//      Sample (x, y) at t. ctrl_xy is double[2*n_ctrl] interleaved.
//      out is double[2].
//
//   nuc_bezier_eval_3d(ctrl_xyz_ptr, n_ctrl, t, out_ptr)
//      Sample (x, y, z) at t. ctrl_xyz is double[3*n_ctrl].
//
// Use:
//   - Path authoring (UI bezier handle widgets).
//   - Bezier-spline trajectory generators.
//   - Smooth interpolation between handful of waypoints (Bezier
//     gives more local control than cubic spline).
//
// Limitations (rational Bezier / NURBS / Bezier curve
// arc-length parameterization land in v0.6 if needed):
// - Polynomial Bezier only (no weighted/rational variant).
// - Caller-supplied parameter t (no arc-length re-parameterization).
// - Up to ~20 control points stays numerically stable; beyond,
//   prefer piecewise cubic Bezier or B-spline.
//
// Compile: clang -c stdlib/runtime/bezier_rt.c -o target/bezier.obj -O2

#include <string.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Sample 2-D Bezier at t. Returns 1 on success, writes x,y to out.
long long nuc_bezier_eval_2d(long long ctrl_xy_ptr, long long n_ctrl_,
                              long long t_b, long long out_ptr)
{
    int n = (int)n_ctrl_;
    if (n < 2) return 0;
    const double *c = (const double *)(void *)(size_t)ctrl_xy_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!c || !out) return 0;
    double t = _i2f(t_b);
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    // de Casteljau into a working buffer of size 2*n.
    double *w = (double *)malloc(sizeof(double) * 2 * n);
    if (!w) return 0;
    memcpy(w, c, sizeof(double) * 2 * n);
    double mt = 1.0 - t;
    for (int level = 1; level < n; level++) {
        for (int i = 0; i < n - level; i++) {
            w[i*2+0] = mt * w[i*2+0] + t * w[(i+1)*2+0];
            w[i*2+1] = mt * w[i*2+1] + t * w[(i+1)*2+1];
        }
    }
    out[0] = w[0];
    out[1] = w[1];
    free(w);
    return 1;
}

// Sample 3-D Bezier at t. ctrl_xyz is double[3*n_ctrl] interleaved.
// out is double[3].
long long nuc_bezier_eval_3d(long long ctrl_xyz_ptr, long long n_ctrl_,
                              long long t_b, long long out_ptr)
{
    int n = (int)n_ctrl_;
    if (n < 2) return 0;
    const double *c = (const double *)(void *)(size_t)ctrl_xyz_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!c || !out) return 0;
    double t = _i2f(t_b);
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    double *w = (double *)malloc(sizeof(double) * 3 * n);
    if (!w) return 0;
    memcpy(w, c, sizeof(double) * 3 * n);
    double mt = 1.0 - t;
    for (int level = 1; level < n; level++) {
        for (int i = 0; i < n - level; i++) {
            w[i*3+0] = mt * w[i*3+0] + t * w[(i+1)*3+0];
            w[i*3+1] = mt * w[i*3+1] + t * w[(i+1)*3+1];
            w[i*3+2] = mt * w[i*3+2] + t * w[(i+1)*3+2];
        }
    }
    out[0] = w[0];
    out[1] = w[1];
    out[2] = w[2];
    free(w);
    return 1;
}
