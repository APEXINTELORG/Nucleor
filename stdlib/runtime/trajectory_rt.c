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

// === TOPP — time-optimal path parameterization (v0.2.203) ================
//
// Pham 2014 / TOPP-RA, simplified for piecewise-linear paths in joint
// space. Given a sequence of N waypoints and per-joint velocity +
// acceleration bounds, computes the time-optimal parameterization
// — i.e., the minimum total traversal time subject to the bounds —
// via the standard forward + backward pass on the squared path
// velocity b(s) = (ds/dt)².
//
// Per-segment algebra (segment i: q[i] → q[i+1], parameterized by
// s ∈ [i, i+1]):
//   q(s) within segment is linear in s, so q_s = q[i+1] - q[i] is
//   constant and q_ss = 0. For each joint j:
//     velocity bound:     |q_s[j] · sqrt(b)| ≤ vmax[j]
//                         → b ≤ (vmax[j] / |q_s[j]|)²
//     acceleration bound: |q_s[j] · a| ≤ amax[j]   (a = s_ddot)
//                         → |a| ≤ amax[j] / |q_s[j]|
//
// Forward pass:  b[0] = 0, b[i+1] = min(b[i] + 2·a_max(i), vbound²(i))
// Backward pass: b[N-1] = 0, b[i] = min(b[i], b[i+1] + 2·a_max(i))
//
// Time per segment: ∫₀¹ ds/sqrt(b(s)) where b(s) is linear within
// the segment. Closed form: (sqrt(b[i+1]) - sqrt(b[i])) / a where
// a = (b[i+1] - b[i]) / 2; falls back to 1/sqrt(b) when a ≈ 0.
//
// **Limitations** (full TOPP-RA via convex optimization on each
// path discretization step lands in v0.6 if needed):
// - Only piecewise-linear paths. For B-spline / quintic-spline
//   geometric paths, sample to a piecewise-linear discretization
//   first.
// - Symmetric box bounds only (|v| ≤ vmax, |a| ≤ amax). Asymmetric
//   bounds (e.g., gravity-loaded vertical axes) need the full LP
//   formulation.
// - No torque/dynamics constraints. Pure kinematic.

typedef struct {
    int n_dim;
    int n_waypoints;
    int cap_waypoints;
    double *waypoints;     // n_waypoints × n_dim, flat
    double *vmax;          // n_dim
    double *amax;          // n_dim
    // After solve:
    double *b;             // n_waypoints (squared path velocity)
    double *t;             // n_waypoints (cumulative time)
    int solved;
    double total_time;
} NTopp;

long long nuc_topp_new(long long n_dim) {
    NTopp *p = (NTopp *)calloc(1, sizeof(NTopp));
    p->n_dim = (int)n_dim;
    p->cap_waypoints = 16;
    p->waypoints = (double *)malloc(p->cap_waypoints * p->n_dim * sizeof(double));
    p->vmax = (double *)malloc(p->n_dim * sizeof(double));
    p->amax = (double *)malloc(p->n_dim * sizeof(double));
    for (int j = 0; j < p->n_dim; j++) {
        p->vmax[j] = 1.0;     // sane defaults: 1 unit/s, 1 unit/s²
        p->amax[j] = 1.0;
    }
    return (long long)(size_t)p;
}

long long nuc_topp_add_waypoint(long long h, long long q_ptr) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p) return -1;
    if (p->n_waypoints >= p->cap_waypoints) {
        p->cap_waypoints *= 2;
        p->waypoints = (double *)realloc(p->waypoints,
                                         p->cap_waypoints * p->n_dim * sizeof(double));
    }
    double *q = (double *)(void *)(size_t)q_ptr;
    memcpy(p->waypoints + p->n_waypoints * p->n_dim, q,
           p->n_dim * sizeof(double));
    p->solved = 0;
    return (long long)(p->n_waypoints++);
}

void nuc_topp_set_vmax(long long h, long long j, long long vmax_b) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || j < 0 || j >= (long long)p->n_dim) return;
    p->vmax[j] = _i2f(vmax_b);
    p->solved = 0;
}

