// pursuit_rt.c — Pure pursuit path-following controller.
//
// Classical geometric controller for differential-drive and
// car-like (Ackermann-steered) robots. Given a path of waypoints
// and the robot's current pose:
//
//   1. Find the lookahead point — the point on the path at
//      Euclidean distance `lookahead` from the robot, ahead of
//      the closest path point.
//   2. Compute the heading error α to that point.
//   3. Compute the steering command:
//        - Differential drive:  ω = 2·v·sin(α) / lookahead
//        - Car-like (Ackermann): δ = atan(2·L·sin(α) / lookahead)
//      where L is the wheelbase length.
//
// Foundation for autonomous mobile robot (AMR/AGV) control,
// outdoor delivery robots, autonomous vehicles, and warehouse
// transports.
//
// **Limitations** (adaptive lookahead, look-ahead time-based
// formulation, and waypoint-skipping / path-pruning land in v0.6
// if needed):
// - Constant lookahead distance (no velocity-adaptive scheduling).
// - No path completion / "near-goal" early-stop.
// - Brute-force closest-point search per call — fine for paths
//   up to a few thousand waypoints.
//
// Compile: clang -c stdlib/runtime/pursuit_rt.c -o target/pursuit.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n_pts;
    int cap_pts;
    double *pts;     // n_pts × 2 (x, y)
    int last_idx;    // monotone progress along the path
} NPursuit;

long long nuc_pursuit_new(long long n_pts_hint) {
    NPursuit *p = (NPursuit *)calloc(1, sizeof(NPursuit));
    p->cap_pts = (int)((n_pts_hint > 0) ? n_pts_hint : 16);
    p->pts = (double *)calloc(p->cap_pts * 2, sizeof(double));
    return (long long)(size_t)p;
}

// Append a waypoint (x, y) to the path.
long long nuc_pursuit_add_point(long long h, long long x_b, long long y_b) {
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p) return -1;
    if (p->n_pts >= p->cap_pts) {
        p->cap_pts *= 2;
        p->pts = (double *)realloc(p->pts, p->cap_pts * 2 * sizeof(double));
    }
    p->pts[p->n_pts*2 + 0] = _i2f(x_b);
    p->pts[p->n_pts*2 + 1] = _i2f(y_b);
    return (long long)(p->n_pts++);
}

// Reset progress so the next pursuit call searches the whole path
// for the closest point. Useful after manually moving the robot or
// switching to a new path.
void nuc_pursuit_reset_progress(long long h) {
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p) return;
    p->last_idx = 0;
}

long long nuc_pursuit_point_count(long long h) {
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    return p ? (long long)p->n_pts : 0;
}

// Find the index of the path point closest to (x, y), starting
// from `last_idx` (monotone — never seek backward in the path).
static int _closest_after(NPursuit *p, double x, double y) {
    int best = p->last_idx;
    double dx = p->pts[best*2+0] - x;
    double dy = p->pts[best*2+1] - y;
    double best_d2 = dx*dx + dy*dy;
    for (int i = p->last_idx + 1; i < p->n_pts; i++) {
        dx = p->pts[i*2+0] - x;
        dy = p->pts[i*2+1] - y;
        double d2 = dx*dx + dy*dy;
        if (d2 < best_d2) { best_d2 = d2; best = i; }
        // Path is assumed roughly sequential; break if distance starts
        // growing.
        else if (d2 > best_d2 * 4.0) break;
    }
    return best;
}

// Find the lookahead point — first path point at distance ≥ `lookahead`
// from (x, y) when scanning forward from the closest point. Falls
// back to the last waypoint if no point is far enough.
static int _lookahead_index(NPursuit *p, int closest, double x, double y, double lookahead) {
    double L2 = lookahead * lookahead;
    for (int i = closest; i < p->n_pts; i++) {
        double dx = p->pts[i*2+0] - x;
        double dy = p->pts[i*2+1] - y;
        if (dx*dx + dy*dy >= L2) return i;
    }
    return p->n_pts - 1;
}

// Differential-drive pure pursuit step. Given current pose
// (x, y, θ), nominal forward velocity v, and lookahead distance L,
// returns the angular velocity command ω (rad/s). Updates internal
// progress so subsequent calls only scan forward.
//
// Signed convention: positive ω = counterclockwise (left turn).
long long nuc_pursuit_step_diff_drive(long long h,
    long long x_b, long long y_b, long long theta_b,
    long long v_b, long long lookahead_b)
{
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p || p->n_pts < 2) return _f2i(0.0);
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double v = _i2f(v_b), L = _i2f(lookahead_b);

    int closest = _closest_after(p, x, y);
    p->last_idx = closest;
    int la = _lookahead_index(p, closest, x, y, L);

    // Heading to lookahead point.
    double dx = p->pts[la*2+0] - x;
    double dy = p->pts[la*2+1] - y;
    double target_heading = atan2(dy, dx);
    double alpha = target_heading - th;
    // Wrap α to [-π, π].
    while (alpha >  M_PI) alpha -= 2.0 * M_PI;
    while (alpha < -M_PI) alpha += 2.0 * M_PI;
    // Pure-pursuit ω = 2·v·sin(α) / L.
    double omega = 2.0 * v * sin(alpha) / L;
    return _f2i(omega);
}

// Car-like (Ackermann-steered) pure pursuit step. Same inputs as
// the differential-drive variant plus the wheelbase length, returns
// the steering angle δ (rad).
long long nuc_pursuit_step_ackermann(long long h,
    long long x_b, long long y_b, long long theta_b,
    long long v_b, long long lookahead_b, long long wheelbase_b)
{
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p || p->n_pts < 2) return _f2i(0.0);
    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double L = _i2f(lookahead_b), W = _i2f(wheelbase_b);
    (void)v_b;  // velocity doesn't affect steering angle in the
                // Ackermann formulation (only via dynamics).

    int closest = _closest_after(p, x, y);
    p->last_idx = closest;
    int la = _lookahead_index(p, closest, x, y, L);

    double dx = p->pts[la*2+0] - x;
    double dy = p->pts[la*2+1] - y;
    double target_heading = atan2(dy, dx);
    double alpha = target_heading - th;
    while (alpha >  M_PI) alpha -= 2.0 * M_PI;
    while (alpha < -M_PI) alpha += 2.0 * M_PI;
    // Pure-pursuit δ = atan(2·W·sin(α) / L).
    double delta = atan(2.0 * W * sin(alpha) / L);
    return _f2i(delta);
}

// Distance to the final waypoint — useful for goal-reached
// detection.
long long nuc_pursuit_distance_to_goal(long long h, long long x_b, long long y_b) {
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p || p->n_pts == 0) return _f2i(0.0);
    double x = _i2f(x_b), y = _i2f(y_b);
    double gx = p->pts[(p->n_pts - 1)*2 + 0];
    double gy = p->pts[(p->n_pts - 1)*2 + 1];
    double dx = gx - x, dy = gy - y;
    return _f2i(sqrt(dx*dx + dy*dy));
}

void nuc_pursuit_free(long long h) {
    NPursuit *p = (NPursuit *)(void *)(size_t)h;
    if (!p) return;
    if (p->pts) free(p->pts);
    free(p);
}
