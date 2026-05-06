// chomp_rt.c — Covariant Hamiltonian Optimization for Motion
// Planning (CHOMP, Ratliff et al. 2009). Gradient-based trajectory
// optimizer that balances path smoothness against obstacle cost.
//
// Given an initial discretized path (N waypoints in n_dim joint
// space), CHOMP iteratively descends the trajectory cost
//
//     F(ξ) = w_smooth · F_smooth(ξ) + w_obs · F_obs(ξ)
//
// where F_smooth is the integrated acceleration squared (penalizes
// jerky paths) and F_obs is the user-supplied obstacle cost
// integrated along the trajectory. Endpoints are clamped (the
// optimizer never moves the start or goal); interior points are
// the optimization variables.
//
// Common use case: take a roughly-shaped path from RRT or PRM
// and smooth it while keeping it collision-free. Often run as a
// post-processing step after a planner produces a discretely
// collision-free path that is otherwise jerky.
//
// Implementation notes:
// - Gradient of F_smooth at interior point i: 2·(2·ξ_i − ξ_{i-1} − ξ_{i+1})
//   (the discrete second-difference Laplacian).
// - Gradient of F_obs at point i: numerical finite difference on
//   the user-supplied cost function.
// - Update rule: ξ_i ← ξ_i − α · (w_smooth · ∇F_smooth + w_obs · ∇F_obs).
//   Standard gradient descent; the "covariant" term in CHOMP-proper
//   pre-conditions the gradient by an inverse smoothness metric A⁻¹
//   to keep steps from de-smoothing the trajectory; here we
//   approximate that effect by clamping the per-step move magnitude
//   (much simpler, similar empirical behavior on typical paths).
// - nuc_chomp_optimize_covariant applies the actual inverse discrete
//   smoothness metric over the interior waypoints before stepping.
// - Endpoints (ξ_0, ξ_{N-1}) are NEVER moved.
//
// Compile: clang -c stdlib/runtime/chomp_rt.c -o target/chomp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*obs_cost_fn_t)(long long config_ptr);

// Compute the obstacle cost at a single waypoint (caller-supplied
// function pointer). Returns the cost as a regular `double`. If the
// callback is null, returns 0 (no obstacle term).
static double _obs_cost_at(obs_cost_fn_t fn, double *config) {
    if (!fn) return 0;
    long long b = fn((long long)(size_t)config);
    return _i2f(b);
}

// Numerical gradient of the obstacle cost wrt a single waypoint.
// Writes n_dim doubles into `out`.
static void _obs_grad_at(obs_cost_fn_t fn, double *config, int n_dim,
                         double eps, double *out)
{
    if (!fn) {
        for (int i = 0; i < n_dim; i++) out[i] = 0;
        return;
    }
    double base = _obs_cost_at(fn, config);
    for (int j = 0; j < n_dim; j++) {
        double saved = config[j];
        config[j] = saved + eps;
        double up = _obs_cost_at(fn, config);
        config[j] = saved;
        out[j] = (up - base) / eps;
    }
}

// Solve (A + reg I) x = rhs for the CHOMP smoothness metric over
// interior waypoints with clamped endpoints. A is the tri-diagonal
// Dirichlet second-difference matrix: diag 2, off-diag -1.
static int _solve_smoothness_metric(int m, double reg,
                                    const double *rhs, double *out,
                                    double *cprime, double *dprime)
{
    if (m <= 0) return 0;
    if (reg < 0) reg = 0;
    double diag = 2.0 + reg;
    double denom = diag;
    if (fabs(denom) < 1e-12) return 0;

    cprime[0] = (m > 1) ? (-1.0 / denom) : 0.0;
    dprime[0] = rhs[0] / denom;

    for (int i = 1; i < m; i++) {
        denom = diag + cprime[i - 1];
        if (fabs(denom) < 1e-12) return 0;
        cprime[i] = (i < m - 1) ? (-1.0 / denom) : 0.0;
        dprime[i] = (rhs[i] + dprime[i - 1]) / denom;
    }

    out[m - 1] = dprime[m - 1];
    for (int i = m - 2; i >= 0; i--) {
        out[i] = dprime[i] - cprime[i] * out[i + 1];
    }
    return 1;
}