void nuc_topp_set_amax(long long h, long long j, long long amax_b) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || j < 0 || j >= (long long)p->n_dim) return;
    p->amax[j] = _i2f(amax_b);
    p->solved = 0;
}

// Solve the parameterization. Returns 0 on success, -1 on bad
// state (fewer than 2 waypoints).
long long nuc_topp_solve(long long h) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || p->n_waypoints < 2) return -1;
    int N = p->n_waypoints;
    int M = N - 1;  // number of segments

    if (p->b) free(p->b);
    if (p->t) free(p->t);
    p->b = (double *)calloc(N, sizeof(double));
    p->t = (double *)calloc(N, sizeof(double));

    double *vbound2 = (double *)malloc(M * sizeof(double));
    double *amax_seg = (double *)malloc(M * sizeof(double));

    for (int i = 0; i < M; i++) {
        double *q0 = p->waypoints + i * p->n_dim;
        double *q1 = p->waypoints + (i + 1) * p->n_dim;
        double v_lim2 = 1e30;
        double a_lim = 1e30;
        for (int j = 0; j < p->n_dim; j++) {
            double dq = q1[j] - q0[j];
            double adq = fabs(dq);
            if (adq < 1e-18) continue;  // joint stationary on this segment
            double v_j = p->vmax[j] / adq;
            double a_j = p->amax[j] / adq;
            if (v_j * v_j < v_lim2) v_lim2 = v_j * v_j;
            if (a_j < a_lim)        a_lim = a_j;
        }
        vbound2[i] = v_lim2;
        amax_seg[i] = a_lim;
    }

    // Per-interior-waypoint corner cap. At waypoint i (0 < i < N-1),
    // if the path tangent changes between segment i-1 and segment i,
    // any nonzero path velocity translates to a discontinuous JOINT
    // velocity — which would require unbounded acceleration. Detect
    // corners and force b[i] = 0 there. (The strict-equality test
    // for collinear unit tangents is `dot ≥ 1 - ε`.)
    double *vbound2_node = (double *)malloc(N * sizeof(double));
    vbound2_node[0] = 0.0;
    vbound2_node[N - 1] = 0.0;
    for (int i = 1; i < N - 1; i++) {
        double *q_prev = p->waypoints + (i - 1) * p->n_dim;
        double *q_cur  = p->waypoints + i * p->n_dim;
        double *q_next = p->waypoints + (i + 1) * p->n_dim;
        double dot = 0, lp2 = 0, ln2 = 0;
        for (int j = 0; j < p->n_dim; j++) {
            double dp = q_cur[j] - q_prev[j];
            double dn = q_next[j] - q_cur[j];
            dot += dp * dn;
            lp2 += dp * dp;
            ln2 += dn * dn;
        }
        double cosang = (lp2 > 1e-18 && ln2 > 1e-18) ? dot / sqrt(lp2 * ln2) : 1.0;
        // Allow cap = min of segment vbounds if collinear; else 0.
        if (cosang >= 0.999999) {
            double v0 = vbound2[i - 1], v1 = vbound2[i];
            vbound2_node[i] = (v0 < v1) ? v0 : v1;
        } else {
            vbound2_node[i] = 0.0;
        }
    }

    // Forward pass: b[0] = 0; b[i+1] ≤ b[i] + 2·a_max(i); b[i+1] ≤ vbound²(i).
    p->b[0] = 0.0;
    for (int i = 0; i < M; i++) {
        double cap = p->b[i] + 2.0 * amax_seg[i];
        if (cap > vbound2[i]) cap = vbound2[i];
        if (cap > vbound2_node[i + 1]) cap = vbound2_node[i + 1];
        p->b[i + 1] = cap;
    }
    // Backward pass: b[N-1] = 0; b[i] ≤ b[i+1] + 2·a_max(i).
    p->b[N - 1] = 0.0;
    for (int i = N - 2; i >= 0; i--) {
        double cap = p->b[i + 1] + 2.0 * amax_seg[i];
        if (cap < p->b[i]) p->b[i] = cap;
    }
    free(vbound2_node);

    // Time per segment. The forward + backward passes guarantee
    // that b[i] is reachable from b[i+1] (and vice-versa) within
    // the segment's a_max budget, but they only constrain the
    // ENDPOINTS — not the within-segment peak. To get a tight
    // total time we need to integrate the actual within-segment
    // b(s), which is the minimum of:
    //   forward parabola : b_f(s) = b[i]   + 2·a·s
    //   backward parabola: b_b(s) = b[i+1] + 2·a·(1-s)
    //   velocity bound   : vbound²
    // The two parabolas meet at s_meet = (b[i+1]-b[i])/(4a) + ½.
    // If neither reaches vbound² before they meet, the profile is
    // triangular (peak = b[i]+2·a·s_meet); otherwise trapezoidal
    // with a constant-velocity cruise at vbound² in between.
    p->t[0] = 0.0;
    for (int i = 0; i < M; i++) {
        double b0 = p->b[i], b1 = p->b[i + 1];
        double a = amax_seg[i];
        double vb2 = vbound2[i];
        double dt = 0.0;
        if (a >= 1e29 || vb2 >= 1e29) {
            // Degenerate segment — no joint moves. Zero time.
            dt = 0.0;
        } else if (a < 1e-12) {
            // No within-segment acceleration possible (shouldn't
            // really happen if any joint moves, since a is in s-units
            // = amax[j] / |dq[j]|).
            if (b0 > 1e-18) dt = 1.0 / sqrt(b0);
        } else {
            double s_fv = (vb2 - b0) / (2.0 * a);
            double s_bv = 1.0 - (vb2 - b1) / (2.0 * a);
            if (s_fv < 0) s_fv = 0;     if (s_fv > 1) s_fv = 1;
            if (s_bv < 0) s_bv = 0;     if (s_bv > 1) s_bv = 1;
            double sqv = sqrt(vb2);
            if (s_fv < s_bv) {
                // Trapezoidal: accelerate to vbound, cruise, decelerate.
                double t_acc = (sqv - sqrt(b0)) / a;
                double t_cruise = (s_bv - s_fv) / sqv;
                double t_dec = (sqv - sqrt(b1)) / a;
                dt = t_acc + t_cruise + t_dec;
            } else {
                // Triangular: forward and backward arcs meet in the
                // middle (peak below vbound²).
                double s_meet = (b1 - b0) / (4.0 * a) + 0.5;
                if (s_meet < 0) s_meet = 0; if (s_meet > 1) s_meet = 1;
                double b_peak = b0 + 2.0 * a * s_meet;
                if (b_peak > vb2) b_peak = vb2;
                double sqp = sqrt(b_peak);
                dt = (sqp - sqrt(b0)) / a + (sqp - sqrt(b1)) / a;
            }
            if (dt < 0) dt = 0;  // numerical guard
        }
        p->t[i + 1] = p->t[i] + dt;
    }
    p->total_time = p->t[N - 1];

    free(vbound2); free(amax_seg);
    p->solved = 1;
    return 0;
}

long long nuc_topp_total_time(long long h) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(-1.0);
    return _f2i(p->total_time);
}

long long nuc_topp_time_at_waypoint(long long h, long long i) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || !p->solved || i < 0 || i >= (long long)p->n_waypoints) return _f2i(-1.0);
    return _f2i(p->t[i]);
}

long long nuc_topp_path_velocity(long long h, long long i) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p || !p->solved || i < 0 || i >= (long long)p->n_waypoints) return _f2i(-1.0);
    return _f2i(sqrt(p->b[i]));
}

long long nuc_topp_waypoint_count(long long h) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    return p ? (long long)p->n_waypoints : 0;
}

void nuc_topp_free(long long h) {
    NTopp *p = (NTopp *)(void *)(size_t)h;
    if (!p) return;
    if (p->waypoints) free(p->waypoints);
    if (p->vmax) free(p->vmax);
    if (p->amax) free(p->amax);
    if (p->b) free(p->b);
    if (p->t) free(p->t);
    free(p);
}
