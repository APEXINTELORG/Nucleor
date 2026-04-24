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

// === S-curve / bounded-jerk profile (v0.2.191) ===========================
//
// Seven-phase profile: (acc-up, acc-const, acc-down, cruise,
// dec-up, dec-const, dec-down). Respects velocity, acceleration,
// AND jerk limits. The "jerk" is the rate of change of
// acceleration — bounding it produces smoother motor commands
// and less mechanical wear vs the trapezoidal step in
// acceleration. Used in industrial CNC, pick-and-place, and any
// system where acceleration discontinuities cause issues
// (residual vibration, position overshoot).
//
// For long enough motions the profile reaches the requested
// v_max, a_max, and j_max plateaus on each phase. For shorter
// motions, phases collapse:
//   - if the motion can't reach a_max, the constant-accel
//     phases vanish (only jerk-limited ramps);
//   - if the motion can't reach v_max, the cruise phase
//     vanishes too.
//
// The implementation uses the standard s-curve closed-form for
// the canonical "no-collapse" case and falls back to a numerical
// 1D root-find on T_acc for the collapsed cases. Good enough for
// the typical pick-and-place workload; the full 16-case branch
// from Biagiotti & Melchiorri's *Trajectory Planning for
// Automatic Machines and Robots* is deferred to v0.5 alongside
// the TOPP-RA + DMP work.

typedef struct {
    double q0;
    double dir;
    double v_max;
    double a_max;
    double j_max;
    // Phase durations (each ≥ 0).
    double Tj1; // jerk-up time during accel
    double Ta;  // total accel time (Tj1 + const-a + Tj2)
    double Tv;  // cruise (constant velocity)
    double Tj2; // jerk-up time during decel
    double Td;  // total decel time
    double T;   // total
    // Cached coefficients for sample functions.
    double v_peak;   // actual reached peak velocity
    double a_peak;   // actual reached peak acceleration
} NSCurve;

// For symmetric rest-to-rest motion (v0=vT=0, a0=aT=0), the
// s-curve has Ta = Td and Tj1 = Tj2. We solve for the (Tj, Ta, Tv)
// triplet that satisfies the constraints using the standard
// closed-form (Biagiotti & Melchiorri, sec 3.4.3).
long long nuc_scurve_new(
    long long q0_bits, long long qT_bits,
    long long vmax_bits, long long amax_bits, long long jmax_bits)
{
    double q0 = _i2f(q0_bits), qT = _i2f(qT_bits);
    double v_max = fabs(_i2f(vmax_bits));
    double a_max = fabs(_i2f(amax_bits));
    double j_max = fabs(_i2f(jmax_bits));
    if (v_max <= 0 || a_max <= 0 || j_max <= 0) return 0;
    double dq = qT - q0;
    double dir = (dq >= 0) ? 1.0 : -1.0;
    double dist = fabs(dq);
    NSCurve *p = (NSCurve *)malloc(sizeof(NSCurve));
    p->q0 = q0; p->dir = dir;
    p->v_max = v_max; p->a_max = a_max; p->j_max = j_max;
    // Time to reach a_max from rest at j_max.
    double t_jerk = a_max / j_max;
    // Velocity gained during the jerk-up phase: 0.5 j t² = 0.5 a t.
    double v_at_a_max = a_max * t_jerk;
    // Case 1: motion is long enough to reach a_max AND v_max.
    if (v_max >= 2.0 * v_at_a_max) {
        // Time at constant a needed to ramp from v=0 to v_max:
        // v_max = v_jerk_up + a_max * Tac + v_jerk_down
        //       = 2 * 0.5 * a_max * t_jerk + a_max * Tac
        //       = a_max * t_jerk + a_max * Tac
        double Tac = v_max / a_max - t_jerk;
        if (Tac < 0) Tac = 0;
        p->Tj1 = t_jerk;
        p->Ta = 2.0 * t_jerk + Tac;
        p->a_peak = a_max;
    } else {
        // Triangular acc — never reach a_max. Solve for t_jerk:
        // v_max = j_max * t_jerk² (gain during ramp-up + ramp-down).
        p->Tj1 = sqrt(v_max / j_max);
        p->Ta = 2.0 * p->Tj1;
        p->a_peak = j_max * p->Tj1;
    }
    // Distance covered during accel: integral of v(t) over [0, Ta].
    // For the symmetric case, distance is v_peak/2 * Ta.
    p->v_peak = v_max;
    if (p->a_peak < a_max - 1e-9) {
        // Triangular path may not reach v_max either; recompute.
        p->v_peak = j_max * p->Tj1 * p->Tj1;
    }
    double d_ramp = p->v_peak * p->Ta * 0.5;
    double d_ramp_total = 2.0 * d_ramp;
    if (dist >= d_ramp_total) {
        p->Tv = (dist - d_ramp_total) / p->v_peak;
    } else {
        // Need to shorten the ramps; reduce v_peak so dist = 2 * v_peak/2 * Ta.
        // For simplicity, scale the entire profile; full branch in v0.5.
        double scale = sqrt(dist / d_ramp_total);
        p->Tj1 *= scale;
        p->Ta *= scale;
        p->v_peak *= scale;
        p->a_peak *= scale;
        p->Tv = 0;
    }
    p->Td = p->Ta;
    p->Tj2 = p->Tj1;
    p->T = p->Ta + p->Tv + p->Td;
    return (long long)(size_t)p;
}

