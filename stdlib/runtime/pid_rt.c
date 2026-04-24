// pid_rt.c — Classic PID controller with anti-windup.
//
//   u(t) = Kp · e(t)  +  Ki · ∫₀^t e(τ) dτ  +  Kd · de/dt
//
// Discrete update (per call to `pid_step` with timestep dt):
//   error    = setpoint − measurement
//   integral = clamp(integral + error · dt,  i_lo, i_hi)
//   derivative = (error − last_error) / dt
//   u_raw    = Kp · error + Ki · integral + Kd · derivative
//   u        = clamp(u_raw, u_lo, u_hi)
//   last_error = error
//
// Anti-windup: integral and output are clamped via separate user-
// settable bounds (defaults: integral = ±∞, output = ±∞). The
// integral clamp prevents the classic "wind-up" pathology when the
// output saturates: without it, the integral keeps accumulating
// during saturation, then takes a long time to unwind once the
// error reverses.
//
// **Limitations** (gain scheduling / derivative-on-measurement /
// setpoint weighting land in v0.6 if needed):
// - Single SISO controller. For multi-DOF coordination use a stack
//   of independent PIDs or a model-based controller (`wbc.nr`,
//   `ilqr.nr`).
// - Derivative is computed on the error signal, which can produce
//   sharp spikes at setpoint changes. Standard fix is "derivative
//   on measurement" — straightforward to add in v0.6.
//
// Compile: clang -c stdlib/runtime/pid_rt.c -o target/pid.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double kp, ki, kd;
    double integral;
    double last_error;
    int has_last;
    double i_lo, i_hi;
    double u_lo, u_hi;
} NPID;

long long nuc_pid_new(long long kp_b, long long ki_b, long long kd_b) {
    NPID *p = (NPID *)calloc(1, sizeof(NPID));
    p->kp = _i2f(kp_b);
    p->ki = _i2f(ki_b);
    p->kd = _i2f(kd_b);
    p->i_lo = -INFINITY; p->i_hi = INFINITY;
    p->u_lo = -INFINITY; p->u_hi = INFINITY;
    p->integral = 0;
    p->last_error = 0;
    p->has_last = 0;
    return (long long)(size_t)p;
}

void nuc_pid_set_gains(long long h, long long kp_b, long long ki_b, long long kd_b) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return;
    p->kp = _i2f(kp_b);
    p->ki = _i2f(ki_b);
    p->kd = _i2f(kd_b);
}

void nuc_pid_set_integral_clamp(long long h, long long lo_b, long long hi_b) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return;
    double lo = _i2f(lo_b), hi = _i2f(hi_b);
    if (lo > hi) { double t = lo; lo = hi; hi = t; }
    p->i_lo = lo; p->i_hi = hi;
}

void nuc_pid_set_output_clamp(long long h, long long lo_b, long long hi_b) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return;
    double lo = _i2f(lo_b), hi = _i2f(hi_b);
    if (lo > hi) { double t = lo; lo = hi; hi = t; }
    p->u_lo = lo; p->u_hi = hi;
}

void nuc_pid_reset(long long h) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return;
    p->integral = 0;
    p->last_error = 0;
    p->has_last = 0;
}

long long nuc_pid_step(long long h, long long setpoint_b, long long meas_b, long long dt_b) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double dt = _i2f(dt_b);
    if (dt <= 0) dt = 1e-6;
    double error = _i2f(setpoint_b) - _i2f(meas_b);

    p->integral += error * dt;
    if (p->integral < p->i_lo) p->integral = p->i_lo;
    if (p->integral > p->i_hi) p->integral = p->i_hi;

    double deriv = 0;
    if (p->has_last) deriv = (error - p->last_error) / dt;
    p->last_error = error;
    p->has_last = 1;

    double u = p->kp * error + p->ki * p->integral + p->kd * deriv;
    if (u < p->u_lo) u = p->u_lo;
    if (u > p->u_hi) u = p->u_hi;
    return _f2i(u);
}

long long nuc_pid_integral(long long h) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->integral);
}

long long nuc_pid_last_error(long long h) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->last_error);
}

void nuc_pid_free(long long h) {
    NPID *p = (NPID *)(void *)(size_t)h;
    if (!p) return;
    free(p);
}
