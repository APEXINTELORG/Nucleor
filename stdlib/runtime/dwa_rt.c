// dwa_rt.c — Dynamic Window Approach (Fox, Burgard & Thrun 1997)
// local planner for differential-drive robots.
//
// Selects the best (v, ω) command at the current control step
// by: (1) restricting candidates to the "dynamic window" of
// velocities reachable from the current velocity within one step
// given the robot's acceleration limits; (2) for each candidate,
// rolling out the trajectory T_horizon seconds forward; (3)
// scoring each trajectory by a weighted sum of:
//   - obstacle clearance (distance to nearest obstacle along traj)
//   - heading toward the goal (smaller angle = better)
//   - forward velocity (prefer faster motion)
// (4) returning the highest-scoring (v, ω).
//
// Foundation for ROS-style local navigation: the global planner
// (RRT / A* / PRM) emits a path; DWA picks the local commands
// that follow it while reactively avoiding obstacles that the
// planner didn't see.
//
// User callback: distance to nearest obstacle from a 2D point.
//   obs_dist_fp: fn(x_b, y_b) -> i64 (bit-cast f64 distance)
//
// **Limitations** (TEB / MPC-style local planners with
// trajectory-level optimization land in v0.6 if needed):
// - Differential-drive only (Ackermann variant adds steering
//   constraint).
// - Constant velocity within each candidate (no piecewise
//   acceleration profile).
// - Brute-force grid search over (v, ω) candidates.
//
// Compile: clang -c stdlib/runtime/dwa_rt.c -o target/dwa.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*obs_dist_fn_t)(long long x_b, long long y_b);

// Compute one DWA step. Returns 0 on success and writes the
// chosen (v_cmd, ω_cmd) to v_out_ptr / w_out_ptr.
//
// All scalar parameters are bit-cast f64 i64 except the integer
// sample counts.
//
// Robot kinematic limits: v_min, v_max (m/s); w_min, w_max (rad/s);
// a_max (m/s²); alpha_max (rad/s²).
// Sampling: n_v × n_w grid in the dynamic window.
// Trajectory rollout: T_horizon seconds at dt step.
// Score weights: w_clearance, w_heading, w_velocity.
long long nuc_dwa_step(
    long long x_b, long long y_b, long long theta_b,
    long long v_curr_b, long long w_curr_b,
    long long gx_b, long long gy_b,
    long long v_min_b, long long v_max_b,
    long long w_min_b, long long w_max_b,
    long long a_max_b, long long alpha_max_b,
    long long n_v_, long long n_w_,
    long long dt_b, long long T_horizon_b,
    long long w_clear_b, long long w_head_b, long long w_vel_b,
    long long obs_dist_fp,
    long long v_out_ptr, long long w_out_ptr)
{
    int n_v = (int)n_v_, n_w = (int)n_w_;
    if (n_v <= 0 || n_w <= 0) return -1;
    obs_dist_fn_t obs_fn = (obs_dist_fn_t)(void *)(size_t)obs_dist_fp;
    double *v_out = (double *)(void *)(size_t)v_out_ptr;
    double *w_out = (double *)(void *)(size_t)w_out_ptr;
    if (!v_out || !w_out) return -1;

    double x = _i2f(x_b), y = _i2f(y_b), th = _i2f(theta_b);
    double v_curr = _i2f(v_curr_b), w_curr = _i2f(w_curr_b);
    double gx = _i2f(gx_b), gy = _i2f(gy_b);
    double v_min = _i2f(v_min_b), v_max = _i2f(v_max_b);
    double w_min = _i2f(w_min_b), w_max = _i2f(w_max_b);
    double a_max = _i2f(a_max_b), alpha_max = _i2f(alpha_max_b);
    double dt = _i2f(dt_b), T = _i2f(T_horizon_b);
    double w_c = _i2f(w_clear_b), w_h = _i2f(w_head_b), w_v = _i2f(w_vel_b);

    // Dynamic window.
    double vw_lo = v_curr - a_max * dt;     if (vw_lo < v_min) vw_lo = v_min;
    double vw_hi = v_curr + a_max * dt;     if (vw_hi > v_max) vw_hi = v_max;
    double ww_lo = w_curr - alpha_max * dt; if (ww_lo < w_min) ww_lo = w_min;
    double ww_hi = w_curr + alpha_max * dt; if (ww_hi > w_max) ww_hi = w_max;
    if (vw_hi < vw_lo) vw_hi = vw_lo;
    if (ww_hi < ww_lo) ww_hi = ww_lo;

    int n_steps = (int)(T / dt);
    if (n_steps < 1) n_steps = 1;

    double best_score = -1e300;
    double best_v = 0, best_w = 0;
    for (int iv = 0; iv < n_v; iv++) {
        double v = vw_lo + (vw_hi - vw_lo) * (n_v == 1 ? 0.5 : (double)iv / (n_v - 1));
        for (int iw = 0; iw < n_w; iw++) {
            double w = ww_lo + (ww_hi - ww_lo) * (n_w == 1 ? 0.5 : (double)iw / (n_w - 1));
            // Roll out trajectory.
            double tx = x, ty = y, tth = th;
            double min_clear = 1e30;
            int collision = 0;
            for (int s = 0; s < n_steps; s++) {
                tx += v * cos(tth) * dt;
                ty += v * sin(tth) * dt;
                tth += w * dt;
                if (obs_fn) {
                    double d = _i2f(obs_fn(_f2i(tx), _f2i(ty)));
                    if (d < min_clear) min_clear = d;
                    if (d <= 0) { collision = 1; break; }
                }
            }
            if (collision) continue;
            // Normalize all three score components to [0, 1] so the
            // weights w_clear / w_head / w_vel are comparable. This
            // is the canonical DWA formulation — without
            // normalization, "stop" trivially wins on the unbounded
            // clearance term.
            double max_clear_norm = 2.0;   // saturate clearance at 2 m
            double clear_score = (min_clear > max_clear_norm)
                ? 1.0 : min_clear / max_clear_norm;
            double goal_dx = gx - tx, goal_dy = gy - ty;
            double target_heading = atan2(goal_dy, goal_dx);
            double heading_err = target_heading - tth;
            while (heading_err >  M_PI) heading_err -= 2.0 * M_PI;
            while (heading_err < -M_PI) heading_err += 2.0 * M_PI;
            double head_score = 1.0 - fabs(heading_err) / M_PI;
            // Velocity score in [0, 1] — only positive forward
            // velocity counts; reverse / stopped score 0.
            double vel_score = (v > 0 && v_max > 0) ? (v / v_max) : 0.0;
            if (vel_score > 1.0) vel_score = 1.0;

            double total = w_c * clear_score + w_h * head_score + w_v * vel_score;
            if (total > best_score) {
                best_score = total;
                best_v = v;
                best_w = w;
            }
        }
    }
    *v_out = best_v;
    *w_out = best_w;
    return 0;
}