// CHOMP optimizer entry point. `path_ptr` is a caller-allocated
// `double[N * n_dim]` buffer; the function modifies it in place.
// Returns the number of iterations actually performed (≤ max_iters)
// or -1 on bad input.
//
// `obs_cost_fp` may be 0 (no obstacles) for pure smoothness
// optimization.
long long nuc_chomp_optimize(
    long long path_ptr, long long N, long long n_dim,
    long long max_iters,
    long long alpha_b, long long w_smooth_b, long long w_obs_b,
    long long obs_cost_fp)
{
    if (N < 3 || n_dim <= 0) return -1;
    double *path = (double *)(void *)(size_t)path_ptr;
    if (!path) return -1;
    obs_cost_fn_t obs_fn = (obs_cost_fn_t)(void *)(size_t)obs_cost_fp;

    int n = (int)n_dim;
    int Ni = (int)N;
    double alpha = _i2f(alpha_b);
    double w_smooth = _i2f(w_smooth_b);
    double w_obs    = _i2f(w_obs_b);
    double eps = 1e-5;

    // Per-iteration scratch: gradient accumulator for each interior
    // waypoint, obstacle gradient buffer.
    double *grad = (double *)malloc((Ni - 2) * n * sizeof(double));
    double *obs_grad = (double *)malloc(n * sizeof(double));
    // Per-iteration max move (for "covariant" approximation —
    // limit step magnitude to avoid de-smoothing).
    double max_step = 0.1;

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // Build the gradient.
        for (int i = 1; i < Ni - 1; i++) {
            double *xi   = path + i * n;
            double *xim  = path + (i - 1) * n;
            double *xip  = path + (i + 1) * n;
            double *gi   = grad + (i - 1) * n;
            // Smoothness gradient: 2·(2·xi − xim − xip)
            for (int j = 0; j < n; j++) {
                gi[j] = 2.0 * (2.0 * xi[j] - xim[j] - xip[j]) * w_smooth;
            }
            // Obstacle gradient at this waypoint.
            if (obs_fn && w_obs > 0) {
                _obs_grad_at(obs_fn, xi, n, eps, obs_grad);
                for (int j = 0; j < n; j++) gi[j] += w_obs * obs_grad[j];
            }
        }
        // Apply the gradient with step-size clamping.
        double max_move = 0;
        for (int i = 1; i < Ni - 1; i++) {
            double *xi = path + i * n;
            double *gi = grad + (i - 1) * n;
            double m2 = 0;
            for (int j = 0; j < n; j++) {
                double dx = -alpha * gi[j];
                if (fabs(dx) > max_step) dx = (dx > 0 ? max_step : -max_step);
                xi[j] += dx;
                m2 += dx * dx;
            }
            if (m2 > max_move) max_move = m2;
        }
        // Convergence check: if the largest single waypoint movement
        // is below threshold, we're done.
        if (max_move < 1e-12) { iter++; break; }
    }

    free(grad); free(obs_grad);
    return iter;
}

