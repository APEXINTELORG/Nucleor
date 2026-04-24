// ilqr_rt.c — Iterative Linear Quadratic Regulator (iLQR, Tassa
// et al. 2012). Locally-optimal nonlinear trajectory optimizer
// that's the workhorse inner loop of model predictive control
// (MPC) and direct shooting trajectory optimization.
//
// The user supplies the dynamics f(x, u) → x_next, the stage cost
// ℓ(x, u), and the terminal cost ℓ_f(x_T), all as function-pointer
// callbacks. iLQR iteratively:
//
//   1. Forward-rolls the current control sequence through the
//      dynamics to get a trajectory.
//   2. Quadratizes the cost-to-go around that trajectory by
//      linearizing the dynamics and quadratizing the cost.
//   3. Solves the resulting LQR sub-problem backward (Riccati
//      recursion) to get state-feedback gains and feedforward
//      control updates.
//   4. Forward-rolls again with the updated controls under a line
//      search until the cost actually decreases.
//
// Both gradients and Hessians are computed by numerical finite
// differences against the user-supplied callbacks. This trades
// computational cost for implementation simplicity — for small to
// medium horizons (T ≤ 100) and state/control dimensions
// (n_x ≤ 16, n_u ≤ 8), the FD overhead is dominated by the
// per-iteration backward-pass linear algebra.
//
// **Limitations** (analytical gradients via the user-supplied
// "linearized dynamics" callback land in v0.6 if needed for
// performance-critical use cases):
// - Numerical FD for everything (slower than user-supplied
//   analytical gradients).
// - No constraints (box constraints on u land in v0.6 via DDP
//   variant or projected line search).
// - No explicit regularization schedule (current impl uses a
//   fixed small Q_uu regularizer).
//
// Compile: clang -c stdlib/runtime/ilqr_rt.c -o target/ilqr.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*cost_fn_t)(long long x_ptr, long long u_ptr);
typedef long long (*tcost_fn_t)(long long x_ptr);

// In-place Gauss-Jordan inverse on a small n×n matrix. Returns 1
// on success, 0 if singular. Caller-allocated `Ainv` (n*n).
static int _gj_inv(double *A, int n, double *Ainv) {
    int aug_w = 2 * n;
    double *aug = (double *)malloc(n * aug_w * sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*aug_w + j] = A[i*n + j];
        for (int j = 0; j < n; j++) aug[i*aug_w + n + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < n; i++) {
        int piv = i;
        for (int r = i + 1; r < n; r++)
            if (fabs(aug[r*aug_w + i]) > fabs(aug[piv*aug_w + i])) piv = r;
        if (fabs(aug[piv*aug_w + i]) < 1e-12) { free(aug); return 0; }
        if (piv != i) {
            for (int j = 0; j < aug_w; j++) {
                double t = aug[i*aug_w + j];
                aug[i*aug_w + j] = aug[piv*aug_w + j];
                aug[piv*aug_w + j] = t;
            }
        }
        double inv = 1.0 / aug[i*aug_w + i];
        for (int j = 0; j < aug_w; j++) aug[i*aug_w + j] *= inv;
        for (int r = 0; r < n; r++) {
            if (r == i) continue;
            double f = aug[r*aug_w + i];
            for (int j = 0; j < aug_w; j++) aug[r*aug_w + j] -= f * aug[i*aug_w + j];
        }
    }
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) Ainv[i*n + j] = aug[i*aug_w + n + j];
    free(aug);
    return 1;
}

// Numerical Jacobian of dynamics f: ∂x_next / ∂(x, u) via central
// differences. Writes A (n_x × n_x) and B (n_x × n_u).
static void _dyn_jacobian(dyn_fn_t f,
    double *x, double *u, int n_x, int n_u,
    double *A, double *B,
    double *scratch_xp, double *scratch_xn, double *scratch_xn2)
{
    double eps = 1e-6;
    // ∂/∂x_j
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xn);
        x[j] = sv - eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xn2);
        x[j] = sv;
        for (int i = 0; i < n_x; i++) A[i*n_x + j] = (scratch_xn[i] - scratch_xn2[i]) / (2.0 * eps);
    }
    // ∂/∂u_j
    for (int j = 0; j < n_u; j++) {
        double sv = u[j];
        u[j] = sv + eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xn);
        u[j] = sv - eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xn2);
        u[j] = sv;
        for (int i = 0; i < n_x; i++) B[i*n_u + j] = (scratch_xn[i] - scratch_xn2[i]) / (2.0 * eps);
    }
    (void)scratch_xp;
}

