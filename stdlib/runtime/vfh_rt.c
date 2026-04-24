// vfh_rt.c — Vector Field Histogram local obstacle avoidance
// (Borenstein & Koren 1991, simplified VFH/VFH+ flavor).
//
// Builds a polar histogram of obstacle density around the robot
// from a circular window over the local occupancy grid, finds the
// "valley" of low-density bearings nearest the goal direction,
// and returns a steering bearing through that valley.
//
// Algorithm:
//   1. For each occupied cell within `window_radius` of the robot,
//      add its weighted contribution to a histogram bin indexed by
//      bearing (n_bins bins covering [-π, π)).
//        weight = max(0, a - b * d²)
//      where d is cell-to-robot distance, (a, b) tuned so weight=0
//      at the window edge.
//   2. Threshold the histogram: bins below `density_threshold` are
//      "free", bins above are "blocked".
//   3. Find every contiguous run of free bins ("valleys").
//   4. Pick the valley whose center bearing is closest to the goal
//      bearing. The steered bearing is the center of that valley
//      (or the goal bearing itself if the goal-bearing bin is free
//      and the valley is wider than `narrow_valley_threshold`).
//
// Use:
//   - Reactive obstacle avoidance layer underneath any global
//     planner that can re-plan slowly.
//   - Pair with `bicycle.nr` / `purepursuit.nr` to track the VFH
//     heading.
//
// **Limitations** (VFH+ pre-thresholding masks / VFH* lookahead /
// dynamic-window cost combination land in v0.6 if needed):
// - 2-D occupancy only.
// - Robot modelled as a point (caller adds safety inflation to
//   the underlying occupancy grid).
// - Histogram smoothing is a simple 3-bin box (not the full VFH+
//   primary/binary mask cascade).
//
// Compile: clang -c stdlib/runtime/vfh_rt.c -o target/vfh.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>
#ifndef M_PI
#define M_PI 3.141592653589793
#endif
#define TWOPI (2.0 * M_PI)

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static double _wrap_pi(double a) {
    while (a >  M_PI) a -= TWOPI;
    while (a < -M_PI) a += TWOPI;
    return a;
}

// Build polar histogram, find best heading, return success.
//
// occ is double[H][W] in row-major (occ[iy*W + ix]); cell is
// "occupied" iff value >= occ_threshold.
// The grid origin (0,0) cell-center is at world (ox, oy);
// cell size is `cell_size`.
//
// Output:
//   *steer_bearing_out_ptr — steered world-frame bearing (rad)
//   Returns 1 on success; 0 if no valley found or bad input.
long long nuc_vfh_step(long long occ_ptr,
                       long long W_, long long H_,
                       long long cell_size_b,
                       long long ox_b, long long oy_b,
                       long long occ_threshold_b,
                       long long robot_x_b, long long robot_y_b,
                       long long goal_x_b, long long goal_y_b,
                       long long window_radius_b,
                       long long n_bins_,
                       long long density_threshold_b,
                       long long steer_bearing_out_ptr)
{
    int W = (int)W_, H = (int)H_;
    int n_bins = (int)n_bins_;
    double *steer_out = (double *)(void *)(size_t)steer_bearing_out_ptr;
    const double *occ = (const double *)(void *)(size_t)occ_ptr;
    if (!steer_out || !occ || W <= 0 || H <= 0 || n_bins < 4) return 0;

    double cell = _i2f(cell_size_b);
    double ox = _i2f(ox_b), oy = _i2f(oy_b);
    double th = _i2f(occ_threshold_b);
    double rx = _i2f(robot_x_b), ry = _i2f(robot_y_b);
    double gx = _i2f(goal_x_b), gy = _i2f(goal_y_b);
    double radius = _i2f(window_radius_b);
    double dens_thr = _i2f(density_threshold_b);
    if (cell <= 0 || radius <= 0) return 0;

    double *hist = (double *)calloc(n_bins, sizeof(double));
    if (!hist) return 0;

    // Build histogram over cells within window_radius of the robot.
    double a = 1.0;
    double b = a / (radius * radius);   // weight=0 at window edge
    int ix_min = (int)floor((rx - radius - ox) / cell);
    int ix_max = (int)ceil((rx + radius - ox) / cell);
    int iy_min = (int)floor((ry - radius - oy) / cell);
    int iy_max = (int)ceil((ry + radius - oy) / cell);
    if (ix_min < 0) ix_min = 0;
    if (iy_min < 0) iy_min = 0;
    if (ix_max >= W) ix_max = W - 1;
    if (iy_max >= H) iy_max = H - 1;

    for (int iy = iy_min; iy <= iy_max; iy++) {
        for (int ix = ix_min; ix <= ix_max; ix++) {
            if (occ[iy * W + ix] < th) continue;
            double cx = ox + (ix + 0.5) * cell;
            double cy = oy + (iy + 0.5) * cell;
            double dx = cx - rx, dy = cy - ry;
            double d2 = dx*dx + dy*dy;
            if (d2 > radius * radius) continue;
            double w = a - b * d2;
            if (w < 0) w = 0;
            double bearing = atan2(dy, dx);   // world-frame bearing
            double nb = (bearing + M_PI) / TWOPI;   // [0,1)
            int bin = (int)floor(nb * n_bins);
            if (bin < 0) bin = 0;
            if (bin >= n_bins) bin = n_bins - 1;
            hist[bin] += w;
        }
    }

    // Smooth: 3-bin box average (circular).
    double *sm = (double *)calloc(n_bins, sizeof(double));
    if (!sm) { free(hist); return 0; }
    for (int i = 0; i < n_bins; i++) {
        int p = (i - 1 + n_bins) % n_bins;
        int n = (i + 1) % n_bins;
        sm[i] = (hist[p] + hist[i] + hist[n]) / 3.0;
    }

    // Threshold: free bins are those with density < dens_thr.
    // Find the valley whose CENTER bearing is closest to goal.
    double goal_bearing = atan2(gy - ry, gx - rx);
    double best_diff = 1e300;
    int best_center_bin = -1;
    int valley_started = -1;
    // Walk the histogram, tracking valley runs. To handle wrap-around
    // we walk twice the length and look at runs that don't already
    // close at index n_bins.
    for (int i = 0; i < 2 * n_bins; i++) {
        int idx = i % n_bins;
        int free_bin = (sm[idx] < dens_thr) ? 1 : 0;
        if (free_bin) {
            if (valley_started < 0) valley_started = i;
        } else {
            if (valley_started >= 0) {
                int len = i - valley_started;
                if (len >= 1 && len <= n_bins) {
                    int center = (valley_started + len / 2) % n_bins;
                    double bearing_center = -M_PI + (center + 0.5) * (TWOPI / n_bins);
                    double diff = fabs(_wrap_pi(bearing_center - goal_bearing));
                    if (diff < best_diff) {
                        best_diff = diff;
                        best_center_bin = center;
                    }
                }
                valley_started = -1;
                if (i >= n_bins) break;
            }
        }
        if (i >= n_bins && valley_started < 0) break;
    }
    // Edge case: entire histogram is free.
    if (best_center_bin < 0) {
        int all_free = 1;
        for (int i = 0; i < n_bins; i++) if (sm[i] >= dens_thr) { all_free = 0; break; }
        if (all_free) {
            *steer_out = goal_bearing;
            free(hist); free(sm);
            return 1;
        }
        free(hist); free(sm);
        return 0;
    }

    double bearing = -M_PI + (best_center_bin + 0.5) * (TWOPI / n_bins);
    *steer_out = bearing;
    free(hist); free(sm);
    return 1;
}
