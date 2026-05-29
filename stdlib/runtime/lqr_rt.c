// lqr_rt.c — Discrete infinite-horizon LQR via Riccati iteration.
//
// Given a linear time-invariant system
//   x_{k+1} = A · x_k + B · u_k
// and a quadratic cost
//   J = Σ_k (x_kᵀ Q x_k + u_kᵀ R u_k)
//
// the optimal feedback law is the static gain
//   u_k = −K · x_k
// where K = (R + Bᵀ P B)⁻¹ Bᵀ P A and P is the solution of the
// discrete algebraic Riccati equation (DARE):
//
//   P = Aᵀ P A − Aᵀ P B (R + Bᵀ P B)⁻¹ Bᵀ P A + Q
//
// Solved here by direct Riccati recursion (start P₀ = Q, iterate
// until ‖P_{k+1} − P_k‖_max < tol). Convergent for stabilizable
// (A, B) with detectable Q^{1/2}.
//
// Complement to `ilqr.nr` and `ddp.nr` (both finite-horizon
// nonlinear). Use LQR when the system is well-modeled by a linear
// time-invariant approximation around an operating point and a
// fixed feedback gain is acceptable.
//
// Limitations (continuous-time CARE / output-feedback LQR /
// time-varying LQR land in v0.6 if needed):
// - Discrete time only (infinite-horizon CARE for continuous time
//   uses Hamiltonian eigendecomposition; planned for v0.6).
// - State-feedback only (assumes full-state measurement).
// - Direct Riccati iteration; for ill-conditioned systems Schur or
//   doubling methods converge faster (planned for v0.6).
//
// Compile: clang -c stdlib/runtime/lqr_rt.c -o target/lqr.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n_x, n_u;
    double *A;       // n_x × n_x
    double *B;       // n_x × n_u
    double *Q;       // n_x × n_x
    double *R;       // n_u × n_u
    double *P;       // n_x × n_x — Riccati solution
    double *K;       // n_u × n_x — feedback gain
    int solved;
} NLQR;

// === Linear algebra helpers ===

static int _gj_inv(const double *A, int n, double *Ainv) {
    int aw = 2*n;
    double *aug = (double *)malloc((size_t)n * aw * sizeof(double));
    for (int i=0;i<n;i++){
        for (int j=0;j<n;j++) aug[i*aw+j] = A[i*n+j];
        for (int j=0;j<n;j++) aug[i*aw+n+j] = (i==j)?1.0:0.0;
    }
    for (int i=0;i<n;i++){
        int piv=i;
        for (int r=i+1;r<n;r++) if (fabs(aug[r*aw+i])>fabs(aug[piv*aw+i])) piv=r;
        if (fabs(aug[piv*aw+i])<1e-14){ free(aug); return 0; }
        if (piv!=i) for (int j=0;j<aw;j++){ double t=aug[i*aw+j]; aug[i*aw+j]=aug[piv*aw+j]; aug[piv*aw+j]=t; }
        double inv = 1.0/aug[i*aw+i];
        for (int j=0;j<aw;j++) aug[i*aw+j]*=inv;
        for (int r=0;r<n;r++){
            if (r==i) continue;
            double f = aug[r*aw+i];
            for (int j=0;j<aw;j++) aug[r*aw+j] -= f*aug[i*aw+j];
        }
    }
    for (int i=0;i<n;i++) for (int j=0;j<n;j++) Ainv[i*n+j] = aug[i*aw+n+j];
    free(aug);
    return 1;
}

// C = α A·B + β C  for general dims (a_rows × a_cols) × (a_cols × b_cols).
static void _gemm(double alpha, const double *A, int ar, int ac,
                  const double *B, int bc,
                  double beta, double *C)
{
    for (int i = 0; i < ar; i++) {
        for (int j = 0; j < bc; j++) {
            double s = 0;
            for (int k = 0; k < ac; k++) s += A[i*ac + k] * B[k*bc + j];
            C[i*bc + j] = beta * C[i*bc + j] + alpha * s;
        }
    }
}