// Numerical gradient and diagonal-Hessian approximation of stage
// cost. Writes l_x (n_x), l_u (n_u), l_xx (n_x*n_x), l_uu (n_u*n_u).
// Cross-Hessian l_ux is approximated as zero (Gauss-Newton style).
static void _cost_quadratize(cost_fn_t l, double *x, double *u,
    int n_x, int n_u,
    double *l_x, double *l_u, double *l_xx, double *l_uu)
{
    double eps = 1e-5;
    double base = _i2f(l((long long)(size_t)x, (long long)(size_t)u));

    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        double up = _i2f(l((long long)(size_t)x, (long long)(size_t)u));
        x[j] = sv - eps;
        double dn = _i2f(l((long long)(size_t)x, (long long)(size_t)u));
        x[j] = sv;
        l_x[j] = (up - dn) / (2.0 * eps);
        // Diagonal Hessian via finite difference of the gradient.
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        // Off-diagonals zeroed (Gauss-Newton).
        for (int k = 0; k < n_x; k++) l_xx[j*n_x + k] = (j == k) ? dd : 0.0;
    }
    for (int j = 0; j < n_u; j++) {
        double sv = u[j];
        u[j] = sv + eps;
        double up = _i2f(l((long long)(size_t)x, (long long)(size_t)u));
        u[j] = sv - eps;
        double dn = _i2f(l((long long)(size_t)x, (long long)(size_t)u));
        u[j] = sv;
        l_u[j] = (up - dn) / (2.0 * eps);
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        for (int k = 0; k < n_u; k++) l_uu[j*n_u + k] = (j == k) ? dd : 0.0;
    }
}

// Numerical gradient + diagonal Hessian of terminal cost.
static void _tcost_quadratize(tcost_fn_t lf, double *x, int n_x,
    double *V_x, double *V_xx)
{
    double eps = 1e-5;
    double base = _i2f(lf((long long)(size_t)x));
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        double up = _i2f(lf((long long)(size_t)x));
        x[j] = sv - eps;
        double dn = _i2f(lf((long long)(size_t)x));
        x[j] = sv;
        V_x[j] = (up - dn) / (2.0 * eps);
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        for (int k = 0; k < n_x; k++) V_xx[j*n_x + k] = (j == k) ? dd : 0.0;
    }
}

// Total trajectory cost.
static double _total_cost(dyn_fn_t f, cost_fn_t l, tcost_fn_t lf,
    double *x0, double *u_seq, int n_x, int n_u, int T,
    double *x_traj_out)
{
    // Forward roll-out.
    memcpy(x_traj_out, x0, n_x * sizeof(double));
    double total = 0;
    for (int t = 0; t < T; t++) {
        double *xt = x_traj_out + t * n_x;
        double *ut = u_seq + t * n_u;
        total += _i2f(l((long long)(size_t)xt, (long long)(size_t)ut));
        f((long long)(size_t)xt, (long long)(size_t)ut,
          (long long)(size_t)(x_traj_out + (t+1)*n_x));
    }
    total += _i2f(lf((long long)(size_t)(x_traj_out + T*n_x)));
    return total;
}

