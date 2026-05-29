// cilqr_rt.c — Box-constrained iLQR.
//
// Same iterative-LQR algorithm as `ilqr_rt.c` (numerical FD
// gradients, Gauss-Newton diagonal-Hessian cost approximation,
// Riccati backward pass with regularization, line-search forward
// pass), with one addition: each control update during the forward
// pass is clamped to a per-component box `[u_min, u_max]`.
//
// This is the simplest principled way to enforce control bounds —
// it doesn't strictly project the backward-pass gain `K` onto the
// active set (Tassa-style box-DDP does that), but it produces
// feasible control sequences and converges well in practice for
// soft-bounds-active problems.
//
// Limitations (Tassa-style projected backward pass land in
// v0.6 if needed):
// - The backward-pass gain `K` is unconstrained; only the forward
//   pass clamps. When bounds are tightly active over many steps,
//   the gain can be too aggressive and convergence slows.
// - Same diagonal-Hessian / numerical-FD limitations as `ilqr.nr`.
//
// Compile: clang -c stdlib/runtime/cilqr_rt.c -o target/cilqr.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ci2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _cf2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*ci_dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*ci_cost_fn_t)(long long x_ptr, long long u_ptr);
typedef long long (*ci_tcost_fn_t)(long long x_ptr);

// === Same helpers as ilqr_rt.c, prefixed _ci_ to avoid collisions ===

static int _ci_gj_inv(double *A, int n, double *Ainv) {
    int aug_w = 2*n;
    double *aug = (double *)malloc((size_t)n * aug_w * sizeof(double));
    for (int i=0;i<n;i++){
        for (int j=0;j<n;j++) aug[i*aug_w+j] = A[i*n+j];
        for (int j=0;j<n;j++) aug[i*aug_w+n+j] = (i==j)?1.0:0.0;
    }
    for (int i=0;i<n;i++){
        int piv=i;
        for (int r=i+1;r<n;r++) if (fabs(aug[r*aug_w+i])>fabs(aug[piv*aug_w+i])) piv=r;
        if (fabs(aug[piv*aug_w+i])<1e-12){ free(aug); return 0; }
        if (piv!=i) for (int j=0;j<aug_w;j++){ double t=aug[i*aug_w+j]; aug[i*aug_w+j]=aug[piv*aug_w+j]; aug[piv*aug_w+j]=t; }
        double inv = 1.0/aug[i*aug_w+i];
        for (int j=0;j<aug_w;j++) aug[i*aug_w+j]*=inv;
        for (int r=0;r<n;r++){
            if (r==i) continue;
            double f = aug[r*aug_w+i];
            for (int j=0;j<aug_w;j++) aug[r*aug_w+j] -= f*aug[i*aug_w+j];
        }
    }
    for (int i=0;i<n;i++) for (int j=0;j<n;j++) Ainv[i*n+j] = aug[i*aug_w+n+j];
    free(aug);
    return 1;
}

static void _ci_dyn_jacobian(ci_dyn_fn_t f, double *x, double *u, int n_x, int n_u,
    double *A, double *B, double *xn1, double *xn2)
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

static void _ci_cost_quadratize(ci_cost_fn_t l, double *x, double *u, int n_x, int n_u,
    double *l_x, double *l_u, double *l_xx, double *l_uu)
{
    double eps = 1e-5;
    double base = _ci2f(l((long long)(size_t)x, (long long)(size_t)u));
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        double up = _ci2f(l((long long)(size_t)x, (long long)(size_t)u));
        x[j] = sv - eps;
        double dn = _ci2f(l((long long)(size_t)x, (long long)(size_t)u));
        x[j] = sv;
        l_x[j] = (up - dn) / (2.0 * eps);
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        for (int k = 0; k < n_x; k++) l_xx[j*n_x + k] = (j == k) ? dd : 0.0;
    }
    for (int j = 0; j < n_u; j++) {
        double sv = u[j];
        u[j] = sv + eps;
        double up = _ci2f(l((long long)(size_t)x, (long long)(size_t)u));
        u[j] = sv - eps;
        double dn = _ci2f(l((long long)(size_t)x, (long long)(size_t)u));
        u[j] = sv;
        l_u[j] = (up - dn) / (2.0 * eps);
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        for (int k = 0; k < n_u; k++) l_uu[j*n_u + k] = (j == k) ? dd : 0.0;
    }
}

