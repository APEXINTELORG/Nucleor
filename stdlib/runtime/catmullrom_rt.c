// catmullrom_rt.c — Catmull-Rom spline evaluation in 2-D and 3-D.
//
// Interpolating spline that passes through every control point
// (vs Bezier which only hits endpoints). C¹ continuous (tangent
// at each point matches the secant of its neighbors). Locally
// controlled: changing one control point only affects the two
// segments adjacent to it.
//
// Standard "centripetal" parameterization (alpha = 0.5) avoids
// the loops/cusps that appear with uniform parameterization on
// non-uniform control point spacing. Caller picks alpha:
//   alpha = 0.0 → uniform (classic Catmull-Rom; can self-intersect)
//   alpha = 0.5 → centripetal (recommended; no self-intersection)
//   alpha = 1.0 → chordal (smoother but can overshoot)
//
// API:
//   nuc_catmullrom_eval_2d(ctrl_xy_ptr, n, t_global, alpha, out_ptr)
//      Sample at t_global ∈ [0, n-3]. The integer part picks the
//      segment between control points (i+1, i+2); fractional part
//      is the local parameter within that segment.
//
// Use:
//   - Animation paths.
//   - Camera trajectories.
//   - Smooth interpolation through waypoints with local control.
//
// **Limitations** (Catmull-Rom variants with arbitrary tangent
// scales / arc-length reparameterization land in v0.6 if needed):
// - Requires N ≥ 4 control points (segment between i+1 and i+2
//   needs neighbors i and i+3).
// - Caller-supplied parameter t_global; no arc-length reparam.
// - 2-D and 3-D variants; higher dimensions need a generic version.
//
// Compile: clang -c stdlib/runtime/catmullrom_rt.c -o target/catmullrom.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Centripetal Catmull-Rom segment evaluator. Computes one component
// (x or y or z) at parameter t ∈ [t1, t2], given 4 control points
// p0..p3 with parameters t0..t3.
static double _cr_segment(double p0, double p1, double p2, double p3,
                           double t0, double t1, double t2, double t3,
                           double t)
{
    double a1 = ((t1 - t) * p0 + (t - t0) * p1) / (t1 - t0);
    double a2 = ((t2 - t) * p1 + (t - t1) * p2) / (t2 - t1);
    double a3 = ((t3 - t) * p2 + (t - t2) * p3) / (t3 - t2);
    double b1 = ((t2 - t) * a1 + (t - t0) * a2) / (t2 - t0);
    double b2 = ((t3 - t) * a2 + (t - t1) * a3) / (t3 - t1);
    return ((t2 - t) * b1 + (t - t1) * b2) / (t2 - t1);
}

static double _knot_step(double dx, double dy, double dz, double alpha) {
    double d = sqrt(dx*dx + dy*dy + dz*dz);
    if (d < 1e-18) d = 1e-18;
    if (alpha == 0.0) return 1.0;
    if (alpha == 1.0) return d;
    return pow(d, alpha);
}

// Sample 2-D Catmull-Rom at global parameter t_global ∈ [0, n-3].
// out is double[2].
long long nuc_catmullrom_eval_2d(long long ctrl_xy_ptr, long long n_ctrl_,
                                   long long t_global_b, long long alpha_b,
                                   long long out_ptr)
{
    int n = (int)n_ctrl_;
    if (n < 4) return 0;
    const double *c = (const double *)(void *)(size_t)ctrl_xy_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!c || !out) return 0;
    double tg = _i2f(t_global_b);
    double alpha = _i2f(alpha_b);
    if (tg < 0) tg = 0;
    double max_seg = (double)(n - 3);
    if (tg > max_seg) tg = max_seg;
    int seg = (int)tg;
    if (seg >= n - 3) seg = n - 4;
    double local = tg - (double)seg;
    // 4 control points for this segment.
    double p0x = c[(seg+0)*2+0], p0y = c[(seg+0)*2+1];
    double p1x = c[(seg+1)*2+0], p1y = c[(seg+1)*2+1];
    double p2x = c[(seg+2)*2+0], p2y = c[(seg+2)*2+1];
    double p3x = c[(seg+3)*2+0], p3y = c[(seg+3)*2+1];
    // Compute knot parameters from chord lengths.
    double t0 = 0;
    double t1 = t0 + _knot_step(p1x-p0x, p1y-p0y, 0.0, alpha);
    double t2 = t1 + _knot_step(p2x-p1x, p2y-p1y, 0.0, alpha);
    double t3 = t2 + _knot_step(p3x-p2x, p3y-p2y, 0.0, alpha);
    double t = t1 + local * (t2 - t1);
    out[0] = _cr_segment(p0x, p1x, p2x, p3x, t0, t1, t2, t3, t);
    out[1] = _cr_segment(p0y, p1y, p2y, p3y, t0, t1, t2, t3, t);
    return 1;
}

// 3-D variant. ctrl_xyz is double[3*n] interleaved.
long long nuc_catmullrom_eval_3d(long long ctrl_xyz_ptr, long long n_ctrl_,
                                   long long t_global_b, long long alpha_b,
                                   long long out_ptr)
{
    int n = (int)n_ctrl_;
    if (n < 4) return 0;
    const double *c = (const double *)(void *)(size_t)ctrl_xyz_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!c || !out) return 0;
    double tg = _i2f(t_global_b);
    double alpha = _i2f(alpha_b);
    if (tg < 0) tg = 0;
    double max_seg = (double)(n - 3);
    if (tg > max_seg) tg = max_seg;
    int seg = (int)tg;
    if (seg >= n - 3) seg = n - 4;
    double local = tg - (double)seg;
    double p0x = c[(seg+0)*3+0], p0y = c[(seg+0)*3+1], p0z = c[(seg+0)*3+2];
    double p1x = c[(seg+1)*3+0], p1y = c[(seg+1)*3+1], p1z = c[(seg+1)*3+2];
    double p2x = c[(seg+2)*3+0], p2y = c[(seg+2)*3+1], p2z = c[(seg+2)*3+2];
    double p3x = c[(seg+3)*3+0], p3y = c[(seg+3)*3+1], p3z = c[(seg+3)*3+2];
    double t0 = 0;
    double t1 = t0 + _knot_step(p1x-p0x, p1y-p0y, p1z-p0z, alpha);
    double t2 = t1 + _knot_step(p2x-p1x, p2y-p1y, p2z-p1z, alpha);
    double t3 = t2 + _knot_step(p3x-p2x, p3y-p2y, p3z-p2z, alpha);
    double t = t1 + local * (t2 - t1);
    out[0] = _cr_segment(p0x, p1x, p2x, p3x, t0, t1, t2, t3, t);
    out[1] = _cr_segment(p0y, p1y, p2y, p3y, t0, t1, t2, t3, t);
    out[2] = _cr_segment(p0z, p1z, p2z, p3z, t0, t1, t2, t3, t);
    return 1;
}