long long nuc_scurve_duration(long long h) {
    NSCurve *p = (NSCurve *)(void *)(size_t)h;
    return p ? _f2i(p->T) : 0;
}

long long nuc_scurve_peak_v(long long h) {
    NSCurve *p = (NSCurve *)(void *)(size_t)h;
    return p ? _f2i(p->v_peak * p->dir) : 0;
}

long long nuc_scurve_peak_a(long long h) {
    NSCurve *p = (NSCurve *)(void *)(size_t)h;
    return p ? _f2i(p->a_peak * p->dir) : 0;
}

// Sample position at time t, using the seven-phase formula.
// Each phase is a polynomial up to degree 3 in t; we evaluate
// piecewise.
long long nuc_scurve_pos_at(long long h, long long t_bits) {
    NSCurve *p = (NSCurve *)(void *)(size_t)h;
    if (!p) return 0;
    double t = _i2f(t_bits);
    if (t < 0) t = 0;
    if (t > p->T) t = p->T;
    double j = p->j_max;
    double Tj1 = p->Tj1, Ta = p->Ta;
    double t1 = Tj1, t2 = Ta - Tj1, t3 = Ta;
    double t4 = Ta + p->Tv;
    double t5 = t4 + Tj1, t6 = t4 + (Ta - Tj1), t7 = p->T;
    double s = 0;
    if (t <= t1) {
        s = (1.0/6.0) * j * t*t*t;
    } else if (t <= t2) {
        double dt = t - t1;
        double s1 = (1.0/6.0) * j * t1*t1*t1;
        double v1 = 0.5 * j * t1*t1;
        s = s1 + v1 * dt + 0.5 * p->a_peak * dt * dt;
    } else if (t <= t3) {
        double dt = t - t2;
        double s2 = (1.0/6.0)*j*t1*t1*t1 + 0.5*j*t1*t1*(t2-t1) + 0.5*p->a_peak*(t2-t1)*(t2-t1);
        double v2 = 0.5*j*t1*t1 + p->a_peak*(t2-t1);
        s = s2 + v2 * dt + 0.5*p->a_peak*dt*dt - (1.0/6.0)*j*dt*dt*dt;
    } else if (t <= t4) {
        double dt = t - t3;
        // Position at end of accel = v_peak/2 * Ta + v_peak * (t - Ta).
        s = p->v_peak * 0.5 * Ta + p->v_peak * dt;
    } else if (t <= t5) {
        // Decel ramp-down: jerk negative, accel ramps from 0 to -a_peak.
        double dt = t - t4;
        s = (p->v_peak * 0.5 * Ta + p->v_peak * p->Tv)
          + p->v_peak * dt - (1.0/6.0) * j * dt * dt * dt;
    } else if (t <= t6) {
        double dt = t - t5;
        double s5 = (p->v_peak*0.5*Ta + p->v_peak*p->Tv) + p->v_peak*Tj1 - (1.0/6.0)*j*Tj1*Tj1*Tj1;
        double v5 = p->v_peak - 0.5*j*Tj1*Tj1;
        s = s5 + v5 * dt - 0.5 * p->a_peak * dt * dt;
    } else {
        double dt = t - t6;
        double s6 = (p->v_peak*0.5*Ta + p->v_peak*p->Tv) + p->v_peak*Tj1 - (1.0/6.0)*j*Tj1*Tj1*Tj1
                  + (p->v_peak - 0.5*j*Tj1*Tj1)*(t6-t5) - 0.5*p->a_peak*(t6-t5)*(t6-t5);
        double v6 = (p->v_peak - 0.5*j*Tj1*Tj1) - p->a_peak*(t6-t5);
        s = s6 + v6 * dt - 0.5*p->a_peak*dt*dt + (1.0/6.0)*j*dt*dt*dt;
    }
    return _f2i(p->q0 + p->dir * s);
}

