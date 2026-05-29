// dubins_rt.c — Dubins shortest paths for a car-like robot with
// minimum turning radius (Dubins 1957; Shkel & Lumelsky 2001
// closed-form classification).
//
// Given start pose `(x0, y0, θ0)`, goal pose `(x1, y1, θ1)`, and
// minimum turning radius `R`, computes the length of the shortest
// path among the 6 candidate Dubins word types:
//
//   LSL, LSR, RSL, RSR  (Curve-Straight-Curve)
//   RLR, LRL            (Curve-Curve-Curve)
//
// Each "L"/"R" is a turn at minimum radius (left/right); "S" is a
// straight segment. Returns the shortest total path length and
// the type index (0..5).
//
// Limitations (path sampling / Reeds-Shepp (with reverse) /
// curvature-bounded smoothing land in v0.6 if needed):
// - Forward-only (no reverse motion). For a car that can also
//   reverse use Reeds-Shepp paths (planned for v0.6).
// - Returns lengths only (not sampled poses along the path).
//   Add a sampler later if needed for trajectory execution.
//
// Compile: clang -c stdlib/runtime/dubins_rt.c -o target/dubins.obj -O2

#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#define TWOPI (2.0 * M_PI)

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static double _mod_2pi(double a) {
    a = fmod(a, TWOPI);
    if (a < 0) a += TWOPI;
    return a;
}

// Each path computation returns a "valid" flag and (t, p, q) — the
// three segment-length parameters in NORMALIZED units (R = 1).
// Total path length = (t + p + q) * R.

static int _dubins_LSL(double a, double b, double D, double *t, double *p, double *q) {
    double tmp1 = atan2(cos(b) - cos(a), D + sin(a) - sin(b));
    double tmp2 = 2.0 + D*D - 2.0*cos(a-b) + 2.0*D*(sin(a) - sin(b));
    if (tmp2 < 0) return 0;
    *p = sqrt(tmp2);
    *t = _mod_2pi(-a + tmp1);
    *q = _mod_2pi(b - tmp1);
    return 1;
}
static int _dubins_RSR(double a, double b, double D, double *t, double *p, double *q) {
    double tmp1 = atan2(cos(a) - cos(b), D - sin(a) + sin(b));
    double tmp2 = 2.0 + D*D - 2.0*cos(a-b) + 2.0*D*(sin(b) - sin(a));
    if (tmp2 < 0) return 0;
    *p = sqrt(tmp2);
    *t = _mod_2pi(a - tmp1);
    *q = _mod_2pi(-b + tmp1);
    return 1;
}
static int _dubins_LSR(double a, double b, double D, double *t, double *p, double *q) {
    double tmp1 = -2.0 + D*D + 2.0*cos(a-b) + 2.0*D*(sin(a) + sin(b));
    if (tmp1 < 0) return 0;
    *p = sqrt(tmp1);
    double tmp2 = atan2(-cos(a) - cos(b), D + sin(a) + sin(b)) - atan2(-2.0, *p);
    *t = _mod_2pi(-a + tmp2);
    *q = _mod_2pi(-_mod_2pi(b) + tmp2);
    return 1;
}
static int _dubins_RSL(double a, double b, double D, double *t, double *p, double *q) {
    double tmp1 = -2.0 + D*D + 2.0*cos(a-b) - 2.0*D*(sin(a) + sin(b));
    if (tmp1 < 0) return 0;
    *p = sqrt(tmp1);
    double tmp2 = atan2(cos(a) + cos(b), D - sin(a) - sin(b)) - atan2(2.0, *p);
    *t = _mod_2pi(a - tmp2);
    *q = _mod_2pi(b - tmp2);
    return 1;
}
static int _dubins_RLR(double a, double b, double D, double *t, double *p, double *q) {
    double tmp = (6.0 - D*D + 2.0*cos(a-b) + 2.0*D*(sin(a) - sin(b))) / 8.0;
    if (fabs(tmp) > 1.0) return 0;
    *p = _mod_2pi(2.0 * M_PI - acos(tmp));
    *t = _mod_2pi(a - atan2(cos(a) - cos(b), D - sin(a) + sin(b)) + (*p) * 0.5);
    *q = _mod_2pi(a - b - (*t) + (*p));
    return 1;
}
static int _dubins_LRL(double a, double b, double D, double *t, double *p, double *q) {
    double tmp = (6.0 - D*D + 2.0*cos(a-b) + 2.0*D*(-sin(a) + sin(b))) / 8.0;
    if (fabs(tmp) > 1.0) return 0;
    *p = _mod_2pi(2.0 * M_PI - acos(tmp));
    *t = _mod_2pi(-a + atan2(-cos(a) + cos(b), D + sin(a) - sin(b)) + (*p) * 0.5);
    *q = _mod_2pi(_mod_2pi(b) - a - (*t) + (*p));
    return 1;
}

