// purepursuit_rt.c — Pure-pursuit geometric path tracker for
// Ackermann (car-like) robots.
//
// Given current pose `(x, y, θ)`, a 2-D waypoint path, and a
// lookahead distance `L_d`, finds the point on the path at
// approximately `L_d` ahead of the robot and computes the steering
// angle that would make the vehicle drive to that point along an
// arc.
//
// Pure pursuit (Coulter 1992):
//   1. Find closest path waypoint to robot.
//   2. From that waypoint, walk forward along the path until the
//      cumulative segment length reaches `L_d`. Interpolate within
//      the final segment to land exactly at distance `L_d`.
//   3. Compute the angle `α` from the robot heading to the lookahead
//      point.
//   4. Steering angle: `δ = atan(2 L sin(α) / L_d)` where `L` is
//      the wheelbase.
//
// Use:
//   - Mobile-base navigation following a planned path.
//   - Closed-loop tracking layer underneath any path planner
//     (RRT, A*, vgraph, Dubins).
//
// Limitations (adaptive lookahead / curvature-based gain
// scheduling / look-ahead point smoothing land in v0.6 if needed):
// - Fixed lookahead distance.
// - No velocity output — caller decides forward speed (typically
//   from a separate longitudinal controller).
// - Assumes path is dense enough that lookahead-point search is
//   well-defined.
//
// Compile: clang -c stdlib/runtime/purepursuit_rt.c -o target/purepursuit.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Compute steering command. Returns:
//   1 on success (steer written to steer_out_ptr)
//   0 if path is empty or lookahead point can't be found before
//     the path ends.
long long nuc_purepursuit_step(long long x_b, long long y_b, long long theta_b,
                                 long long path_x_ptr, long long path_y_ptr,
                                 long long n_waypoints_,
                                 long long lookahead_b, long long wheelbase_b,
                                 long long steer_out_ptr)
{
    int n = (int)n_waypoints_;
    if (n < 2) return 0;
    const double *px = (const double *)(void *)(size_t)path_x_ptr;
    const double *py = (const double *)(void *)(size_t)path_y_ptr;
    double *steer_out = (double *)(void *)(size_t)steer_out_ptr;
    if (!px || !py || !steer_out) return 0;
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double L_d = _i2f(lookahead_b);
    double L = _i2f(wheelbase_b);
    if (L_d <= 0 || L <= 0) return 0;

    // Find closest waypoint to robot.
    int closest = 0;
    double best_d2 = 1e300;
    for (int i = 0; i < n; i++) {
        double dx = px[i] - x, dy = py[i] - y;
        double d2 = dx*dx + dy*dy;
        if (d2 < best_d2) { best_d2 = d2; closest = i; }
    }

    // Walk forward from closest, accumulating arc length, until we
    // reach at least L_d. Lookahead point = interpolate within the
    // final segment.
    double accum = sqrt(best_d2);    // start with distance from robot to closest waypoint
    int seg = closest;
    double lookahead_x = 0, lookahead_y = 0;
    int found = 0;
    if (accum >= L_d) {
        // Lookahead is between robot and closest waypoint — use closest.
        lookahead_x = px[closest];
        lookahead_y = py[closest];
        found = 1;
    } else {
        // Walk along the path forward.
        for (int i = closest; i < n - 1; i++) {
            double seg_dx = px[i+1] - px[i];
            double seg_dy = py[i+1] - py[i];
            double seg_len = sqrt(seg_dx*seg_dx + seg_dy*seg_dy);
            if (accum + seg_len >= L_d) {
                double need = L_d - accum;
                double t = (seg_len > 1e-12) ? need / seg_len : 0;
                lookahead_x = px[i] + t * seg_dx;
                lookahead_y = py[i] + t * seg_dy;
                found = 1;
                break;
            }
            accum += seg_len;
        }
    }
    if (!found) {
        // Path too short — use last waypoint.
        lookahead_x = px[n-1];
        lookahead_y = py[n-1];
    }

    // Angle from robot to lookahead point in robot frame.
    double dx = lookahead_x - x;
    double dy = lookahead_y - y;
    double ang_world = atan2(dy, dx);
    double alpha = ang_world - th;
    // Wrap to [-π, π].
    while (alpha >  3.141592653589793) alpha -= 6.283185307179586;
    while (alpha < -3.141592653589793) alpha += 6.283185307179586;

    // Steering angle.
    double steer = atan2(2.0 * L * sin(alpha), L_d);
    *steer_out = steer;
    return 1;
}
