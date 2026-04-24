// ddp_rt.c — Differential Dynamic Programming (Mayne 1966; Jacobson
// & Mayne 1970). Second-order extension of iLQR: instead of dropping
// the contribution of the dynamics Hessians (Gauss-Newton style),
// DDP includes the full second-order expansion of the value function
// through the dynamics.
//
// Concretely, where iLQR computes
//   Q_xx = l_xx + Aᵀ V_xx A
//   Q_uu = l_uu + Bᵀ V_xx B
//   Q_ux = Bᵀ V_xx A
//
// DDP adds the tensor contractions
//   Q_xx += Σ_k V_x[k] · f_xx[k]
//   Q_uu += Σ_k V_x[k] · f_uu[k]
//   Q_ux += Σ_k V_x[k] · f_ux[k]
//
// where f_xx, f_uu, f_ux are the second-derivative tensors of the
// dynamics with respect to (x, x), (u, u), (u, x). DDP converges
// quadratically near the optimum (vs iLQR's superlinear convergence)
// at the cost of computing the dynamics Hessians.
//
// The dynamics Hessians are computed by central finite differences
// against the user's `dynamics_fp` callback. For dynamics with n_x
// states and n_u controls, this is O(n_x² + n_u² + n_x·n_u) extra
// callback invocations per (t, ·) — significant for large state
// dimensions, but typically still cheaper per outer iteration than
// the extra iLQR iterations needed to match DDP's quadratic
// convergence.
//
// **Limitations** (analytical Hessians via a user-supplied tensor
// callback land in v0.6 if needed for performance):
// - Numerical FD for dynamics Hessians (slow for n_x > ~10).
// - Same diagonal-Hessian approximation of the cost as iLQR.
// - Same fixed regularizer + bisection line search as iLQR.
// - No box constraints on u (would need projected line search or
//   Tassa-style bound-projected DDP variant).
//
// Compile: clang -c stdlib/runtime/ddp_rt.c -o target/ddp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*cost_fn_t)(long long x_ptr, long long u_ptr);
typedef long long (*tcost_fn_t)(long long x_ptr);

// In-place Gauss-Jordan inverse on a small n×n matrix. Returns 1
// on success, 0 if singular.
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

// Numerical Jacobian of dynamics via central differences.
static void _dyn_jacobian(dyn_fn_t f,
    double *x, double *u, int n_x, int n_u,
    double *A, double *B,
    double *xn1, double *xn2)
{
    double eps = 1e-6;
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xn1);
        x[j] = sv - eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xn2);
        x[j] = sv;
        for (int i = 0; i < n_x; i++) A[i*n_x + j] = (xn1[i] - xn2[i]) / (2.0 * eps);
    }
    for (int j = 0; j < n_u; j++) {
        double sv = u[j];
        u[j] = sv + eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xn1);
        u[j] = sv - eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xn2);
        u[j] = sv;
        for (int i = 0; i < n_x; i++) B[i*n_u + j] = (xn1[i] - xn2[i]) / (2.0 * eps);
    }
}

