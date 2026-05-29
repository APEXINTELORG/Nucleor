// mecanum_rt.c — Mecanum-wheel (4-wheel omnidirectional) kinematics.
//
// A mecanum-drive robot has four omnidirectional wheels, each
// with rollers angled at ±45°. Configured per the standard
// "X-pattern" (rollers form an X when viewed from above):
//
//   FL roller axis: +45°,  FR: -45°
//   BL roller axis: -45°,  BR: +45°
//
// Body velocity (vx, vy, omega) decomposes to wheel speeds via:
//
//   v_FL = vx − vy − (Lx + Ly) * omega
//   v_FR = vx + vy + (Lx + Ly) * omega
//   v_BL = vx + vy − (Lx + Ly) * omega
//   v_BR = vx − vy + (Lx + Ly) * omega
//
// where Lx is half the wheelbase (front-rear) and Ly is half the
// track (left-right). All four wheel speeds in m/s; vx, vy in m/s
// (body frame, +x forward, +y left); omega in rad/s.
//
// Forward kinematics (wheels → body) is the Moore-Penrose
// pseudo-inverse of the 4×3 inverse-kinematics Jacobian, which
// for the standard X-pattern simplifies to:
//
//   vx    = (v_FL + v_FR + v_BL + v_BR) / 4
//   vy    = (-v_FL + v_FR + v_BL - v_BR) / 4
//   omega = (-v_FL + v_FR - v_BL + v_BR) / (4 * (Lx + Ly))
//
// Use:
//   - Indoor warehouse robots (KUKA iiwago, Mecanum YouBot).
//   - Soccer/competition platforms.
//   - Any 4-wheel platform where strafing is required.
//
// Limitations (wheel-slip / over-determined least-squares /
// roller-friction model land in v0.6 if needed):
// - Kinematic only (no slip, no roller friction).
// - X-pattern roller geometry only (caller flips signs for
//   O-pattern).
//
// Compile: clang -c stdlib/runtime/mecanum_rt.c -o target/mecanum.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Inverse kinematics: body (vx, vy, omega) → 4 wheel speeds.
// out_ptr is double[4]: (FL, FR, BL, BR).
long long nuc_mecanum_wheels(long long vx_b, long long vy_b, long long w_b,
                              long long Lx_b, long long Ly_b,
                              long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double vx = _i2f(vx_b), vy = _i2f(vy_b), w = _i2f(w_b);
    double Lx = _i2f(Lx_b), Ly = _i2f(Ly_b);
    double k = (Lx + Ly) * w;
    out[0] = vx - vy - k;   // FL
    out[1] = vx + vy + k;   // FR
    out[2] = vx + vy - k;   // BL
    out[3] = vx - vy + k;   // BR
    return 1;
}

// Forward kinematics: 4 wheel speeds → body (vx, vy, omega).
// out_ptr is double[3]: (vx, vy, omega).
long long nuc_mecanum_velocities(long long fl_b, long long fr_b,
                                   long long bl_b, long long br_b,
                                   long long Lx_b, long long Ly_b,
                                   long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double Lx = _i2f(Lx_b), Ly = _i2f(Ly_b);
    double sum = Lx + Ly;
    if (fabs(sum) < 1e-18) return 0;
    double fl = _i2f(fl_b), fr = _i2f(fr_b), bl = _i2f(bl_b), br = _i2f(br_b);
    out[0] = (fl + fr + bl + br) / 4.0;            // vx
    out[1] = (-fl + fr + bl - br) / 4.0;           // vy
    out[2] = (-fl + fr - bl + br) / (4.0 * sum);   // omega
    return 1;
}

// One-step Euler odometry. Pose update with body velocity rotated
// into world frame. out_ptr is double[3]: new (x, y, theta).
long long nuc_mecanum_step(long long x_b, long long y_b, long long th_b,
                             long long vx_b, long long vy_b, long long w_b,
                             long long dt_b, long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(th_b);
    double vx = _i2f(vx_b), vy = _i2f(vy_b), w = _i2f(w_b);
    double dt = _i2f(dt_b);
    double c = cos(th), s = sin(th);
    out[0] = x + dt * (vx * c - vy * s);
    out[1] = y + dt * (vx * s + vy * c);
    out[2] = th + dt * w;
    return 1;
}
