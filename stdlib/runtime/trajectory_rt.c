// trajectory_rt.c — Smooth time-parameterized trajectories.
//
// Quintic (5th order) polynomial joint trajectory: given start
// position + velocity + acceleration and goal position + velocity +
// acceleration over duration T, produce
//
//   q(t)  = a0 + a1·t + a2·t² + a3·t³ + a4·t⁴ + a5·t⁵
//   q'(t) =      a1   + 2·a2·t + 3·a3·t² + 4·a4·t³ + 5·a5·t⁴
//   q''(t)=             2·a2   + 6·a3·t  +12·a4·t² +20·a5·t³
//
// The 6 coefficients are uniquely determined by the 6 boundary
// conditions (q,q',q'' at t=0 and t=T). Smooth at endpoints —
// good for actuator-limited systems.
//
// Trapezoidal velocity profiles, S-curves, and DMPs (dynamic
// movement primitives) ship in v0.5 alongside the URDF integration.
//
// Compile: clang -c stdlib/runtime/trajectory_rt.c -o target/traj.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double T;
    double a[6]; // a0..a5
} NQuintic;

// Build a quintic from boundary conditions. All position / velocity /
// acceleration values cross the FFI as i64-bit-cast doubles.
//
// Returns a handle to a heap-allocated NQuintic. Caller frees with
// nuc_quintic_free.
long long nuc_quintic_new(
    long long T_bits,
    long long q0_bits, long long v0_bits, long long a0_bits,
    long long qT_bits, long long vT_bits, long long aT_bits)
{
    double T = _i2f(T_bits);
    if (T <= 0.0) return 0;
    double q0 = _i2f(q0_bits), v0 = _i2f(v0_bits), a0 = _i2f(a0_bits);
    double qT = _i2f(qT_bits), vT = _i2f(vT_bits), aT = _i2f(aT_bits);
    NQuintic *q = (NQuintic *)malloc(sizeof(NQuintic));
    q->T = T;
    // Closed-form coefficients (e.g. Lynch & Park, Modern Robotics, Eq. 9.2).
    double T2 = T*T, T3 = T2*T, T4 = T3*T, T5 = T4*T;
    q->a[0] = q0;
    q->a[1] = v0;
    q->a[2] = 0.5 * a0;
    q->a[3] = (20*(qT - q0) - (8*vT + 12*v0)*T - (3*aT - a0)*T2) / (2*T3);
    q->a[4] = (30*(q0 - qT) + (14*vT + 16*v0)*T + (3*aT - 2*a0)*T2) / (2*T4);
    q->a[5] = (12*(qT - q0) - 6*(vT + v0)*T + (aT - a0)*T2) / (2*T5);
    return (long long)(size_t)q;
}

long long nuc_quintic_duration(long long h) {
    NQuintic *q = (NQuintic *)(void *)(size_t)h;
    if (!q) return 0;
    return _f2i(q->T);
}

// Sample the position at time t (clamped to [0, T]).
long long nuc_quintic_pos_at(long long h, long long t_bits) {
    NQuintic *q = (NQuintic *)(void *)(size_t)h;
    if (!q) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > q->T) t = q->T;
    double t2 = t*t, t3 = t2*t, t4 = t3*t, t5 = t4*t;
    return _f2i(q->a[0] + q->a[1]*t + q->a[2]*t2 + q->a[3]*t3 + q->a[4]*t4 + q->a[5]*t5);
}

// Sample the velocity at time t.
long long nuc_quintic_vel_at(long long h, long long t_bits) {
    NQuintic *q = (NQuintic *)(void *)(size_t)h;
    if (!q) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > q->T) t = q->T;
    double t2 = t*t, t3 = t2*t, t4 = t3*t;
    return _f2i(q->a[1] + 2*q->a[2]*t + 3*q->a[3]*t2 + 4*q->a[4]*t3 + 5*q->a[5]*t4);
}

// Sample the acceleration at time t.
long long nuc_quintic_acc_at(long long h, long long t_bits) {
    NQuintic *q = (NQuintic *)(void *)(size_t)h;
    if (!q) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > q->T) t = q->T;
    double t2 = t*t, t3 = t2*t;
    return _f2i(2*q->a[2] + 6*q->a[3]*t + 12*q->a[4]*t2 + 20*q->a[5]*t3);
}

void nuc_quintic_free(long long h) {
    NQuintic *q = (NQuintic *)(void *)(size_t)h;
    if (q) free(q);
}