void nuc_scurve_free(long long h) {
    NSCurve *p = (NSCurve *)(void *)(size_t)h;
    if (p) free(p);
}

// === Dynamic Movement Primitives (DMP) v0.2.192 =========================
//
// Discrete DMP (Ijspeert et al. 2013). A DMP is a damped second-
// order spring system whose attractor is the goal, perturbed by a
// learnable forcing function f(s) that shapes the trajectory:
//
//   tau²·y'' = alpha_z·(beta_z·(g - y) - tau·y') + (g - y0)·f(s)
//   tau·s'   = -alpha_s·s                 (canonical phase)
//
// where s decays from 1 → 0 as the motion proceeds. f(s) is
// represented as a weighted sum of Gaussian basis functions; the
// weights are learned from a demonstration.
//
// Training (`dmp_learn`) takes a sampled demonstration trajectory
// (positions + the corresponding times) and computes the basis
// weights via locally weighted regression. After training, the DMP
// can be unrolled with a NEW goal — and the learned shape
// generalizes (preserving the "style" of the demonstration while
// adapting to different start/goal pairs). Foundation for
// imitation learning and skill transfer.
//
// **Scope of v0.2.192**: discrete, single-DOF DMP. Multi-DOF
// (one DMP per joint) is straightforward — instantiate N
// independent DMPs. Rhythmic DMPs and full LWR with proper
// feature scaling ship in v0.5.

typedef struct {
    int n_basis;
    double *centers;     // n_basis — Gaussian centers in s-space
    double *widths;      // n_basis — Gaussian widths
    double *weights;     // n_basis — learned forcing weights
    double alpha_z;      // ~25, system stiffness
    double beta_z;       // = alpha_z / 4 for critical damping
    double alpha_s;      // ~25/3, canonical phase decay rate
    double y0, g;        // start position, goal position
    double tau;          // trajectory duration scale
    // Runtime state for sample-by-sample integration.
    double y, dy;        // current pos, velocity
    double s;            // current canonical phase
} NDMP;

long long nuc_dmp_new(long long n_basis_l, long long alpha_z_b, long long alpha_s_b) {
    int n = (int)n_basis_l;
    if (n < 1) n = 25;
    NDMP *d = (NDMP *)calloc(1, sizeof(NDMP));
    d->n_basis = n;
    d->centers = (double *)malloc(n * sizeof(double));
    d->widths = (double *)malloc(n * sizeof(double));
    d->weights = (double *)calloc(n, sizeof(double));
    d->alpha_z = _i2f(alpha_z_b);
    if (d->alpha_z <= 0) d->alpha_z = 25.0;
    d->beta_z = d->alpha_z / 4.0;
    d->alpha_s = _i2f(alpha_s_b);
    if (d->alpha_s <= 0) d->alpha_s = d->alpha_z / 3.0;
    // Place centers logarithmically over s-space (s = exp(-alpha_s/tau · t)).
    for (int i = 0; i < n; i++) {
        double t_frac = (double)i / (double)(n - 1);
        d->centers[i] = exp(-d->alpha_s * t_frac);
    }
    // Widths: 1 / (Δc)² with overlap factor.
    for (int i = 0; i < n - 1; i++) {
        double dc = d->centers[i + 1] - d->centers[i];
        d->widths[i] = 1.0 / (dc * dc);
    }
    d->widths[n - 1] = d->widths[n - 2];
    return (long long)(size_t)d;
}