// C = α Aᵀ·B + β C  with A treated as (a_rows × a_cols) — output is (a_cols × b_cols).
static void _gemm_TN(double alpha, const double *A, int a_rows, int a_cols,
                     const double *B, int b_cols,
                     double beta, double *C)
{
    for (int i = 0; i < a_cols; i++) {
        for (int j = 0; j < b_cols; j++) {
            double s = 0;
            for (int k = 0; k < a_rows; k++) s += A[k*a_cols + i] * B[k*b_cols + j];
            C[i*b_cols + j] = beta * C[i*b_cols + j] + alpha * s;
        }
    }
}

// === API ===

long long nuc_lqr_new(long long n_x_, long long n_u_) {
    int nx = (int)n_x_, nu = (int)n_u_;
    if (nx <= 0 || nu <= 0) return 0;
    NLQR *p = (NLQR *)calloc(1, sizeof(NLQR));
    p->n_x = nx; p->n_u = nu;
    p->A = (double *)calloc((size_t)nx * nx, sizeof(double));
    p->B = (double *)calloc((size_t)nx * nu, sizeof(double));
    p->Q = (double *)calloc((size_t)nx * nx, sizeof(double));
    p->R = (double *)calloc((size_t)nu * nu, sizeof(double));
    p->P = (double *)calloc((size_t)nx * nx, sizeof(double));
    p->K = (double *)calloc((size_t)nu * nx, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_lqr_set_A(long long h, long long i, long long j, long long v) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_x||j>=p->n_x) return;
    p->A[i*p->n_x + j] = _i2f(v);
}
void nuc_lqr_set_B(long long h, long long i, long long j, long long v) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_x||j>=p->n_u) return;
    p->B[i*p->n_u + j] = _i2f(v);
}
void nuc_lqr_set_Q(long long h, long long i, long long j, long long v) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_x||j>=p->n_x) return;
    p->Q[i*p->n_x + j] = _i2f(v);
}
void nuc_lqr_set_R(long long h, long long i, long long j, long long v) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_u||j>=p->n_u) return;
    p->R[i*p->n_u + j] = _i2f(v);
}