// === Trapezoidal velocity profile (v0.2.181) ============================
//
// Three-phase profile: constant acceleration, constant velocity (cruise),
// constant deceleration. Solves for the actual reachable peak velocity
// when the displacement is too small to reach the requested v_max
// (collapses to a triangular profile in that case).
//
// Inputs: q0, qT (start + goal position), v_max, a_max (limits).
// Output: a heap-allocated NTrapezoid with the resolved (T_acc, T_cruise,
// T_dec, peak_v) timing.

typedef struct {
    double q0;
    double dir;          // +1 or -1
    double v_peak;       // actual reachable peak velocity
    double a;            // |acceleration|
    double t_acc;        // duration of accel phase
    double t_cruise;     // duration of constant-v phase
    double t_dec;        // duration of decel phase
    double T;            // total = t_acc + t_cruise + t_dec
} NTrapezoid;

long long nuc_trapezoid_new(
    long long q0_bits, long long qT_bits,
    long long vmax_bits, long long amax_bits)
{
    double q0 = _i2f(q0_bits), qT = _i2f(qT_bits);
    double v_max = fabs(_i2f(vmax_bits));
    double a_max = fabs(_i2f(amax_bits));
    if (v_max <= 0 || a_max <= 0) return 0;
    double dq = qT - q0;
    double dir = (dq >= 0) ? 1.0 : -1.0;
    double dist = fabs(dq);
    NTrapezoid *p = (NTrapezoid *)malloc(sizeof(NTrapezoid));
    p->q0 = q0;
    p->dir = dir;
    p->a = a_max;
    // Distance covered while ramping from 0 to v_max and back: 2 * (v_max² / (2 a_max)) = v_max²/a_max.
    double ramp_dist = (v_max * v_max) / a_max;
    if (dist >= ramp_dist) {
        // Trapezoid: full v_max reached.
        p->v_peak = v_max;
        p->t_acc = v_max / a_max;
        p->t_dec = p->t_acc;
        p->t_cruise = (dist - ramp_dist) / v_max;
    } else {
        // Triangular: peak v < v_max.
        p->v_peak = sqrt(dist * a_max);
        p->t_acc = p->v_peak / a_max;
        p->t_dec = p->t_acc;
        p->t_cruise = 0.0;
    }
    p->T = p->t_acc + p->t_cruise + p->t_dec;
    return (long long)(size_t)p;
}

long long nuc_trapezoid_duration(long long h) {
    NTrapezoid *p = (NTrapezoid *)(void *)(size_t)h;
    return p ? _f2i(p->T) : 0;
}

long long nuc_trapezoid_peak_v(long long h) {
    NTrapezoid *p = (NTrapezoid *)(void *)(size_t)h;
    return p ? _f2i(p->v_peak * p->dir) : 0;
}

long long nuc_trapezoid_pos_at(long long h, long long t_bits) {
    NTrapezoid *p = (NTrapezoid *)(void *)(size_t)h;
    if (!p) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > p->T) t = p->T;
    double s; // signed displacement from q0
    if (t <= p->t_acc) {
        s = 0.5 * p->a * t * t;
    } else if (t <= p->t_acc + p->t_cruise) {
        double s_acc = 0.5 * p->a * p->t_acc * p->t_acc;
        s = s_acc + p->v_peak * (t - p->t_acc);
    } else {
        double s_acc = 0.5 * p->a * p->t_acc * p->t_acc;
        double s_cruise = p->v_peak * p->t_cruise;
        double tt = t - p->t_acc - p->t_cruise;
        s = s_acc + s_cruise + p->v_peak * tt - 0.5 * p->a * tt * tt;
    }
    return _f2i(p->q0 + p->dir * s);
}

long long nuc_trapezoid_vel_at(long long h, long long t_bits) {
    NTrapezoid *p = (NTrapezoid *)(void *)(size_t)h;
    if (!p) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > p->T) t = p->T;
    double v;
    if (t <= p->t_acc) {
        v = p->a * t;
    } else if (t <= p->t_acc + p->t_cruise) {
        v = p->v_peak;
    } else {
        v = p->v_peak - p->a * (t - p->t_acc - p->t_cruise);
    }
    return _f2i(p->dir * v);
}

void nuc_trapezoid_free(long long h) {
    NTrapezoid *p = (NTrapezoid *)(void *)(size_t)h;
    if (p) free(p);
}
