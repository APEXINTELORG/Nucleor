// stanley_rt.c — Stanley path tracker for Ackermann robots.
//
// Geometric controller from the Stanford DARPA Grand Challenge
// vehicle (Hoffmann/Thrun 2007). Computes steering from two error
// terms measured at the FRONT axle:
//
//   δ = ψ_e + atan2(k · e_ct, v_f + k_soft)
//
//   ψ_e  = heading error (path tangent − vehicle heading)
//   e_ct = signed cross-track error (perpendicular distance from
//          front axle to path; positive when front axle is to the
//          LEFT of the path tangent direction)
//   k     = cross-track gain
//   k_soft= softening constant to keep gain finite at v→0
//   v_f   = forward speed at front axle
//
// Pure pursuit looks ahead; Stanley looks at where the front
// wheel actually IS relative to the path. Better at low speeds
// and tight curves, more sensitive to path noise.
//
// Use:
//   - Mobile-base path tracking, especially at low/varying speed.
//   - Pair with `purepursuit.nr` and pick whichever fits the
//     vehicle: Stanley for sharper response, pure-pursuit for
//     smooth high-speed cruising.
//
// **Limitations** (gain scheduling / yaw-rate feedforward / curvature
// preview land in v0.6 if needed):
// - No curvature feedforward (only proportional).
// - Cross-track sign assumes 2-D right-handed frame (z = up).
// - Path must be dense enough that nearest-segment projection
//   is well-defined.
//
// Compile: clang -c stdlib/runtime/stanley_rt.c -o target/stanley.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Compute Stanley steering command. Inputs:
//   (x, y, theta) = REAR axle pose (we'll project to front axle
//                   internally using wheelbase L).
//   v             = forward speed (m/s).
//   path_x_ptr/path_y_ptr = double[n] path waypoints.
//   k             = cross-track gain (typical 0.5 - 2.5).
//   k_soft        = softening constant (typical 1.0 m/s).
//   wheelbase     = L (m).
// Returns 1 on success, writes steer to *steer_out_ptr; 0 on bad input.
long long nuc_stanley_step(long long x_b, long long y_b, long long theta_b,
                            long long v_b,
                            long long path_x_ptr, long long path_y_ptr,
                            long long n_waypoints_,
                            long long k_b, long long k_soft_b,
                            long long wheelbase_b,
                            long long steer_out_ptr)
{
    int n = (int)n_waypoints_;
    if (n < 2) return 0;
    const double *px = (const double *)(void *)(size_t)path_x_ptr;
    const double *py = (const double *)(void *)(size_t)path_y_ptr;
    double *steer_out = (double *)(void *)(size_t)steer_out_ptr;
    if (!px || !py || !steer_out) return 0;
    double xr = _i2f(x_b), yr = _i2f(y_b), th = _i2f(theta_b);
    double v = _i2f(v_b);
    double k = _i2f(k_b);
    double k_soft = _i2f(k_soft_b);
    double L = _i2f(wheelbase_b);
    if (L <= 0 || k_soft < 0) return 0;

    // Project rear-axle pose forward by L to get front-axle pose.
    double xf = xr + L * cos(th);
    double yf = yr + L * sin(th);

    // Find the nearest segment to the front axle. For each segment
    // i .. i+1, compute projection of front axle and clamp to [0,1].
    int best_i = 0;
    double best_d2 = 1e300;
    double best_t = 0.0;
    for (int i = 0; i < n - 1; i++) {
        double sx = px[i+1] - px[i];
        double sy = py[i+1] - py[i];
        double L2 = sx*sx + sy*sy;
        double t = 0;
        if (L2 > 1e-18) {
            t = ((xf - px[i]) * sx + (yf - py[i]) * sy) / L2;
            if (t < 0) t = 0;
            else if (t > 1) t = 1;
        }
        double cx = px[i] + t * sx;
        double cy = py[i] + t * sy;
        double dx = xf - cx, dy = yf - cy;
        double d2 = dx*dx + dy*dy;
        if (d2 < best_d2) { best_d2 = d2; best_i = i; best_t = t; }
    }

    // Path tangent direction at the projection point — use the
    // segment we landed on.
    double sx = px[best_i+1] - px[best_i];
    double sy = py[best_i+1] - py[best_i];
    double seg_len = sqrt(sx*sx + sy*sy);
    if (seg_len < 1e-12) return 0;
    double tx = sx / seg_len;
    double ty = sy / seg_len;
    double path_heading = atan2(ty, tx);

    // Heading error = path tangent − vehicle heading, wrapped.
    double psi_e = path_heading - th;
    while (psi_e >  3.141592653589793) psi_e -= 6.283185307179586;
    while (psi_e < -3.141592653589793) psi_e += 6.283185307179586;

    // Signed cross-track error. Vector from projection to front axle
    // is (ex, ey); LEFT normal of path tangent is (-ty, tx).
    double cx = px[best_i] + best_t * sx;
    double cy = py[best_i] + best_t * sy;
    double ex = xf - cx;
    double ey = yf - cy;
    // sign = +1 when (ex,ey) projects positively onto LEFT normal,
    //        −1 when projects onto RIGHT normal.
    double e_ct_signed = ex * (-ty) + ey * (tx);

    // Stanley law. Sign convention: when front axle is LEFT of
    // path (e_ct > 0), we want to steer RIGHT (negative δ), so the
    // cross-track term enters as atan2(−k · e_ct, ...).
    double v_eff = v + k_soft;
    double xt_term = atan2(-k * e_ct_signed, v_eff);
    double steer = psi_e + xt_term;

    // Wrap final steer to [-π, π].
    while (steer >  3.141592653589793) steer -= 6.283185307179586;
    while (steer < -3.141592653589793) steer += 6.283185307179586;

    *steer_out = steer;
    return 1;
}