static void _ci_tcost_quadratize(ci_tcost_fn_t lf, double *x, int n_x,
    double *V_x, double *V_xx)
{
    double eps = 1e-5;
    double base = _ci2f(lf((long long)(size_t)x));
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        double up = _ci2f(lf((long long)(size_t)x));
        x[j] = sv - eps;
        double dn = _ci2f(lf((long long)(size_t)x));
        x[j] = sv;
        V_x[j] = (up - dn) / (2.0 * eps);
        double dd = (up - 2.0 * base + dn) / (eps * eps);
        for (int k = 0; k < n_x; k++) V_xx[j*n_x + k] = (j == k) ? dd : 0.0;
    }
}

static double _ci_total_cost(ci_dyn_fn_t f, ci_cost_fn_t l, ci_tcost_fn_t lf,
    double *x0, double *u_seq, int n_x, int n_u, int T, double *x_traj_out)
{
    memcpy(x_traj_out, x0, n_x * sizeof(double));
    double total = 0;
    for (int t = 0; t < T; t++) {
        double *xt = x_traj_out + t * n_x;
        double *ut = u_seq + t * n_u;
        total += _ci2f(l((long long)(size_t)xt, (long long)(size_t)ut));
        f((long long)(size_t)xt, (long long)(size_t)ut,
          (long long)(size_t)(x_traj_out + (t+1)*n_x));
    }
    total += _ci2f(lf((long long)(size_t)(x_traj_out + T*n_x)));
    return total;
}

// === Box-constrained iLQR ===
//
// Same I/O as nuc_ilqr_optimize, plus u_min_ptr and u_max_ptr —
// caller-allocated double[n_u] arrays giving per-component bounds.
// During the forward pass each computed u is clamped to those bounds
// before the dynamics call.

