// topp_rt.c — Trapezoidal time-parameterization for a 1-D
// arc-length path.
//
// Given a path total length L, max velocity v_max, and max
// acceleration a_max, computes the minimum-time trajectory s(t)
// along the path with |s'| ≤ v_max and |s''| ≤ a_max:
//
//   - Accelerate at a_max from rest until reaching v_max:
//       duration   t1 = v_max / a_max
//       distance   d1 = ½ · a_max · t1²
//   - Cruise at v_max for the middle (if reachable).
//   - Decelerate symmetrically.
//
// If 2·d1 > L the cruise phase doesn't fit — fall back to a
// triangular profile that peaks at √(L · a_max) < v_max.
//
// Use: convert a geometric path (e.g. a minimum-snap polynomial
// from `qtraj.nr`) into a time-parameterized one. Caller maps
// arc-length `s = topp_position(h, t)` back to robot configuration
// via the original geometric path.
//
// **Limitations** (full phase-plane TOPP / curvature-dependent
// limits land in v0.6 if needed):
// - Single global v_max + a_max (no path-dependent limits). For a
//   joint-space path with per-DOF limits the conservative choice
//   is `v_max = min over (s, dof) of v_max_dof / |path_velocity_dof(s)|`,
//   precomputed once.
// - Symmetric ramp; no asymmetric accel/decel limits.
// - Trapezoidal (jerk = δ-spike at corners). For jerk-limited
//   profiles use s-curve (planned for v0.6).
//
// Compile: clang -c stdlib/runtime/topp_rt.c -o target/topp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double L;            // path length
    double v_max;        // velocity ceiling
    double a_max;        // accel ceiling
    double v_peak;       // actual peak velocity (≤ v_max)
    double t_accel;      // duration of accel phase
    double t_cruise;     // duration of cruise phase (0 for triangular)
    double t_total;
    int triangular;      // 1 if triangular (cruise time = 0)
} NTOPP;

long long nuc_topp_trap_new(long long L_b, long long v_max_b, long long a_max_b) {
    double L = _i2f(L_b);
    double v_max = _i2f(v_max_b);
    double a_max = _i2f(a_max_b);
    if (L <= 0 || v_max <= 0 || a_max <= 0) return 0;
    NTOPP *p = (NTOPP *)calloc(1, sizeof(NTOPP));
    p->L = L; p->v_max = v_max; p->a_max = a_max;

    double t1 = v_max / a_max;
    double d1 = 0.5 * a_max * t1 * t1;

    if (2.0 * d1 >= L) {
        // Triangular profile: peak velocity below v_max.
        p->triangular = 1;
        p->t_accel = sqrt(L / a_max);
        p->v_peak = a_max * p->t_accel;
        p->t_cruise = 0;
        p->t_total = 2.0 * p->t_accel;
    } else {
        p->triangular = 0;
        p->t_accel = t1;
        p->v_peak = v_max;
        double d_cruise = L - 2.0 * d1;
        p->t_cruise = d_cruise / v_max;
        p->t_total = 2.0 * t1 + p->t_cruise;
    }
    return (long long)(size_t)p;
}

long long nuc_topp_trap_total_time(long long h) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->t_total);
}

long long nuc_topp_trap_path_length(long long h) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->L);
}

long long nuc_topp_trap_peak_velocity(long long h) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->v_peak);
}

long long nuc_topp_trap_position(long long h, long long t_b) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0) return _f2i(0.0);
    if (t >= p->t_total) return _f2i(p->L);
    double s;
    if (t <= p->t_accel) {
        // Accel phase: s = ½ a t²
        s = 0.5 * p->a_max * t * t;
    } else if (t <= p->t_accel + p->t_cruise) {
        // Cruise phase: s = ½ a t1² + v_peak (t − t1)
        s = 0.5 * p->a_max * p->t_accel * p->t_accel
          + p->v_peak * (t - p->t_accel);
    } else {
        // Decel phase: t' = t_total − t
        double tp = p->t_total - t;
        s = p->L - 0.5 * p->a_max * tp * tp;
    }
    return _f2i(s);
}

long long nuc_topp_trap_velocity(long long h, long long t_b) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0 || t >= p->t_total) return _f2i(0.0);
    if (t <= p->t_accel) return _f2i(p->a_max * t);
    if (t <= p->t_accel + p->t_cruise) return _f2i(p->v_peak);
    return _f2i(p->a_max * (p->t_total - t));
}

long long nuc_topp_trap_acceleration(long long h, long long t_b) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0 || t >= p->t_total) return _f2i(0.0);
    if (t < p->t_accel) return _f2i(p->a_max);
    if (t < p->t_accel + p->t_cruise) return _f2i(0.0);
    return _f2i(-p->a_max);
}

void nuc_topp_trap_free(long long h) {
    NTOPP *p = (NTOPP *)(void *)(size_t)h;
    if (!p) return;
    free(p);
}
