// trapvel_rt.c — Trapezoidal velocity profile for point-to-point
// motion with bounded acceleration and bounded velocity.
//
// Given start position `s0`, goal position `s1`, max velocity
// `v_max`, and max acceleration `a_max`, computes the
// classical trapezoidal profile:
//
//   - Accelerate at +a_max from v=0 until v reaches v_max
//     (or the midpoint, whichever comes first).
//   - Cruise at constant v_max for the middle phase (may be
//     zero-length if the move is too short to reach v_max —
//     the "triangular" case).
//   - Decelerate at -a_max until v=0 at s1.
//
// This is the foundational profile underneath every robot servo
// drive, CNC controller, and pick-and-place sequencer that needs
// smooth bounded motion.
//
// API surface:
//   `nuc_trapvel_total_time(s0, s1, v_max, a_max) -> double`
//      total duration of the move.
//   `nuc_trapvel_sample(s0, s1, v_max, a_max, t)`
//      sample (position, velocity, acceleration) at time t.
//      Writes 3 doubles to out_ptr.
//
// **Limitations** (S-curve / 7-segment jerk-limited / asymmetric
// accel-decel land in v0.6 if needed):
// - Symmetric accel = decel (both = a_max).
// - Discontinuous acceleration at phase transitions (jerk = inf).
// - 1-D scalar moves; multi-axis sync done by caller.
//
// Compile: clang -c stdlib/runtime/trapvel_rt.c -o target/trapvel.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Plan the profile internally. Returns:
//   t_acc  — accel-phase duration
//   t_cru  — cruise-phase duration (0 in the triangular case)
//   t_total — total duration
//   v_peak — actual peak velocity (= v_max in trapezoid, < v_max in triangle)
//   sign   — +1 if s1 > s0, -1 if s1 < s0, 0 if degenerate
static int _plan(double s0, double s1, double v_max, double a_max,
                 double *t_acc, double *t_cru, double *t_total,
                 double *v_peak, double *sign)
{
    if (a_max <= 0 || v_max <= 0) return 0;
    double D = s1 - s0;
    *sign = (D > 0) ? 1.0 : (D < 0 ? -1.0 : 0.0);
    double absD = fabs(D);
    if (absD == 0.0) {
        *t_acc = 0; *t_cru = 0; *t_total = 0; *v_peak = 0;
        return 1;
    }
    // Distance to reach v_max under +a_max from rest:
    //   v_max = a_max * t_acc  →  t_acc = v_max / a_max
    //   d_acc = 0.5 * a_max * t_acc^2 = v_max^2 / (2 a_max)
    double t_acc_full = v_max / a_max;
    double d_acc_full = 0.5 * a_max * t_acc_full * t_acc_full;
    if (2.0 * d_acc_full <= absD) {
        // Trapezoidal case — has a cruise phase.
        *t_acc = t_acc_full;
        double d_cru = absD - 2.0 * d_acc_full;
        *t_cru = d_cru / v_max;
        *t_total = 2.0 * t_acc_full + *t_cru;
        *v_peak = v_max;
    } else {
        // Triangular case — never reach v_max.
        // 2 * (0.5 a t^2) = absD  →  t = sqrt(absD / a_max)
        *t_acc = sqrt(absD / a_max);
        *t_cru = 0;
        *t_total = 2.0 * (*t_acc);
        *v_peak = a_max * (*t_acc);
    }
    return 1;
}

long long nuc_trapvel_total_time(long long s0_b, long long s1_b,
                                  long long v_max_b, long long a_max_b,
                                  long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double s0 = _i2f(s0_b), s1 = _i2f(s1_b);
    double v_max = _i2f(v_max_b), a_max = _i2f(a_max_b);
    double t_acc, t_cru, t_total, v_peak, sign;
    if (!_plan(s0, s1, v_max, a_max, &t_acc, &t_cru, &t_total, &v_peak, &sign)) return 0;
    *out = t_total;
    return 1;
}

// Sample (position, velocity, acceleration) at time t. Out is
// double[3]: (s, v, a). Returns 1 on success, 0 on bad input.
long long nuc_trapvel_sample(long long s0_b, long long s1_b,
                              long long v_max_b, long long a_max_b,
                              long long t_b, long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double s0 = _i2f(s0_b), s1 = _i2f(s1_b);
    double v_max = _i2f(v_max_b), a_max = _i2f(a_max_b);
    double t = _i2f(t_b);
    double t_acc, t_cru, t_total, v_peak, sign;
    if (!_plan(s0, s1, v_max, a_max, &t_acc, &t_cru, &t_total, &v_peak, &sign)) return 0;
    if (t < 0) t = 0;
    if (t > t_total) t = t_total;
    double s, v, a;
    if (sign == 0.0) {
        s = s0; v = 0; a = 0;
    } else if (t < t_acc) {
        // Accel phase.
        a = sign * a_max;
        v = sign * a_max * t;
        s = s0 + sign * 0.5 * a_max * t * t;
    } else if (t < t_acc + t_cru) {
        // Cruise phase.
        a = 0;
        v = sign * v_peak;
        double d_acc = 0.5 * a_max * t_acc * t_acc;
        s = s0 + sign * (d_acc + v_peak * (t - t_acc));
    } else {
        // Decel phase.
        double td = t - (t_acc + t_cru);  // time into decel
        a = -sign * a_max;
        v = sign * v_peak - sign * a_max * td;
        if (sign > 0 && v < 0) v = 0;
        if (sign < 0 && v > 0) v = 0;
        double d_acc = 0.5 * a_max * t_acc * t_acc;
        double d_cru = v_peak * t_cru;
        s = s0 + sign * (d_acc + d_cru + v_peak * td - 0.5 * a_max * td * td);
    }
    out[0] = s;
    out[1] = v;
    out[2] = a;
    return 1;
}
