// skid_steer_rt.c — 4-wheel skid-steer kinematics + odometry.
//
// A skid-steer platform (Husky, Jackal, big agricultural robots,
// tracked vehicles) drives all wheels on each side at the same
// speed. Turning happens by skidding — left side faster than
// right means the robot turns right, and vice versa.
//
// Kinematics ARE differential-drive applied to the AVERAGE
// per-side speed, but with an effective track width L_eff that
// accounts for the wheel-vs-ground slip (typically 1.5× the
// physical track for indoor wheels on hard floor; closer to 1.0×
// for outdoor wheels on soft soil). Caller supplies L_eff.
//
//   v       = (v_L + v_R) / 2
//   omega   = (v_R - v_L) / L_eff
//   ẋ = v cos θ;   ẏ = v sin θ;   θ̇ = omega
//
// Where v_L is the average of the two left-side wheels and v_R
// is the average of the two right-side wheels.
//
// Use:
//   - Tracked vehicles (where the "wheels" are tread sprockets).
//   - 4-wheel skid platforms.
//   - Big agricultural / mining vehicles.
//
// Limitations (slip-aware odometry / yaw-rate fusion / ICR-
// estimation from history land in v0.6 if needed):
// - Caller supplies L_eff (no auto-fit from data).
// - Kinematic only.
//
// Compile: clang -c stdlib/runtime/skid_steer_rt.c -o target/skid_steer.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Forward kinematics: 4 wheel speeds → body (v, omega).
// Wheels in order: FL, FR, BL, BR.
long long nuc_skid_steer_velocities(long long fl_b, long long fr_b,
                                       long long bl_b, long long br_b,
                                       long long L_eff_b,
                                       long long v_out_ptr, long long w_out_ptr)
{
    double *v_out = (double *)(void *)(size_t)v_out_ptr;
    double *w_out = (double *)(void *)(size_t)w_out_ptr;
    if (!v_out || !w_out) return 0;
    double L = _i2f(L_eff_b);
    if (L <= 0) return 0;
    double fl = _i2f(fl_b), fr = _i2f(fr_b);
    double bl = _i2f(bl_b), br = _i2f(br_b);
    double vL = 0.5 * (fl + bl);
    double vR = 0.5 * (fr + br);
    *v_out = 0.5 * (vL + vR);
    *w_out = (vR - vL) / L;
    return 1;
}

// Inverse kinematics: body (v, omega) → per-side wheel speeds.
// Returns vL_out and vR_out (each a single value; caller drives
// both wheels on the side at the same speed).
long long nuc_skid_steer_wheels(long long v_b, long long w_b,
                                  long long L_eff_b,
                                  long long vL_out_ptr, long long vR_out_ptr)
{
    double *vL_out = (double *)(void *)(size_t)vL_out_ptr;
    double *vR_out = (double *)(void *)(size_t)vR_out_ptr;
    if (!vL_out || !vR_out) return 0;
    double L = _i2f(L_eff_b);
    if (L <= 0) return 0;
    double v = _i2f(v_b), w = _i2f(w_b);
    *vL_out = v - 0.5 * w * L;
    *vR_out = v + 0.5 * w * L;
    return 1;
}

// Euler odometry step.
long long nuc_skid_steer_step(long long x_b, long long y_b, long long th_b,
                                long long fl_b, long long fr_b,
                                long long bl_b, long long br_b,
                                long long L_eff_b, long long dt_b,
                                long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double L = _i2f(L_eff_b), dt = _i2f(dt_b);
    if (L <= 0) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(th_b);
    double fl = _i2f(fl_b), fr = _i2f(fr_b);
    double bl = _i2f(bl_b), br = _i2f(br_b);
    double vL = 0.5 * (fl + bl);
    double vR = 0.5 * (fr + br);
    double v = 0.5 * (vL + vR);
    double w = (vR - vL) / L;
    out[0] = x  + dt * v * cos(th);
    out[1] = y  + dt * v * sin(th);
    out[2] = th + dt * w;
    return 1;
}
