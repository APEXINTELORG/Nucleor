// apf_rt.c — Artificial potential field for reactive motion.
//
// Khatib 1986. Combine an attractive potential pulling the robot
// toward the goal with repulsive potentials pushing it away from
// nearby obstacles. The gradient (force) at the robot's current
// position gives the desired direction of motion.
//
//   F_att(q) = −k_att · (q − q_goal)
//   F_rep(q) = Σ over obstacles within d_max:
//                k_rep · (1/d − 1/d_max) · (1/d²) · (q − q_obs)/|q − q_obs|
//
//   F_total = F_att + F_rep         → direction of motion
//
// The simplest reactive controller — fast, no rollout, no
// optimization. Common baseline alongside DWA / pure pursuit.
// Works well for sparse obstacles + open goal direction; struggles
// with local minima (concave obstacles, narrow passages between
// obstacles). For those, use DWA or a planner.
//
// Limitations (Vector Field Histogram, Navigation Functions
// land in v0.6 if needed for narrow-passage / local-minimum
// scenarios):
// - 2D only (3D extension is straightforward — change every
//   2-vector to 3-vector).
// - Caller supplies obstacle list (point obstacles); for arbitrary
//   shapes, use a distance callback instead.
// - No local-minimum escape — gets stuck in concave obstacles
//   facing the goal.
//
// Compile: clang -c stdlib/runtime/apf_rt.c -o target/apf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Compute the 2D potential-field force at point (x, y) given the
// goal (gx, gy) and N point obstacles in `obs_ptr` (double[N*2]).
// Writes (Fx, Fy) to F_out_ptr.
//
//   k_att, k_rep: gain scalars.
//   d_max:        repulsion influence range (no force from obstacles
//                 farther than this).
//
// Returns 0 on success.
long long nuc_apf_force_2d(
    long long x_b, long long y_b,
    long long gx_b, long long gy_b,
    long long obs_ptr, long long n_obs_,
    long long k_att_b, long long k_rep_b, long long d_max_b,
    long long F_out_ptr)
{
    int n = (int)n_obs_;
    const double *obs = (const double *)(void *)(size_t)obs_ptr;
    double *F = (double *)(void *)(size_t)F_out_ptr;
    if (!F || (n > 0 && !obs)) return -1;
    double x = _i2f(x_b), y = _i2f(y_b);
    double gx = _i2f(gx_b), gy = _i2f(gy_b);
    double k_att = _i2f(k_att_b), k_rep = _i2f(k_rep_b), d_max = _i2f(d_max_b);

    // Attractive force: F_att = -k_att (q - q_goal) = k_att (q_goal - q).
    F[0] = k_att * (gx - x);
    F[1] = k_att * (gy - y);

    // Repulsive forces from each obstacle within d_max.
    for (int i = 0; i < n; i++) {
        double dx = x - obs[i*2 + 0];
        double dy = y - obs[i*2 + 1];
        double d = sqrt(dx*dx + dy*dy);
        if (d < 1e-9) continue;
        if (d >= d_max) continue;
        double mag = k_rep * (1.0/d - 1.0/d_max) / (d * d);
        F[0] += mag * dx;
        F[1] += mag * dy;
    }
    return 0;
}

// Convenience: integrate one APF step. Given current pose (x, y),
// step size dt, returns the new (x', y') after moving along the
// (normalized) potential force direction by `dt · v`. Useful for
// quick demos / simulation; production code typically uses the
// raw force from `nuc_apf_force_2d` and integrates with a proper
// dynamics model.
long long nuc_apf_step_2d(
    long long x_b, long long y_b,
    long long gx_b, long long gy_b,
    long long obs_ptr, long long n_obs_,
    long long k_att_b, long long k_rep_b, long long d_max_b,
    long long v_b, long long dt_b,
    long long x_out_ptr, long long y_out_ptr)
{
    double F[2];
    long long rc = nuc_apf_force_2d(x_b, y_b, gx_b, gy_b,
        obs_ptr, n_obs_, k_att_b, k_rep_b, d_max_b,
        (long long)(size_t)F);
    if (rc != 0) return rc;
    double mag = sqrt(F[0]*F[0] + F[1]*F[1]);
    double v = _i2f(v_b), dt = _i2f(dt_b);
    double *xo = (double *)(void *)(size_t)x_out_ptr;
    double *yo = (double *)(void *)(size_t)y_out_ptr;
    if (!xo || !yo) return -1;
    if (mag < 1e-9) {
        *xo = _i2f(x_b);
        *yo = _i2f(y_b);
        return 0;
    }
    double nx = F[0] / mag, ny = F[1] / mag;
    *xo = _i2f(x_b) + nx * v * dt;
    *yo = _i2f(y_b) + ny * v * dt;
    return 0;
}
