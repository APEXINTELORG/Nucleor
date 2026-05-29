// mobile_rt.c — Differential-drive and Ackermann mobile-robot
// kinematics + arc-integrated pose update.
//
// Differential drive:
//   v_body  = (vL + vR) · wheel_radius / 2
//   ω_body  = (vR − vL) · wheel_radius / wheelbase
// Inverse:
//   vL      = (v_body − ω_body · wheelbase / 2) / wheel_radius
//   vR      = (v_body + ω_body · wheelbase / 2) / wheel_radius
// (`vL`, `vR` are angular wheel velocities in rad/s; `wheel_radius`
// in m; `wheelbase` in m; `v_body` in m/s; `ω_body` in rad/s.)
//
// Ackermann (car-like, bicycle model):
//   v_body  = v
//   ω_body  = v / wheelbase · tan(δ)        (δ = steering angle)
//
// Exact arc-integrated pose update from (x, y, θ) with (v, ω) over dt:
//   if |ω| > ε:
//     R = v / ω
//     x' = x + R · (sin(θ + ω·dt) − sin(θ))
//     y' = y + R · (−cos(θ + ω·dt) + cos(θ))
//     θ' = θ + ω·dt
//   else (straight line):
//     x' = x + v · cos(θ) · dt
//     y' = y + v · sin(θ) · dt
//     θ' = θ
//
// Limitations (slip / wheel-acceleration limits / mecanum /
// omnidirectional models land in v0.6 if needed):
// - No wheel slip / friction — pure rolling without slipping.
// - No actuator dynamics (instant velocity tracking).
// - Single-track (bicycle) Ackermann; for two-track + ICR
//   computation, derive from this rod's outputs externally.
//
// Compile: clang -c stdlib/runtime/mobile_rt.c -o target/mobile.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// === Differential drive ===

void nuc_mobile_diff_fwd_kin(long long vL_b, long long vR_b,
                              long long r_b, long long L_b,
                              long long v_out_ptr, long long w_out_ptr)
{
    double vL = _i2f(vL_b), vR = _i2f(vR_b);
    double r = _i2f(r_b), L = _i2f(L_b);
    double *vo = (double *)(void *)(size_t)v_out_ptr;
    double *wo = (double *)(void *)(size_t)w_out_ptr;
    double v = (vL + vR) * r * 0.5;
    double w = (vR - vL) * r / (L > 1e-9 ? L : 1e-9);
    if (vo) *vo = v;
    if (wo) *wo = w;
}

void nuc_mobile_diff_inv_kin(long long v_b, long long w_b,
                              long long r_b, long long L_b,
                              long long vL_out_ptr, long long vR_out_ptr)
{
    double v = _i2f(v_b), w = _i2f(w_b);
    double r = _i2f(r_b), L = _i2f(L_b);
    double *vL = (double *)(void *)(size_t)vL_out_ptr;
    double *vR = (double *)(void *)(size_t)vR_out_ptr;
    double inv_r = (r > 1e-9) ? (1.0 / r) : 1e9;
    double half_L = 0.5 * L;
    if (vL) *vL = (v - w * half_L) * inv_r;
    if (vR) *vR = (v + w * half_L) * inv_r;
}

// === Ackermann (bicycle model) ===

void nuc_mobile_ackermann_fwd_kin(long long v_b, long long delta_b,
                                   long long L_b,
                                   long long v_out_ptr, long long w_out_ptr)
{
    double v = _i2f(v_b);
    double d = _i2f(delta_b);
    double L = _i2f(L_b);
    double *vo = (double *)(void *)(size_t)v_out_ptr;
    double *wo = (double *)(void *)(size_t)w_out_ptr;
    if (vo) *vo = v;
    if (wo) *wo = (L > 1e-9) ? (v / L * tan(d)) : 0.0;
}

// Inverse Ackermann: given (v, ω), recover steering angle δ.
// Returns δ. (v passes through.)
long long nuc_mobile_ackermann_inv_steer(long long v_b, long long w_b, long long L_b) {
    double v = _i2f(v_b), w = _i2f(w_b), L = _i2f(L_b);
    if (fabs(v) < 1e-9) return _f2i(0.0);
    return _f2i(atan2(w * L, v));
}

// === Arc-integrated pose update ===

void nuc_mobile_pose_step(long long x_b, long long y_b, long long theta_b,
                           long long v_b, long long w_b, long long dt_b,
                           long long x_out_ptr, long long y_out_ptr,
                           long long theta_out_ptr)
{
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double v = _i2f(v_b), w = _i2f(w_b), dt = _i2f(dt_b);
    double *xo = (double *)(void *)(size_t)x_out_ptr;
    double *yo = (double *)(void *)(size_t)y_out_ptr;
    double *to = (double *)(void *)(size_t)theta_out_ptr;
    double xn, yn, tn;
    if (fabs(w) > 1e-9) {
        double R = v / w;
        double new_th = th + w * dt;
        xn = x + R * (sin(new_th) - sin(th));
        yn = y + R * (-cos(new_th) + cos(th));
        tn = new_th;
    } else {
        xn = x + v * cos(th) * dt;
        yn = y + v * sin(th) * dt;
        tn = th;
    }
    if (xo) *xo = xn;
    if (yo) *yo = yn;
    if (to) *to = tn;
}
