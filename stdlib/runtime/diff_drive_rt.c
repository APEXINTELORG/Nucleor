// diff_drive_rt.c — Differential-drive (2-wheel) kinematics + odometry.
//
// A diff-drive robot has two independently-driven wheels separated
// by a fixed track width L. The standard kinematic model:
//
//   v       = (v_l + v_r) / 2          (forward speed)
//   omega   = (v_r - v_l) / L          (yaw rate)
//
//   ẋ = v cos(theta)
//   ẏ = v sin(theta)
//   θ̇ = omega
//
// Use:
//   - TurtleBot / iRobot Create / custom 2-wheel platform odometry.
//   - Forward-integration in simulators.
//   - Inverse-kinematics layer beneath cmd_vel-style controllers.
//
// API:
//   nuc_diff_drive_velocities(v_l, v_r, L_b, v_out, w_out)
//      Forward kinematics: wheel speeds → body (v, omega).
//   nuc_diff_drive_wheels(v, w, L_b, vl_out, vr_out)
//      Inverse kinematics: body (v, omega) → wheel speeds.
//   nuc_diff_drive_step(x, y, theta, v_l, v_r, L_b, dt_b, out_ptr)
//      One-step Euler odometry update. Writes new (x, y, theta).
//   nuc_diff_drive_step_arc(x, y, theta, v_l, v_r, L_b, dt_b, out_ptr)
//      Exact constant-curvature arc integration over dt (better
//      than Euler for non-trivial omega·dt).
//
// **Limitations** (wheel-slip / encoder-tick odometry / IMU-fused
// pose update land in v0.6 if needed):
// - Kinematic only (no slip).
// - Caller supplies wheel speeds (not encoder ticks).
//
// Compile: clang -c stdlib/runtime/diff_drive_rt.c -o target/diff_drive.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

long long nuc_diff_drive_velocities(long long vl_b, long long vr_b, long long L_b,
                                      long long v_out_ptr, long long w_out_ptr)
{
    double *v_out = (double *)(void *)(size_t)v_out_ptr;
    double *w_out = (double *)(void *)(size_t)w_out_ptr;
    if (!v_out || !w_out) return 0;
    double L = _i2f(L_b);
    if (L <= 0) return 0;
    double vl = _i2f(vl_b), vr = _i2f(vr_b);
    *v_out = 0.5 * (vl + vr);
    *w_out = (vr - vl) / L;
    return 1;
}

long long nuc_diff_drive_wheels(long long v_b, long long w_b, long long L_b,
                                 long long vl_out_ptr, long long vr_out_ptr)
{
    double *vl_out = (double *)(void *)(size_t)vl_out_ptr;
    double *vr_out = (double *)(void *)(size_t)vr_out_ptr;
    if (!vl_out || !vr_out) return 0;
    double L = _i2f(L_b);
    if (L <= 0) return 0;
    double v = _i2f(v_b), w = _i2f(w_b);
    *vl_out = v - 0.5 * w * L;
    *vr_out = v + 0.5 * w * L;
    return 1;
}

// Euler step: dt assumed small enough that v and omega are constant.
long long nuc_diff_drive_step(long long x_b, long long y_b, long long th_b,
                                long long vl_b, long long vr_b,
                                long long L_b, long long dt_b,
                                long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double L = _i2f(L_b), dt = _i2f(dt_b);
    if (L <= 0) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(th_b);
    double vl = _i2f(vl_b), vr = _i2f(vr_b);
    double v = 0.5 * (vl + vr);
    double w = (vr - vl) / L;
    out[0] = x  + dt * v * cos(th);
    out[1] = y  + dt * v * sin(th);
    out[2] = th + dt * w;
    return 1;
}

// Exact constant-curvature arc integration over dt. Equivalent to
// Euler when omega·dt is small; better for tight turns or large dt.
long long nuc_diff_drive_step_arc(long long x_b, long long y_b, long long th_b,
                                    long long vl_b, long long vr_b,
                                    long long L_b, long long dt_b,
                                    long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double L = _i2f(L_b), dt = _i2f(dt_b);
    if (L <= 0) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(th_b);
    double vl = _i2f(vl_b), vr = _i2f(vr_b);
    double v = 0.5 * (vl + vr);
    double w = (vr - vl) / L;
    if (fabs(w) < 1e-9) {
        // Straight-line case (no curvature).
        out[0] = x + v * dt * cos(th);
        out[1] = y + v * dt * sin(th);
        out[2] = th;
    } else {
        // Constant-curvature arc: ICR (instantaneous center of rotation).
        double R = v / w;
        double dth = w * dt;
        out[0] = x + R * (sin(th + dth) - sin(th));
        out[1] = y - R * (cos(th + dth) - cos(th));
        out[2] = th + dth;
    }
    return 1;
}
