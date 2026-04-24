// scurve_rt.c — Jerk-limited (7-phase) s-curve time-parameterization
// for an arc-length path.
//
// Production-grade motion-control profile. Where `topp.nr`'s
// trapezoidal profile bounds velocity + acceleration, this rod
// additionally bounds jerk — eliminating the δ-spike acceleration
// jumps that cause robot lurching, vibration, and reduced lifetime
// of joints.
//
// Algorithm (rest-to-rest, symmetric profile):
//
//   Phases (jerk j is constant within each):
//     1. j = +j_max       a:0 → a_max          duration T_j = a_max / j_max
//     2. j = 0           a = a_max constant     duration T_a − 2·T_j
//     3. j = −j_max       a: a_max → 0         duration T_j
//     4. j = 0           cruise at v_max         duration T_v
//     5. j = −j_max       a: 0 → −a_max        duration T_j
//     6. j = 0           a = −a_max constant     duration T_a − 2·T_j
//     7. j = +j_max       a: −a_max → 0        duration T_j
//
// where
//
//   T_a = T_j + v_max / a_max          (accel phase total duration)
//   T_v = L / v_max − T_a               (cruise duration)
//   T_total = 2·T_a + T_v
//
// Distance during accel = ½ · v_max · T_a (area of the trapezoidal
// velocity profile, which is what the s-curve produces at the
// velocity level).
//
// **Limitations** (degenerate cases / asymmetric / online retiming
// land in v0.6 if needed):
// - **Requires the FULL 7-phase profile** — both v_max and a_max
//   must be reached. If `T_v < 0` or `T_a < 2·T_j`, the trajectory
//   would need a degenerate variant (no cruise, or no a_max
//   plateau). Returns 0 from `scurve_new` in that case; the caller
//   should fall back to `topp.nr`'s trapezoidal profile or scale
//   down v_max / a_max.
// - Symmetric (accel = decel limits).
// - Rest-to-rest only (no nonzero start/end velocities).
//
// Compile: clang -c stdlib/runtime/scurve_rt.c -o target/scurve.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double L, v_max, a_max, j_max;
    double T_j;            // accel ramp duration
    double T_a;            // total accel-phase duration
    double T_v;            // cruise duration
    double T_total;
    // Phase boundaries in absolute time:
    double t1, t2, t3, t4, t5, t6, t7;
    // State at the END of each phase (cached for fast eval):
    double s1, s2, s3, s4, s5, s6;     // position
    double v1, v2, v3, v4, v5, v6;     // velocity
    double a1, a2, a3;                  // accel (a3 = 0 = a4 = a7 since phase 4 has zero accel; a5 = 0 too at boundary; etc.)
} NSCURVE;

long long nuc_scurve_new(long long L_b, long long v_max_b, long long a_max_b, long long j_max_b) {
    double L     = _i2f(L_b);
    double v_max = _i2f(v_max_b);
    double a_max = _i2f(a_max_b);
    double j_max = _i2f(j_max_b);
    if (L <= 0 || v_max <= 0 || a_max <= 0 || j_max <= 0) return 0;

    double T_j = a_max / j_max;
    // Full plateau requires v_max ≥ a_max · T_j  ⇔ v_max ≥ a_max² / j_max.
    if (v_max < a_max * T_j - 1e-12) return 0;

    double T_a = T_j + v_max / a_max;       // accel phase duration

    // Distance during accel = ½·v_max·T_a (area under trapezoidal v profile).
    double d_accel = 0.5 * v_max * T_a;
    if (2.0 * d_accel > L + 1e-12) return 0;

    double T_v = (L - 2.0 * d_accel) / v_max;
    double T_total = 2.0 * T_a + T_v;

    NSCURVE *p = (NSCURVE *)calloc(1, sizeof(NSCURVE));
    p->L = L; p->v_max = v_max; p->a_max = a_max; p->j_max = j_max;
    p->T_j = T_j; p->T_a = T_a; p->T_v = T_v; p->T_total = T_total;

    // Phase boundaries:
    p->t1 = T_j;
    p->t2 = T_a - T_j;
    p->t3 = T_a;
    p->t4 = T_a + T_v;
    p->t5 = p->t4 + T_j;
    p->t6 = p->t4 + (T_a - T_j);
    p->t7 = T_total;

    // Cache state at end of each phase (closed-form integration).
    // Phase 1 end (t = T_j): a = a_max, v = ½·a_max·T_j, s = (1/6)·j·T_j³ = ½·a_max·T_j²/3·... let me redo.
    //   j = +j_max, starting from a=0, v=0, s=0.
    //   a(τ) = j_max·τ
    //   v(τ) = ½·j_max·τ²
    //   s(τ) = (1/6)·j_max·τ³
    p->a1 = j_max * T_j;                // = a_max
    p->v1 = 0.5 * j_max * T_j * T_j;     // = ½·a_max·T_j
    p->s1 = (1.0/6.0) * j_max * T_j * T_j * T_j;

    // Phase 2 (constant a = a_max, duration T_a - 2·T_j):
    //   a stays a_max
    //   v(τ) = v1 + a_max·τ
    //   s(τ) = s1 + v1·τ + ½·a_max·τ²
    double T2 = T_a - 2.0 * T_j;
    p->a2 = a_max;
    p->v2 = p->v1 + a_max * T2;
    p->s2 = p->s1 + p->v1 * T2 + 0.5 * a_max * T2 * T2;

    // Phase 3 (j = -j_max, duration T_j):
    //   a(τ) = a_max - j_max·τ → 0 at τ = T_j
    //   v(τ) = v2 + a_max·τ - ½·j_max·τ²
    //   s(τ) = s2 + v2·τ + ½·a_max·τ² - (1/6)·j_max·τ³
    p->a3 = 0.0;
    p->v3 = p->v2 + a_max * T_j - 0.5 * j_max * T_j * T_j;     // = v_max
    p->s3 = p->s2 + p->v2 * T_j + 0.5 * a_max * T_j * T_j
                  - (1.0/6.0) * j_max * T_j * T_j * T_j;

    // Phase 4 (cruise, duration T_v):
    p->v4 = p->v3;
    p->s4 = p->s3 + p->v3 * T_v;

    // Phase 5 (j = -j_max, mirror of phase 1 starting from v_max):
    //   a(τ) = -j_max·τ
    //   v(τ) = v_max - ½·j_max·τ²
    //   s(τ) = s4 + v_max·τ - (1/6)·j_max·τ³
    p->v5 = p->v4 - 0.5 * j_max * T_j * T_j;
    p->s5 = p->s4 + p->v4 * T_j - (1.0/6.0) * j_max * T_j * T_j * T_j;

    // Phase 6 (constant a = -a_max, duration T2):
    p->v6 = p->v5 - a_max * T2;
    p->s6 = p->s5 + p->v5 * T2 - 0.5 * a_max * T2 * T2;

    // Phase 7 (j = +j_max, mirror of phase 3 ending at v=0, s=L)
    // s_end should equal L, v_end = 0; verified by symmetry.

    return (long long)(size_t)p;
}