// Full covariant CHOMP entry point. This matches nuc_chomp_optimize's
// cost model and endpoint constraints, but preconditions each
// dimension's interior gradient by the inverse smoothness metric
// before applying the step:
//
//     delta = A^-1 grad
//     xi <- xi - alpha * delta
//
// `metric_reg` adds diagonal regularization to A for numerical
// damping. `max_step` is optional; pass <= 0 to disable per-coordinate
// clamping, or a positive bit-cast f64 to cap one coordinate's step.
long long nuc_chomp_optimize_covariant(
    long long path_ptr, long long N, long long n_dim,
    long long max_iters,
    long long alpha_b, long long w_smooth_b, long long w_obs_b,
    long long obs_cost_fp,
    long long metric_reg_b, long long max_step_b)
{
    if (N < 3 || n_dim <= 0) return -1;
    double *path = (double *)(void *)(size_t)path_ptr;
    if (!path) return -1;
    obs_cost_fn_t obs_fn = (obs_cost_fn_t)(void *)(size_t)obs_cost_fp;

    int n = (int)n_dim;
    int Ni = (int)N;
    int m = Ni - 2;
    double alpha = _i2f(alpha_b);
    double w_smooth = _i2f(w_smooth_b);
    double w_obs    = _i2f(w_obs_b);
    double metric_reg = _i2f(metric_reg_b);
    double max_step = _i2f(max_step_b);
    double eps = 1e-5;

    double *grad = (double *)malloc(m * n * sizeof(double));
    double *obs_grad = (double *)malloc(n * sizeof(double));
    double *rhs = (double *)malloc(m * sizeof(double));
    double *precond = (double *)malloc(m * sizeof(double));
    double *cprime = (double *)malloc(m * sizeof(double));
    double *dprime = (double *)malloc(m * sizeof(double));
    if (!grad || !obs_grad || !rhs || !precond || !cprime || !dprime) {
        free(grad); free(obs_grad); free(rhs); free(precond); free(cprime); free(dprime);
        return -1;
    }

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        for (int i = 1; i < Ni - 1; i++) {
            double *xi   = path + i * n;
            double *xim  = path + (i - 1) * n;
            double *xip  = path + (i + 1) * n;
            double *gi   = grad + (i - 1) * n;
            for (int j = 0; j < n; j++) {
                gi[j] = 2.0 * (2.0 * xi[j] - xim[j] - xip[j]) * w_smooth;
            }
            if (obs_fn && w_obs > 0) {
                _obs_grad_at(obs_fn, xi, n, eps, obs_grad);
                for (int j = 0; j < n; j++) gi[j] += w_obs * obs_grad[j];
            }
        }

        for (int j = 0; j < n; j++) {
            for (int i = 0; i < m; i++) rhs[i] = grad[i * n + j];
            if (!_solve_smoothness_metric(m, metric_reg, rhs, precond, cprime, dprime)) {
                free(grad); free(obs_grad); free(rhs); free(precond); free(cprime); free(dprime);
                return -1;
            }
            for (int i = 0; i < m; i++) grad[i * n + j] = precond[i];
        }

        double max_move = 0;
        for (int i = 1; i < Ni - 1; i++) {
            double *xi = path + i * n;
            double *gi = grad + (i - 1) * n;
            double m2 = 0;
            for (int j = 0; j < n; j++) {
                double dx = -alpha * gi[j];
                if (max_step > 0 && fabs(dx) > max_step) {
                    dx = (dx > 0 ? max_step : -max_step);
                }
                xi[j] += dx;
                m2 += dx * dx;
            }
            if (m2 > max_move) max_move = m2;
        }
        if (max_move < 1e-12) { iter++; break; }
    }

    free(grad); free(obs_grad); free(rhs); free(precond); free(cprime); free(dprime);
    return iter;
}

// Diagnostic helper: integrated trajectory cost (smoothness + obstacle).
// Useful for verifying convergence.
long long nuc_chomp_cost(
    long long path_ptr, long long N, long long n_dim,
    long long w_smooth_b, long long w_obs_b,
    long long obs_cost_fp)
{
    if (N < 3 || n_dim <= 0) return _f2i(0.0);
    double *path = (double *)(void *)(size_t)path_ptr;
    if (!path) return _f2i(0.0);
    obs_cost_fn_t obs_fn = (obs_cost_fn_t)(void *)(size_t)obs_cost_fp;
    int n = (int)n_dim;
    int Ni = (int)N;
    double w_smooth = _i2f(w_smooth_b);
    double w_obs    = _i2f(w_obs_b);
    double smooth = 0;
    for (int i = 1; i < Ni - 1; i++) {
        double *xi   = path + i * n;
        double *xim  = path + (i - 1) * n;
        double *xip  = path + (i + 1) * n;
        for (int j = 0; j < n; j++) {
            double accel = 2.0 * xi[j] - xim[j] - xip[j];
            smooth += accel * accel;
        }
    }
    double obs = 0;
    if (obs_fn) {
        for (int i = 0; i < Ni; i++) {
            obs += _obs_cost_at(obs_fn, path + i * n);
        }
    }
    return _f2i(w_smooth * smooth + w_obs * obs);
}