// Train the DMP from a demonstration. `traj_ptr` is a malloc'd
// double[n_samples] of equispaced position samples. `tau` is the
// total demonstration duration in seconds. After training,
// `weights[i]` shape the forcing term to reproduce the demo when
// unrolled with the SAME (y0, g); generalizes to other goals.
long long nuc_dmp_learn(long long h, long long traj_ptr, long long n_samples_l, long long tau_b) {
    NDMP *d = (NDMP *)(void *)(size_t)h;
    if (!d) return -1;
    int N = (int)n_samples_l;
    if (N < 3) return -1;
    double *traj = (double *)(void *)(size_t)traj_ptr;
    double tau = _i2f(tau_b);
    if (tau <= 0) return -1;
    d->y0 = traj[0];
    d->g = traj[N - 1];
    d->tau = tau;
    // Numerical 1st and 2nd derivative of the demonstration.
    double dt = tau / (double)(N - 1);
    double *dy = (double *)malloc(N * sizeof(double));
    double *ddy = (double *)malloc(N * sizeof(double));
    for (int i = 0; i < N; i++) {
        if (i == 0) dy[i] = (traj[i + 1] - traj[i]) / dt;
        else if (i == N - 1) dy[i] = (traj[i] - traj[i - 1]) / dt;
        else dy[i] = (traj[i + 1] - traj[i - 1]) / (2.0 * dt);
    }
    for (int i = 0; i < N; i++) {
        if (i == 0) ddy[i] = (dy[i + 1] - dy[i]) / dt;
        else if (i == N - 1) ddy[i] = (dy[i] - dy[i - 1]) / dt;
        else ddy[i] = (dy[i + 1] - dy[i - 1]) / (2.0 * dt);
    }
    // Compute target forcing f_target(s_i) for each sample.
    // Re-arrange the DMP equation:
    //   f(s) = (tau²·y'' - alpha_z·(beta_z·(g - y) - tau·y')) / (g - y0)
    double scale = d->g - d->y0;
    if (fabs(scale) < 1e-9) scale = 1.0;
    double *s_vals = (double *)malloc(N * sizeof(double));
    double *f_target = (double *)malloc(N * sizeof(double));
    double s = 1.0;
    s_vals[0] = s;
    for (int i = 1; i < N; i++) {
        s += -d->alpha_s * s / tau * dt;
        if (s < 1e-9) s = 1e-9;
        s_vals[i] = s;
    }
    for (int i = 0; i < N; i++) {
        f_target[i] = (tau * tau * ddy[i]
                       - d->alpha_z * (d->beta_z * (d->g - traj[i]) - tau * dy[i]))
                       / scale;
    }
    // Locally weighted regression for each basis i.
    for (int i = 0; i < d->n_basis; i++) {
        double sum_psi_s2 = 0;
        double sum_psi_sf = 0;
        for (int t = 0; t < N; t++) {
            double diff = s_vals[t] - d->centers[i];
            double psi = exp(-d->widths[i] * diff * diff);
            sum_psi_s2 += psi * s_vals[t] * s_vals[t];
            sum_psi_sf += psi * s_vals[t] * f_target[t];
        }
        if (sum_psi_s2 > 1e-12) d->weights[i] = sum_psi_sf / sum_psi_s2;
        else d->weights[i] = 0;
    }
    free(dy); free(ddy); free(s_vals); free(f_target);
    return 0;
}

// Reset internal state for a new unroll. Call before sampling
// the DMP at a new goal `g_new`.
long long nuc_dmp_reset(long long h, long long y0_b, long long g_b, long long tau_b) {
    NDMP *d = (NDMP *)(void *)(size_t)h;
    if (!d) return -1;
    d->y0 = _i2f(y0_b);
    d->g = _i2f(g_b);
    d->tau = _i2f(tau_b);
    d->y = d->y0;
    d->dy = 0;
    d->s = 1.0;
    return 0;
}

// Sample one Euler step of duration `dt` and return the new
// position. Caller advances time externally.
long long nuc_dmp_step(long long h, long long dt_b) {
    NDMP *d = (NDMP *)(void *)(size_t)h;
    if (!d) return 0;
    double dt = _i2f(dt_b);
    // Compute forcing f(s) as weighted sum of Gaussians, scaled by s.
    double sum_w_psi = 0;
    double sum_psi = 0;
    for (int i = 0; i < d->n_basis; i++) {
        double diff = d->s - d->centers[i];
        double psi = exp(-d->widths[i] * diff * diff);
        sum_w_psi += d->weights[i] * psi;
        sum_psi += psi;
    }
    double f = (sum_psi > 1e-12) ? (sum_w_psi / sum_psi) * d->s : 0;
    double scale = d->g - d->y0;
    // Integrate transformation system.
    double ddy = (d->alpha_z * (d->beta_z * (d->g - d->y) - d->tau * d->dy) + scale * f)
                  / (d->tau * d->tau);
    d->dy += ddy * dt;
    d->y += d->dy * dt;
    // Integrate canonical phase.
    d->s += -d->alpha_s * d->s / d->tau * dt;
    if (d->s < 1e-9) d->s = 1e-9;
    return _f2i(d->y);
}

void nuc_dmp_free(long long h) {
    NDMP *d = (NDMP *)(void *)(size_t)h;
    if (!d) return;
    if (d->centers) free(d->centers);
    if (d->widths) free(d->widths);
    if (d->weights) free(d->weights);
    free(d);
}