// Returns shortest path length (in original world units, not
// normalized). Writes type index (0..5) to type_out_ptr (long long).
// Returns -1 cast as bit pattern on infeasible.
long long nuc_dubins_shortest(long long x0_b, long long y0_b, long long t0_b,
                                long long x1_b, long long y1_b, long long t1_b,
                                long long R_b, long long type_out_ptr)
{
    double x0 = _i2f(x0_b), y0 = _i2f(y0_b), th0 = _i2f(t0_b);
    double x1 = _i2f(x1_b), y1 = _i2f(y1_b), th1 = _i2f(t1_b);
    double R  = _i2f(R_b);
    long long *type_out = (long long *)(void *)(size_t)type_out_ptr;
    if (R <= 0) return _f2i(-1.0);

    double dx = x1 - x0, dy = y1 - y0;
    double D = sqrt(dx*dx + dy*dy) / R;
    double th = atan2(dy, dx);
    double a = _mod_2pi(th0 - th);
    double b = _mod_2pi(th1 - th);

    double best = INFINITY;
    int best_type = -1;
    double tt, pp, qq;

    if (_dubins_LSL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 0; } }
    if (_dubins_LSR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 1; } }
    if (_dubins_RSL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 2; } }
    if (_dubins_RSR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 3; } }
    if (_dubins_RLR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 4; } }
    if (_dubins_LRL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 5; } }

    if (best_type < 0) {
        if (type_out) *type_out = -1;
        return _f2i(-1.0);
    }
    if (type_out) *type_out = best_type;
    return _f2i(best * R);
}

// Same but also writes the 3 segment lengths (in world units) to
// `params_out_ptr` (`double[3]`). For segments 0 and 2 (turns) the
// "length" is arc length = angle * R. For segment 1 in a CSC type
// it's the straight distance; in a CCC type it's also arc length.
long long nuc_dubins_shortest_with_segments(long long x0_b, long long y0_b, long long t0_b,
                                              long long x1_b, long long y1_b, long long t1_b,
                                              long long R_b, long long type_out_ptr,
                                              long long params_out_ptr)
{
    double x0 = _i2f(x0_b), y0 = _i2f(y0_b), th0 = _i2f(t0_b);
    double x1 = _i2f(x1_b), y1 = _i2f(y1_b), th1 = _i2f(t1_b);
    double R  = _i2f(R_b);
    long long *type_out = (long long *)(void *)(size_t)type_out_ptr;
    double *params_out = (double *)(void *)(size_t)params_out_ptr;
    if (R <= 0) return _f2i(-1.0);

    double dx = x1 - x0, dy = y1 - y0;
    double D = sqrt(dx*dx + dy*dy) / R;
    double th = atan2(dy, dx);
    double a = _mod_2pi(th0 - th);
    double b = _mod_2pi(th1 - th);

    double best = INFINITY;
    int best_type = -1;
    double best_t = 0, best_p = 0, best_q = 0;

    double tt, pp, qq;
    if (_dubins_LSL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 0; best_t=tt; best_p=pp; best_q=qq; } }
    if (_dubins_LSR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 1; best_t=tt; best_p=pp; best_q=qq; } }
    if (_dubins_RSL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 2; best_t=tt; best_p=pp; best_q=qq; } }
    if (_dubins_RSR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 3; best_t=tt; best_p=pp; best_q=qq; } }
    if (_dubins_RLR(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 4; best_t=tt; best_p=pp; best_q=qq; } }
    if (_dubins_LRL(a, b, D, &tt, &pp, &qq)) { double L = tt+pp+qq; if (L < best) { best = L; best_type = 5; best_t=tt; best_p=pp; best_q=qq; } }

    if (best_type < 0) {
        if (type_out) *type_out = -1;
        return _f2i(-1.0);
    }
    if (type_out) *type_out = best_type;
    if (params_out) {
        // For CSC types (0..3) the middle segment is straight (length = p · R).
        // For CCC types (4..5) all three are arcs (length = angle · R).
        params_out[0] = best_t * R;
        params_out[1] = best_p * R;
        params_out[2] = best_q * R;
    }
    return _f2i(best * R);
}
