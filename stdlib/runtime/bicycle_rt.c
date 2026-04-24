// bicycle_rt.c — Kinematic bicycle model forward integration.
//
// The bicycle model treats a car as two wheels on a single axle:
// front (steerable) and rear (driven). Standard kinematics:
//
//   ẋ = v cos(θ)
//   ẏ = v sin(θ)
//   θ̇ = (v / L) tan(δ)
//
//   (x, y, θ) = REAR-axle pose (world frame)
//   v        = forward speed at the rear axle (m/s)
//   δ        = front-wheel steering angle (rad)
//   L        = wheelbase (m)
//
// Use:
//   - Rolling forward simulation companion to `purepursuit.nr`,
//     `stanley.nr`, and any planner whose vehicle model is a
//     car-like robot (Dubins / Reeds-Shepp).
//   - Quick offline sim of trajectories before deploying onto
//     hardware.
//
// Two integrators provided:
//   `nuc_bicycle_step_euler` — single forward Euler step (fast,
//                              accurate for small dt and low
//                              curvature).
//   `nuc_bicycle_step_rk4`   — single RK4 step (4× cost, much
//                              better accuracy at large dt or
//                              tight curvature).
//
// **Limitations** (full dynamic bicycle with tire slip / Pacejka
// model / lateral acceleration limits land in v0.6 if needed):
// - Kinematic only — assumes no wheel slip (low-speed regime).
// - δ clamped externally (caller responsibility).
// - L > 0 assumed.
//
// Compile: clang -c stdlib/runtime/bicycle_rt.c -o target/bicycle.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

static void _deriv(double v, double th, double delta, double L,
                   double *dx, double *dy, double *dth)
{
    *dx  = v * cos(th);
    *dy  = v * sin(th);
    *dth = (L > 1e-18) ? v * tan(delta) / L : 0;
}

// Forward Euler: x_{k+1} = x_k + dt * f(x_k).
// Writes new (x, y, θ) to out_ptr (double[3]).
// Returns 1 on success, 0 on bad input.
long long nuc_bicycle_step_euler(long long x_b, long long y_b, long long theta_b,
                                  long long v_b, long long delta_b,
                                  long long L_b, long long dt_b,
                                  long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double v = _i2f(v_b), d = _i2f(delta_b);
    double L = _i2f(L_b), dt = _i2f(dt_b);
    if (L <= 0) return 0;

    double dx, dy, dth;
    _deriv(v, th, d, L, &dx, &dy, &dth);
    out[0] = x  + dt * dx;
    out[1] = y  + dt * dy;
    out[2] = th + dt * dth;
    return 1;
}

// Classical RK4 over a single step `dt`. Re-uses the same
// (v, δ, L) throughout the step (zero-order hold on inputs).
long long nuc_bicycle_step_rk4(long long x_b, long long y_b, long long theta_b,
                                long long v_b, long long delta_b,
                                long long L_b, long long dt_b,
                                long long out_ptr)
{
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!out) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double v = _i2f(v_b), d = _i2f(delta_b);
    double L = _i2f(L_b), dt = _i2f(dt_b);
    if (L <= 0) return 0;

    double k1x, k1y, k1t;
    double k2x, k2y, k2t;
    double k3x, k3y, k3t;
    double k4x, k4y, k4t;

    _deriv(v, th, d, L, &k1x, &k1y, &k1t);
    _deriv(v, th + 0.5*dt*k1t, d, L, &k2x, &k2y, &k2t);
    _deriv(v, th + 0.5*dt*k2t, d, L, &k3x, &k3y, &k3t);
    _deriv(v, th + dt*k3t,     d, L, &k4x, &k4y, &k4t);

    out[0] = x  + (dt/6.0) * (k1x + 2*k2x + 2*k3x + k4x);
    out[1] = y  + (dt/6.0) * (k1y + 2*k2y + 2*k3y + k4y);
    out[2] = th + (dt/6.0) * (k1t + 2*k2t + 2*k3t + k4t);
    return 1;
}