// iLQR optimizer entry point. `u_seq_ptr` is a caller-allocated
// `double[T * n_u]` buffer, modified in place. Returns the number
// of iterations actually performed (≤ max_iters), or -1 on bad
// input.
long long nuc_ilqr_optimize(
    long long n_x_, long long n_u_, long long T_,
    long long x0_ptr, long long u_seq_ptr,
    long long max_iters,
    long long dynamics_fp,
    long long stage_cost_fp,
    long long terminal_cost_fp)
{
    int n_x = (int)n_x_, n_u = (int)n_u_, T = (int)T_;
    if (n_x <= 0 || n_u <= 0 || T <= 0) return -1;
    double *x0 = (double *)(void *)(size_t)x0_ptr;
    double *u_seq = (double *)(void *)(size_t)u_seq_ptr;
    if (!x0 || !u_seq) return -1;
    dyn_fn_t f   = (dyn_fn_t)(void *)(size_t)dynamics_fp;
    cost_fn_t l  = (cost_fn_t)(void *)(size_t)stage_cost_fp;
    tcost_fn_t lf= (tcost_fn_t)(void *)(size_t)terminal_cost_fp;
    if (!f || !l || !lf) return -1;

    // Allocate work buffers.
    double *x_traj      = (double *)malloc((T + 1) * n_x * sizeof(double));
    double *x_traj_new  = (double *)malloc((T + 1) * n_x * sizeof(double));
    double *u_new       = (double *)malloc(T * n_u * sizeof(double));
    double *V_x         = (double *)malloc(n_x * sizeof(double));
    double *V_xx        = (double *)malloc(n_x * n_x * sizeof(double));
    double *K_seq       = (double *)malloc(T * n_u * n_x * sizeof(double));
    double *k_seq       = (double *)malloc(T * n_u * sizeof(double));
    double *A           = (double *)malloc(n_x * n_x * sizeof(double));
    double *B           = (double *)malloc(n_x * n_u * sizeof(double));
    double *l_x         = (double *)malloc(n_x * sizeof(double));
    double *l_u         = (double *)malloc(n_u * sizeof(double));
    double *l_xx        = (double *)malloc(n_x * n_x * sizeof(double));
    double *l_uu        = (double *)malloc(n_u * n_u * sizeof(double));
    double *Q_x         = (double *)malloc(n_x * sizeof(double));
    double *Q_u         = (double *)malloc(n_u * sizeof(double));
    double *Q_xx        = (double *)malloc(n_x * n_x * sizeof(double));
    double *Q_uu        = (double *)malloc(n_u * n_u * sizeof(double));
    double *Q_ux        = (double *)malloc(n_u * n_x * sizeof(double));
    double *Q_uu_inv    = (double *)malloc(n_u * n_u * sizeof(double));
    double *scr1        = (double *)malloc(n_x * sizeof(double));
    double *scr2        = (double *)malloc(n_x * sizeof(double));
    double *scr3        = (double *)malloc(n_x * sizeof(double));

    double cost = _total_cost(f, l, lf, x0, u_seq, n_x, n_u, T, x_traj);
    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // === Backward pass ===
        _tcost_quadratize(lf, x_traj + T * n_x, n_x, V_x, V_xx);
        for (int t = T - 1; t >= 0; t--) {
            double *xt = x_traj + t * n_x;
            double *ut = u_seq  + t * n_u;
            _dyn_jacobian(f, xt, ut, n_x, n_u, A, B, scr1, scr2, scr3);
            _cost_quadratize(l, xt, ut, n_x, n_u, l_x, l_u, l_xx, l_uu);

            // Q_x = l_x + Aᵀ·V_x.
            for (int i = 0; i < n_x; i++) {
                double s = l_x[i];
                for (int j = 0; j < n_x; j++) s += A[j*n_x + i] * V_x[j];
                Q_x[i] = s;
            }
            // Q_u = l_u + Bᵀ·V_x.
            for (int i = 0; i < n_u; i++) {
                double s = l_u[i];
                for (int j = 0; j < n_x; j++) s += B[j*n_u + i] * V_x[j];
                Q_u[i] = s;
            }
            // Q_xx = l_xx + Aᵀ·V_xx·A.
            // Compute V_xx·A first (n_x × n_x).
            double *VxxA = (double *)malloc(n_x * n_x * sizeof(double));
            for (int i = 0; i < n_x; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int k = 0; k < n_x; k++) s += V_xx[i*n_x + k] * A[k*n_x + j];
                    VxxA[i*n_x + j] = s;
                }
            for (int i = 0; i < n_x; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = l_xx[i*n_x + j];
                    for (int k = 0; k < n_x; k++) s += A[k*n_x + i] * VxxA[k*n_x + j];
                    Q_xx[i*n_x + j] = s;
                }
            // Q_uu = l_uu + Bᵀ·V_xx·B  (+ regularization for stability).
            double *VxxB = (double *)malloc(n_x * n_u * sizeof(double));
            for (int i = 0; i < n_x; i++)
                for (int j = 0; j < n_u; j++) {
                    double s = 0;
                    for (int k = 0; k < n_x; k++) s += V_xx[i*n_x + k] * B[k*n_u + j];
                    VxxB[i*n_u + j] = s;
                }
            for (int i = 0; i < n_u; i++)
                for (int j = 0; j < n_u; j++) {
                    double s = l_uu[i*n_u + j];
                    for (int k = 0; k < n_x; k++) s += B[k*n_u + i] * VxxB[k*n_u + j];
                    Q_uu[i*n_u + j] = s + (i == j ? 1e-6 : 0);  // regularizer
                }
            // Q_ux = Bᵀ·V_xx·A.
            for (int i = 0; i < n_u; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int k = 0; k < n_x; k++) s += B[k*n_u + i] * VxxA[k*n_x + j];
                    Q_ux[i*n_x + j] = s;
                }
            free(VxxA); free(VxxB);

            if (!_gj_inv(Q_uu, n_u, Q_uu_inv)) {
                // Singular Q_uu — bail.
                free(x_traj); free(x_traj_new); free(u_new);
                free(V_x); free(V_xx); free(K_seq); free(k_seq);
                free(A); free(B); free(l_x); free(l_u); free(l_xx); free(l_uu);
                free(Q_x); free(Q_u); free(Q_xx); free(Q_uu); free(Q_ux); free(Q_uu_inv);
                free(scr1); free(scr2); free(scr3);
                return iter;
            }
            // K = -Q_uu_inv · Q_ux  (n_u × n_x).
            // k = -Q_uu_inv · Q_u   (n_u).
            double *K_t = K_seq + t * n_u * n_x;
            double *k_t = k_seq + t * n_u;
            for (int i = 0; i < n_u; i++) {
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int kk = 0; kk < n_u; kk++) s += Q_uu_inv[i*n_u + kk] * Q_ux[kk*n_x + j];
                    K_t[i*n_x + j] = -s;
                }
                double s = 0;
                for (int kk = 0; kk < n_u; kk++) s += Q_uu_inv[i*n_u + kk] * Q_u[kk];
                k_t[i] = -s;
            }
            // Update value-function approximation:
            //   V_x  <- Q_x + Kᵀ·Q_uu·k + Kᵀ·Q_u + Q_uxᵀ·k
            //   V_xx <- Q_xx + Kᵀ·Q_uu·K + Kᵀ·Q_ux + Q_uxᵀ·K
            // Compute Q_uu·k (length n_u).
            double *QuuK_vec = (double *)malloc(n_u * sizeof(double));
            for (int i = 0; i < n_u; i++) {
                double s = 0;
                for (int j = 0; j < n_u; j++) s += Q_uu[i*n_u + j] * k_t[j];
                QuuK_vec[i] = s;
            }
            // V_x updates
            for (int i = 0; i < n_x; i++) {
                double s = Q_x[i];
                for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * QuuK_vec[kk];
                for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * Q_u[kk];
                for (int kk = 0; kk < n_u; kk++) s += Q_ux[kk*n_x + i] * k_t[kk];
                V_x[i] = s;
            }
            free(QuuK_vec);
            // V_xx updates: Q_xx + Kᵀ·Q_uu·K + Kᵀ·Q_ux + Q_uxᵀ·K (symmetric).
            // Compute Q_uu·K (n_u × n_x).
            double *QuuK = (double *)malloc(n_u * n_x * sizeof(double));
            for (int i = 0; i < n_u; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int kk = 0; kk < n_u; kk++) s += Q_uu[i*n_u + kk] * K_t[kk*n_x + j];
                    QuuK[i*n_x + j] = s;
                }
            for (int i = 0; i < n_x; i++) {
                for (int j = 0; j < n_x; j++) {
                    double s = Q_xx[i*n_x + j];
                    for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * QuuK[kk*n_x + j];
                    for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * Q_ux[kk*n_x + j];
                    for (int kk = 0; kk < n_u; kk++) s += Q_ux[kk*n_x + i] * K_t[kk*n_x + j];
                    V_xx[i*n_x + j] = s;
                }
            }
            free(QuuK);
        }

        // === Forward pass with line search ===
        double new_cost = cost;
        int accepted = 0;
        double alpha = 1.0;
        for (int ls = 0; ls < 10; ls++) {
            memcpy(x_traj_new, x0, n_x * sizeof(double));
            for (int t = 0; t < T; t++) {
                double *xn = x_traj_new + t * n_x;
                double *xo = x_traj     + t * n_x;
                double *uo = u_seq      + t * n_u;
                double *un = u_new      + t * n_u;
                double *K_t = K_seq + t * n_u * n_x;
                double *k_t = k_seq + t * n_u;
                // u_new = u_old + α·k + K·(x_new - x_old).
                for (int i = 0; i < n_u; i++) {
                    double s = uo[i] + alpha * k_t[i];
                    for (int j = 0; j < n_x; j++) s += K_t[i*n_x + j] * (xn[j] - xo[j]);
                    un[i] = s;
                }
                f((long long)(size_t)xn, (long long)(size_t)un,
                  (long long)(size_t)(x_traj_new + (t+1)*n_x));
            }
            double total = 0;
            for (int t = 0; t < T; t++) {
                total += _i2f(l((long long)(size_t)(x_traj_new + t*n_x),
                                (long long)(size_t)(u_new + t*n_u)));
            }
            total += _i2f(lf((long long)(size_t)(x_traj_new + T*n_x)));
            if (total < cost) {
                new_cost = total;
                memcpy(x_traj, x_traj_new, (T + 1) * n_x * sizeof(double));
                memcpy(u_seq,  u_new,      T * n_u * sizeof(double));
                accepted = 1;
                break;
            }
            alpha *= 0.5;
        }
        if (!accepted) { iter++; break; }
        // Convergence check.
        if (cost - new_cost < 1e-9) { cost = new_cost; iter++; break; }
        cost = new_cost;
    }

    free(x_traj); free(x_traj_new); free(u_new);
    free(V_x); free(V_xx); free(K_seq); free(k_seq);
    free(A); free(B); free(l_x); free(l_u); free(l_xx); free(l_uu);
    free(Q_x); free(Q_u); free(Q_xx); free(Q_uu); free(Q_ux); free(Q_uu_inv);
    free(scr1); free(scr2); free(scr3);
    return iter;
}

// Diagnostic: total trajectory cost given the user's callbacks
// and an arbitrary control sequence. Useful for verifying iLQR
// reduced the cost.
long long nuc_ilqr_total_cost(
    long long n_x_, long long n_u_, long long T_,
    long long x0_ptr, long long u_seq_ptr,
    long long dynamics_fp,
    long long stage_cost_fp,
    long long terminal_cost_fp)
{
    int n_x = (int)n_x_, n_u = (int)n_u_, T = (int)T_;
    double *x0 = (double *)(void *)(size_t)x0_ptr;
    double *u_seq = (double *)(void *)(size_t)u_seq_ptr;
    dyn_fn_t f   = (dyn_fn_t)(void *)(size_t)dynamics_fp;
    cost_fn_t l  = (cost_fn_t)(void *)(size_t)stage_cost_fp;
    tcost_fn_t lf= (tcost_fn_t)(void *)(size_t)terminal_cost_fp;
    double *x_traj = (double *)malloc((T + 1) * n_x * sizeof(double));
    double c = _total_cost(f, l, lf, x0, u_seq, n_x, n_u, T, x_traj);
    free(x_traj);
    return _f2i(c);
}