long long nuc_scurve_total_time(long long h) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    return p ? _f2i(p->T_total) : _f2i(0.0);
}
long long nuc_scurve_path_length(long long h) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    return p ? _f2i(p->L) : _f2i(0.0);
}

long long nuc_scurve_position(long long h, long long t_b) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0)        return _f2i(0.0);
    if (t >= p->T_total) return _f2i(p->L);

    if (t <= p->t1) {
        double tau = t;
        return _f2i((1.0/6.0) * p->j_max * tau * tau * tau);
    }
    if (t <= p->t2) {
        double tau = t - p->t1;
        return _f2i(p->s1 + p->v1 * tau + 0.5 * p->a_max * tau * tau);
    }
    if (t <= p->t3) {
        double tau = t - p->t2;
        return _f2i(p->s2 + p->v2 * tau + 0.5 * p->a_max * tau * tau
                    - (1.0/6.0) * p->j_max * tau * tau * tau);
    }
    if (t <= p->t4) {
        double tau = t - p->t3;
        return _f2i(p->s3 + p->v3 * tau);
    }
    if (t <= p->t5) {
        double tau = t - p->t4;
        return _f2i(p->s4 + p->v4 * tau - (1.0/6.0) * p->j_max * tau * tau * tau);
    }
    if (t <= p->t6) {
        double tau = t - p->t5;
        return _f2i(p->s5 + p->v5 * tau - 0.5 * p->a_max * tau * tau);
    }
    // Phase 7
    double tau = t - p->t6;
    return _f2i(p->s6 + p->v6 * tau - 0.5 * p->a_max * tau * tau
                + (1.0/6.0) * p->j_max * tau * tau * tau);
}

long long nuc_scurve_velocity(long long h, long long t_b) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0 || t >= p->T_total) return _f2i(0.0);

    if (t <= p->t1)      return _f2i(0.5 * p->j_max * t * t);
    if (t <= p->t2) {
        double tau = t - p->t1;
        return _f2i(p->v1 + p->a_max * tau);
    }
    if (t <= p->t3) {
        double tau = t - p->t2;
        return _f2i(p->v2 + p->a_max * tau - 0.5 * p->j_max * tau * tau);
    }
    if (t <= p->t4) return _f2i(p->v3);
    if (t <= p->t5) {
        double tau = t - p->t4;
        return _f2i(p->v4 - 0.5 * p->j_max * tau * tau);
    }
    if (t <= p->t6) {
        double tau = t - p->t5;
        return _f2i(p->v5 - p->a_max * tau);
    }
    double tau = t - p->t6;
    return _f2i(p->v6 - p->a_max * tau + 0.5 * p->j_max * tau * tau);
}

long long nuc_scurve_acceleration(long long h, long long t_b) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0 || t >= p->T_total) return _f2i(0.0);

    if (t <= p->t1) return _f2i(p->j_max * t);
    if (t <= p->t2) return _f2i(p->a_max);
    if (t <= p->t3) {
        double tau = t - p->t2;
        return _f2i(p->a_max - p->j_max * tau);
    }
    if (t <= p->t4) return _f2i(0.0);
    if (t <= p->t5) {
        double tau = t - p->t4;
        return _f2i(-p->j_max * tau);
    }
    if (t <= p->t6) return _f2i(-p->a_max);
    double tau = t - p->t6;
    return _f2i(-p->a_max + p->j_max * tau);
}

long long nuc_scurve_jerk(long long h, long long t_b) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t <= 0 || t >= p->T_total) return _f2i(0.0);
    if (t < p->t1) return _f2i( p->j_max);
    if (t < p->t2) return _f2i(0.0);
    if (t < p->t3) return _f2i(-p->j_max);
    if (t < p->t4) return _f2i(0.0);
    if (t < p->t5) return _f2i(-p->j_max);
    if (t < p->t6) return _f2i(0.0);
    return _f2i( p->j_max);
}

void nuc_scurve_free(long long h) {
    NSCURVE *p = (NSCURVE *)(void *)(size_t)h;
    if (!p) return;
    free(p);
}