// Numerical second-derivative tensors of dynamics via 4-point
// central differences:
//   ∂²f_k / ∂x_i ∂x_j  for f_xx (size n_x · n_x · n_x)
//   ∂²f_k / ∂u_i ∂u_j  for f_uu (size n_x · n_u · n_u)
//   ∂²f_k / ∂u_i ∂x_j  for f_ux (size n_x · n_u · n_x)
//
// Layout: f_xx[k*n_x*n_x + i*n_x + j], etc.
static void _dyn_hessian(dyn_fn_t f,
    double *x, double *u, int n_x, int n_u,
    double *f_xx, double *f_uu, double *f_ux,
    double *xpp, double *xpm, double *xmp, double *xmm)
{
    double eps = 1e-4;
    double e2 = eps * eps;

    // f_xx via mixed central difference:
    //   ∂²f/∂x_i∂x_j ≈ [f(+i,+j) - f(+i,-j) - f(-i,+j) + f(-i,-j)] / (4 eps²)
    for (int i = 0; i < n_x; i++) {
        for (int j = i; j < n_x; j++) {
            double svi = x[i], svj = x[j];
            if (i == j) {
                // Pure 2nd derivative: ∂²f/∂x_i² ≈ (f(+) - 2 f(0) + f(-)) / eps²
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpp);  // f(0)
                x[i] = svi + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpm);  // f(+)
                x[i] = svi - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmp);  // f(-)
                x[i] = svi;
                for (int k = 0; k < n_x; k++)
                    f_xx[k*n_x*n_x + i*n_x + j] =
                        (xpm[k] - 2.0 * xpp[k] + xmp[k]) / e2;
            } else {
                x[i] = svi + eps; x[j] = svj + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpp);
                x[j] = svj - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpm);
                x[i] = svi - eps; x[j] = svj + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmp);
                x[j] = svj - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmm);
                x[i] = svi; x[j] = svj;
                for (int k = 0; k < n_x; k++) {
                    double v = (xpp[k] - xpm[k] - xmp[k] + xmm[k]) / (4.0 * e2);
                    f_xx[k*n_x*n_x + i*n_x + j] = v;
                    f_xx[k*n_x*n_x + j*n_x + i] = v;  // symmetry
                }
            }
        }
    }

    // f_uu identical structure on u.
    for (int i = 0; i < n_u; i++) {
        for (int j = i; j < n_u; j++) {
            double svi = u[i], svj = u[j];
            if (i == j) {
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpp);
                u[i] = svi + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpm);
                u[i] = svi - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmp);
                u[i] = svi;
                for (int k = 0; k < n_x; k++)
                    f_uu[k*n_u*n_u + i*n_u + j] =
                        (xpm[k] - 2.0 * xpp[k] + xmp[k]) / e2;
            } else {
                u[i] = svi + eps; u[j] = svj + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpp);
                u[j] = svj - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpm);
                u[i] = svi - eps; u[j] = svj + eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmp);
                u[j] = svj - eps;
                f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmm);
                u[i] = svi; u[j] = svj;
                for (int k = 0; k < n_x; k++) {
                    double v = (xpp[k] - xpm[k] - xmp[k] + xmm[k]) / (4.0 * e2);
                    f_uu[k*n_u*n_u + i*n_u + j] = v;
                    f_uu[k*n_u*n_u + j*n_u + i] = v;
                }
            }
        }
    }

    // f_ux: ∂²f/∂u_i ∂x_j (mixed; no symmetry inside this tensor).
    for (int i = 0; i < n_u; i++) {
        for (int j = 0; j < n_x; j++) {
            double svu = u[i], svx = x[j];
            u[i] = svu + eps; x[j] = svx + eps;
            f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpp);
            x[j] = svx - eps;
            f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xpm);
            u[i] = svu - eps; x[j] = svx + eps;
            f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmp);
            x[j] = svx - eps;
            f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)xmm);
            u[i] = svu; x[j] = svx;
            for (int k = 0; k < n_x; k++)
                f_ux[k*n_u*n_x + i*n_x + j] =
                    (xpp[k] - xpm[k] - xmp[k] + xmm[k]) / (4.0 * e2);
        }
    }
}

// Numerical gradient + diagonal Hessian of stage cost (matches iLQR).
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
        double dd = (up - 2.0 * base + dn) / (eps * eps);
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