long long nuc_cilqr_optimize_box(
    long long n_x_, long long n_u_, long long T_,
    long long x0_ptr, long long u_seq_ptr,
    long long u_min_ptr, long long u_max_ptr,
    long long max_iters,
    long long dynamics_fp, long long stage_cost_fp, long long terminal_cost_fp)
{
    int n_x = (int)n_x_, n_u = (int)n_u_, T = (int)T_;
    if (n_x <= 0 || n_u <= 0 || T <= 0) return -1;
    double *x0 = (double *)(void *)(size_t)x0_ptr;
    double *u_seq = (double *)(void *)(size_t)u_seq_ptr;
    double *u_min = (double *)(void *)(size_t)u_min_ptr;
    double *u_max = (double *)(void *)(size_t)u_max_ptr;
    if (!x0 || !u_seq || !u_min || !u_max) return -1;
    ci_dyn_fn_t f   = (ci_dyn_fn_t)(void *)(size_t)dynamics_fp;
    ci_cost_fn_t l  = (ci_cost_fn_t)(void *)(size_t)stage_cost_fp;
    ci_tcost_fn_t lf= (ci_tcost_fn_t)(void *)(size_t)terminal_cost_fp;
    if (!f || !l || !lf) return -1;

    // Pre-clamp the initial sequence to the box.
    for (int t = 0; t < T; t++) {
        for (int i = 0; i < n_u; i++) {
            double v = u_seq[t*n_u + i];
            if (v < u_min[i]) v = u_min[i];
            if (v > u_max[i]) v = u_max[i];
            u_seq[t*n_u + i] = v;
        }
    }

    // Allocate same buffers as ilqr.
    double *x_traj      = (double *)malloc((size_t)(T + 1) * n_x * sizeof(double));
    double *x_traj_new  = (double *)malloc((size_t)(T + 1) * n_x * sizeof(double));
    double *u_new       = (double *)malloc((size_t)T * n_u * sizeof(double));
    double *V_x         = (double *)malloc(n_x * sizeof(double));
    double *V_xx        = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    double *K_seq       = (double *)malloc((size_t)T * n_u * n_x * sizeof(double));
    double *k_seq       = (double *)malloc((size_t)T * n_u * sizeof(double));
    double *A           = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    double *B           = (double *)malloc((size_t)n_x * n_u * sizeof(double));
    double *l_x         = (double *)malloc(n_x * sizeof(double));
    double *l_u         = (double *)malloc(n_u * sizeof(double));
    double *l_xx        = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    double *l_uu        = (double *)malloc((size_t)n_u * n_u * sizeof(double));
    double *Q_x         = (double *)malloc(n_x * sizeof(double));
    double *Q_u         = (double *)malloc(n_u * sizeof(double));
    double *Q_xx        = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    double *Q_uu        = (double *)malloc((size_t)n_u * n_u * sizeof(double));
    double *Q_ux        = (double *)malloc((size_t)n_u * n_x * sizeof(double));
    double *Q_uu_inv    = (double *)malloc((size_t)n_u * n_u * sizeof(double));
    double *xn1         = (double *)malloc(n_x * sizeof(double));
    double *xn2         = (double *)malloc(n_x * sizeof(double));

    double cost = _ci_total_cost(f, l, lf, x0, u_seq, n_x, n_u, T, x_traj);

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // === Backward pass (identical to ilqr) ===
        _ci_tcost_quadratize(lf, x_traj + T * n_x, n_x, V_x, V_xx);
        for (int t = T - 1; t >= 0; t--) {
            double *xt = x_traj + t * n_x;
            double *ut = u_seq  + t * n_u;
            _ci_dyn_jacobian(f, xt, ut, n_x, n_u, A, B, xn1, xn2);
            _ci_cost_quadratize(l, xt, ut, n_x, n_u, l_x, l_u, l_xx, l_uu);

            for (int i = 0; i < n_x; i++) {
                double s = l_x[i];
                for (int j = 0; j < n_x; j++) s += A[j*n_x + i] * V_x[j];
                Q_x[i] = s;
            }
            for (int i = 0; i < n_u; i++) {
                double s = l_u[i];
                for (int j = 0; j < n_x; j++) s += B[j*n_u + i] * V_x[j];
                Q_u[i] = s;
            }
            double *VxxA = (double *)malloc((size_t)n_x * n_x * sizeof(double));
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
            double *VxxB = (double *)malloc((size_t)n_x * n_u * sizeof(double));
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
                    Q_uu[i*n_u + j] = s + (i == j ? 1e-6 : 0);
                }
            for (int i = 0; i < n_u; i++)
                for (int j = 0; j < n_x; j++) {
                    double s = 0;
                    for (int k = 0; k < n_x; k++) s += B[k*n_u + i] * VxxA[k*n_x + j];
                    Q_ux[i*n_x + j] = s;
                }
            free(VxxA); free(VxxB);

            if (!_ci_gj_inv(Q_uu, n_u, Q_uu_inv)) {
                free(x_traj); free(x_traj_new); free(u_new);
                free(V_x); free(V_xx); free(K_seq); free(k_seq);
                free(A); free(B); free(l_x); free(l_u); free(l_xx); free(l_uu);
                free(Q_x); free(Q_u); free(Q_xx); free(Q_uu); free(Q_ux); free(Q_uu_inv);
                free(xn1); free(xn2);
                return iter;
            }
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
            // Value-function update (same as ilqr).
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
            double *QuuK = (double *)malloc((size_t)n_u * n_x * sizeof(double));
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

        // === Forward pass with line search + BOX CLAMP ===
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
                    // BOX CLAMP — only difference vs ilqr
                    if (s < u_min[i]) s = u_min[i];
                    if (s > u_max[i]) s = u_max[i];
                    un[i] = s;
                }
                f((long long)(size_t)xn, (long long)(size_t)un,
                  (long long)(size_t)(x_traj_new + (t+1)*n_x));
            }
            double total = 0;
            for (int t = 0; t < T; t++) {
                total += _ci2f(l((long long)(size_t)(x_traj_new + t*n_x),
                                  (long long)(size_t)(u_new + t*n_u)));
            }
            total += _ci2f(lf((long long)(size_t)(x_traj_new + T*n_x)));
            if (total < cost) {
                new_cost = total;
                memcpy(x_traj, x_traj_new, (size_t)(T + 1) * n_x * sizeof(double));
                memcpy(u_seq,  u_new,      (size_t)T * n_u * sizeof(double));
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
    free(xn1); free(xn2);
    return iter;
}