long long nuc_lqr_solve(long long h, long long max_iters, long long tol_b) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p) return -1;
    int nx = p->n_x, nu = p->n_u;
    int max_it = (int)max_iters;
    if (max_it <= 0) max_it = 500;
    double tol = _i2f(tol_b);
    if (tol <= 0) tol = 1e-9;

    // Initialize P = Q.
    memcpy(p->P, p->Q, (size_t)nx * nx * sizeof(double));

    double *P_new   = (double *)malloc((size_t)nx * nx * sizeof(double));
    double *PA      = (double *)malloc((size_t)nx * nx * sizeof(double));
    double *PB      = (double *)malloc((size_t)nx * nu * sizeof(double));
    double *BTPB    = (double *)malloc((size_t)nu * nu * sizeof(double));
    double *RpBTPB  = (double *)malloc((size_t)nu * nu * sizeof(double));
    double *INV     = (double *)malloc((size_t)nu * nu * sizeof(double));
    double *BTPA    = (double *)malloc((size_t)nu * nx * sizeof(double));
    double *INVBTPA = (double *)malloc((size_t)nu * nx * sizeof(double));
    double *ATPB_INVBTPA = (double *)malloc((size_t)nx * nx * sizeof(double));
    double *ATPA    = (double *)malloc((size_t)nx * nx * sizeof(double));

    long long iter;
    for (iter = 0; iter < max_it; iter++) {
        // PA = P · A      (nx × nx)
        _gemm(1.0, p->P, nx, nx, p->A, nx, 0.0, PA);
        // ATPA = Aᵀ · PA   (nx × nx)
        _gemm_TN(1.0, p->A, nx, nx, PA, nx, 0.0, ATPA);
        // PB = P · B       (nx × nu)
        _gemm(1.0, p->P, nx, nx, p->B, nu, 0.0, PB);
        // BTPB = Bᵀ · PB   (nu × nu)
        _gemm_TN(1.0, p->B, nx, nu, PB, nu, 0.0, BTPB);
        // RpBTPB = R + BTPB
        for (int i = 0; i < nu*nu; i++) RpBTPB[i] = p->R[i] + BTPB[i];
        // INV = inv(RpBTPB)
        if (!_gj_inv(RpBTPB, nu, INV)) break;
        // BTPA = Bᵀ · PA  (nu × nx)
        _gemm_TN(1.0, p->B, nx, nu, PA, nx, 0.0, BTPA);
        // INVBTPA = INV · BTPA  (nu × nx)
        _gemm(1.0, INV, nu, nu, BTPA, nx, 0.0, INVBTPA);
        // ATPB_INVBTPA = Aᵀ · PB · INVBTPA, but this should use Aᵀ P B times INVBTPA
        // Actually: A^T P A − A^T P B · INV · B^T P A + Q
        //                              = ATPA − (PB)^T · INVBTPA · A   wait
        // Let me re-derive: (PA)^T = A^T P^T = A^T P (P symmetric) — no, PA was computed as P·A so (PA)^T = A^T P^T = A^T P.
        // We want A^T P B · INV · B^T P A.
        //   = (B^T P A)^T · INV · (B^T P A)
        //   = BTPA^T · INV · BTPA
        //   = (BTPA^T) · INVBTPA          (nx × nu) · (nu × nx) = nx × nx
        _gemm_TN(1.0, BTPA, nu, nx, INVBTPA, nx, 0.0, ATPB_INVBTPA);
        // P_new = ATPA − ATPB_INVBTPA + Q
        for (int i = 0; i < nx*nx; i++) P_new[i] = ATPA[i] - ATPB_INVBTPA[i] + p->Q[i];

        // Convergence check.
        double max_d = 0;
        for (int i = 0; i < nx*nx; i++) {
            double d = fabs(P_new[i] - p->P[i]);
            if (d > max_d) max_d = d;
        }
        memcpy(p->P, P_new, (size_t)nx * nx * sizeof(double));
        if (max_d < tol) { iter++; break; }
    }

    // Compute K = (R + B^T P B)^{-1} B^T P A using fresh matrices.
    _gemm(1.0, p->P, nx, nx, p->A, nx, 0.0, PA);
    _gemm(1.0, p->P, nx, nx, p->B, nu, 0.0, PB);
    _gemm_TN(1.0, p->B, nx, nu, PB, nu, 0.0, BTPB);
    for (int i = 0; i < nu*nu; i++) RpBTPB[i] = p->R[i] + BTPB[i];
    if (_gj_inv(RpBTPB, nu, INV)) {
        _gemm_TN(1.0, p->B, nx, nu, PA, nx, 0.0, BTPA);
        _gemm(1.0, INV, nu, nu, BTPA, nx, 0.0, p->K);
        p->solved = 1;
    }

    free(P_new); free(PA); free(PB); free(BTPB); free(RpBTPB);
    free(INV); free(BTPA); free(INVBTPA); free(ATPB_INVBTPA); free(ATPA);
    return iter;
}

long long nuc_lqr_K(long long h, long long i, long long j) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_u||j>=p->n_x) return _f2i(0.0);
    return _f2i(p->K[i*p->n_x + j]);
}
long long nuc_lqr_P(long long h, long long i, long long j) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || i<0||j<0||i>=p->n_x||j>=p->n_x) return _f2i(0.0);
    return _f2i(p->P[i*p->n_x + j]);
}

// Compute u = −K · x for caller-supplied x (length n_x), writing
// into u_out (length n_u).
void nuc_lqr_compute_u(long long h, long long x_ptr, long long u_out_ptr) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p || !p->solved) return;
    double *x = (double *)(void *)(size_t)x_ptr;
    double *u = (double *)(void *)(size_t)u_out_ptr;
    if (!x || !u) return;
    for (int i = 0; i < p->n_u; i++) {
        double s = 0;
        for (int j = 0; j < p->n_x; j++) s += p->K[i*p->n_x + j] * x[j];
        u[i] = -s;
    }
}

void nuc_lqr_free(long long h) {
    NLQR *p = (NLQR *)(void *)(size_t)h;
    if (!p) return;
    if (p->A) free(p->A);
    if (p->B) free(p->B);
    if (p->Q) free(p->Q);
    if (p->R) free(p->R);
    if (p->P) free(p->P);
    if (p->K) free(p->K);
    free(p);
}