static double _total_cost(dyn_fn_t f, cost_fn_t l, tcost_fn_t lf,
    double *x0, double *u_seq, int n_x, int n_u, int T,
    double *x_traj_out)
{
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

// DDP optimizer entry point. Same calling convention as iLQR but
// includes the second-order dynamics-Hessian contractions in the
// Q-function update.
long long nuc_ddp_optimize(
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
    double *f_xx        = (double *)malloc(n_x * n_x * n_x * sizeof(double));
    double *f_uu        = (double *)malloc(n_x * n_u * n_u * sizeof(double));
    double *f_ux        = (double *)malloc(n_x * n_u * n_x * sizeof(double));
    double *xn1         = (double *)malloc(n_x * sizeof(double));
    double *xn2         = (double *)malloc(n_x * sizeof(double));
    double *xpp         = (double *)malloc(n_x * sizeof(double));
    double *xpm         = (double *)malloc(n_x * sizeof(double));
    double *xmp         = (double *)malloc(n_x * sizeof(double));
    double *xmm         = (double *)malloc(n_x * sizeof(double));

    double cost = _total_cost(f, l, lf, x0, u_seq, n_x, n_u, T, x_traj);
    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // === Backward pass ===
        _tcost_quadratize(lf, x_traj + T * n_x, n_x, V_x, V_xx);
        for (int t = T - 1; t >= 0; t--) {
            double *xt = x_traj + t * n_x;
            double *ut = u_seq  + t * n_u;
            _dyn_jacobian(f, xt, ut, n_x, n_u, A, B, xn1, xn2);
            _dyn_hessian (f, xt, ut, n_x, n_u, f_xx, f_uu, f_ux,
                          xpp, xpm, xmp, xmm);
            _cost_quadratize(l, xt, ut, n_x, n_u, l_x, l_u, l_xx, l_uu);

            // Q_x = l_x + Aᵀ V_x.
            for (int i = 0; i < n_x; i++) {
                double s = l_x[i];
                for (int j = 0; j < n_x; j++) s += A[j*n_x + i] * V_x[j];
                Q_x[i] = s;
            }
            // Q_u = l_u + Bᵀ V_x.
            for (int i = 0; i < n_u; i++) {
                double s = l_u[i];
                for (int j = 0; j < n_x; j++) s += B[j*n_u + i] * V_x[j];
                Q_u[i] = s;
            }

            // Q_xx = l_xx + Aᵀ V_xx A + Σ_k V_x[k] · f_xx[k].
            // 1) compute V_xx · A (n_x × n_x).
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
                    // DDP: + Σ_k V_x[k] · f_xx[k][i,j].
                    for (int k = 0; k < n_x; k++)
                        s += V_x[k] * f_xx[k*n_x*n_x + i*n_x + j];
                    Q_xx[i*n_x + j] = s;
                }

            // Q_uu = l_uu + Bᵀ V_xx B + Σ_k V_x[k] · f_uu[k]  (+ reg).
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
                    for (int k = 0; k < n_x; k++)
                        s += V_x[k] * f_uu[k*n_u*n_u + i*n_u + j];
                    Q_uu[i*n_u + j] = s + (i == j ? 1e-6 : 0);
                }

            // Q_ux = Bᵀ V_xx A + Σ_k V_x[k] · f_ux[k].
            for (int i = 0; i < n_u; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int k = 0; k < n_x; k++) s += B[k*n_u + i] * VxxA[k*n_x + j];
                    for (int k = 0; k < n_x; k++)
                        s += V_x[k] * f_ux[k*n_u*n_x + i*n_x + j];
                    Q_ux[i*n_x + j] = s;
                }
            free(VxxA); free(VxxB);

            if (!_gj_inv(Q_uu, n_u, Q_uu_inv)) {
                free(x_traj); free(x_traj_new); free(u_new);
                free(V_x); free(V_xx); free(K_seq); free(k_seq);
                free(A); free(B); free(l_x); free(l_u); free(l_xx); free(l_uu);
                free(Q_x); free(Q_u); free(Q_xx); free(Q_uu); free(Q_ux); free(Q_uu_inv);
                free(f_xx); free(f_uu); free(f_ux);
                free(xn1); free(xn2); free(xpp); free(xpm); free(xmp); free(xmm);
                return iter;
            }
            // K_t = -Q_uu_inv · Q_ux,  k_t = -Q_uu_inv · Q_u.
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
            // V update (same form as iLQR).
            double *QuuK_vec = (double *)malloc(n_u * sizeof(double));
            for (int i = 0; i < n_u; i++) {
                double s = 0;
                for (int j = 0; j < n_u; j++) s += Q_uu[i*n_u + j] * k_t[j];
                QuuK_vec[i] = s;
            }
            for (int i = 0; i < n_x; i++) {
                double s = Q_x[i];
                for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * QuuK_vec[kk];
                for (int kk = 0; kk < n_u; kk++) s += K_t[kk*n_x + i] * Q_u[kk];
                for (int kk = 0; kk < n_u; kk++) s += Q_ux[kk*n_x + i] * k_t[kk];
                V_x[i] = s;
            }
            free(QuuK_vec);
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
        if (cost - new_cost < 1e-9) { cost = new_cost; iter++; break; }
        cost = new_cost;
    }

    free(x_traj); free(x_traj_new); free(u_new);
    free(V_x); free(V_xx); free(K_seq); free(k_seq);
    free(A); free(B); free(l_x); free(l_u); free(l_xx); free(l_uu);
    free(Q_x); free(Q_u); free(Q_xx); free(Q_uu); free(Q_ux); free(Q_uu_inv);
    free(f_xx); free(f_uu); free(f_ux);
    free(xn1); free(xn2); free(xpp); free(xpm); free(xmp); free(xmm);
    return iter;
}

// Diagnostic: trajectory cost, identical to iLQR's helper. Provided
// here so DDP users don't have to import the iLQR rod just for this.
long long nuc_ddp_total_cost(
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
