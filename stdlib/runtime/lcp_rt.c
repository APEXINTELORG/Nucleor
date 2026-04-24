// lcp_rt.c — Box LCP solver via Projected Gauss-Seidel (PGS).
//
// Solves the box linear complementarity problem
//
//   find λ ∈ [lo, hi]  such that  w = M·λ + q  satisfies
//
//     w_i ≥ 0  whenever  λ_i = lo_i
//     w_i ≤ 0  whenever  λ_i = hi_i
//     w_i = 0  whenever  lo_i < λ_i < hi_i
//
// This is the iteration that underlies MuJoCo, Bullet, ODE, and
// most other rigid-body contact solvers. Unilateral contacts model
// the normal force as λ ∈ [0, ∞); Coulomb friction models tangent
// forces as λ ∈ [−μλ_n, μλ_n] (a box whose width tracks the
// instantaneous normal force).
//
// Algorithm (PGS):
//   for iter in 0..max_iters:
//     for i in 0..n:
//       w_i  = q_i + Σ_{j≠i} M_ij · λ_j
//       λ_i' = clamp(−w_i / M_ii, lo_i, hi_i)
//     if max_i |λ_i' − λ_i| < tol: break
//
// Convergence: PGS converges for any positive-definite M (proved in
// Cottle, Pang & Stone 1992). For symmetric positive-semidefinite M
// it converges to a solution if one exists. Convergence rate
// depends on the spectral radius of the iteration matrix; for
// well-conditioned M (typical for soft-contact LCPs after Baumgarte
// stabilization), 30–100 iters reach 1e-4 accuracy.
//
// **Limitations** (Lemke's algorithm / interior-point methods land
// in v0.6 if needed for ill-conditioned systems):
// - PGS is iterative; for ill-conditioned M (very stiff contacts +
//   no soft regularization) convergence may be slow.
// - No automatic warm-starting from previous solution (caller can
//   set initial via `lcp_pgs_set_initial`).
// - Generic LCP — caller is responsible for assembling M and q from
//   contact Jacobians, mass matrix, free velocity, and the friction
//   pyramid linearization.
//
// Compile: clang -c stdlib/runtime/lcp_rt.c -o target/lcp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n;
    double *M;             // n × n  (row-major)
    double *q;             // n
    double *lo, *hi;       // n; bounds per variable
    double *lambda;        // n; current solution
    double final_residual; // last computed complementarity residual
} NLCP;

long long nuc_lcp_pgs_new(long long n_) {
    int n = (int)n_;
    if (n <= 0) return 0;
    NLCP *p = (NLCP *)calloc(1, sizeof(NLCP));
    p->n = n;
    p->M = (double *)calloc(n*n, sizeof(double));
    p->q = (double *)calloc(n, sizeof(double));
    p->lo = (double *)calloc(n, sizeof(double));
    p->hi = (double *)malloc(n * sizeof(double));
    p->lambda = (double *)calloc(n, sizeof(double));
    // Default bounds: [0, +inf) — standard unilateral-contact case.
    for (int i = 0; i < n; i++) {
        p->lo[i] = 0.0;
        p->hi[i] = INFINITY;
    }
    return (long long)(size_t)p;
}

void nuc_lcp_pgs_set_M(long long h, long long i, long long j, long long v_b) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p || i < 0 || j < 0 || i >= (long long)p->n || j >= (long long)p->n) return;
    p->M[i*p->n + j] = _i2f(v_b);
}

void nuc_lcp_pgs_set_q(long long h, long long i, long long v_b) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n) return;
    p->q[i] = _i2f(v_b);
}

void nuc_lcp_pgs_set_bounds(long long h, long long i, long long lo_b, long long hi_b) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n) return;
    p->lo[i] = _i2f(lo_b);
    p->hi[i] = _i2f(hi_b);
    if (p->lo[i] > p->hi[i]) {
        double t = p->lo[i]; p->lo[i] = p->hi[i]; p->hi[i] = t;
    }
}

void nuc_lcp_pgs_set_initial(long long h, long long i, long long v_b) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n) return;
    double v = _i2f(v_b);
    if (v < p->lo[i]) v = p->lo[i];
    if (v > p->hi[i]) v = p->hi[i];
    p->lambda[i] = v;
}

long long nuc_lcp_pgs_solve(long long h, long long max_iters, long long tol_b) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p) return -1;
    int n = p->n;
    int max_it = (int)max_iters;
    if (max_it <= 0) max_it = 100;
    double tol = _i2f(tol_b);
    if (tol <= 0) tol = 1e-6;

    long long iter;
    for (iter = 0; iter < max_it; iter++) {
        double max_delta = 0;
        for (int i = 0; i < n; i++) {
            double diag = p->M[i*n + i];
            // Skip if diagonal is non-positive — solver requires M_ii > 0.
            if (diag <= 1e-14) continue;
            // sum = q_i + Σ_{j≠i} M_ij · λ_j
            double sum = p->q[i];
            for (int j = 0; j < n; j++) {
                if (j == i) continue;
                sum += p->M[i*n + j] * p->lambda[j];
            }
            double new_lam = -sum / diag;
            if (new_lam < p->lo[i]) new_lam = p->lo[i];
            if (new_lam > p->hi[i]) new_lam = p->hi[i];
            double d = fabs(new_lam - p->lambda[i]);
            if (d > max_delta) max_delta = d;
            p->lambda[i] = new_lam;
        }
        if (max_delta < tol) { iter++; break; }
    }

    // Compute final complementarity residual for diagnostics:
    //   residual = max_i  |min(λ_i − lo_i,  max(0, w_i))|  +
    //                     |min(hi_i − λ_i, max(0, −w_i))|
    // Simpler proxy: ‖w·step_to_box_edge‖∞ which is what PGS drove
    // to ≤ tol.
    double res = 0;
    for (int i = 0; i < n; i++) {
        double w = p->q[i];
        for (int j = 0; j < n; j++) w += p->M[i*n + j] * p->lambda[j];
        // Free direction at λ_i: positive = increase λ.
        // If λ_i > lo, we should have w_i ≤ 0 (else we want to decrease λ).
        // If λ_i < hi, we should have w_i ≥ 0 (else we want to increase λ).
        double v = 0;
        if (p->lambda[i] > p->lo[i] + 1e-12 && w > v) v = w;
        if (p->lambda[i] < p->hi[i] - 1e-12 && -w > v) v = -w;
        if (v > res) res = v;
    }
    p->final_residual = res;
    return iter;
}

long long nuc_lcp_pgs_get(long long h, long long i) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n) return _f2i(0.0);
    return _f2i(p->lambda[i]);
}

long long nuc_lcp_pgs_residual(long long h) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    return _f2i(p->final_residual);
}

void nuc_lcp_pgs_free(long long h) {
    NLCP *p = (NLCP *)(void *)(size_t)h;
    if (!p) return;
    if (p->M) free(p->M);
    if (p->q) free(p->q);
    if (p->lo) free(p->lo);
    if (p->hi) free(p->hi);
    if (p->lambda) free(p->lambda);
    free(p);
}
