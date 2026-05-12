// ekf_rt.c — Extended Kalman Filter for nonlinear state estimation.
//
// Standard Bayesian estimator for systems with nonlinear dynamics
// f(x, u) and nonlinear measurement model h(x). Linearizes both
// around the current state estimate (Jacobians F, H), then runs
// the standard Kalman filter recursion:
//
//   Predict:
//     x⁻       = f(x, u)
//     F        = ∂f/∂x  at x
//     P⁻       = F·P·Fᵀ + Q
//
//   Update (with measurement z):
//     y        = z − h(x⁻)
//     H        = ∂h/∂x  at x⁻
//     S        = H·P⁻·Hᵀ + R
//     K        = P⁻·Hᵀ·S⁻¹
//     x        = x⁻ + K·y
//     P        = (I − K·H)·P⁻
//
// Foundation for sensor fusion (IMU + odometry + GPS), SLAM,
// model-based observers, and any time-varying state estimation.
//
// Both f and h are caller-supplied function-pointer callbacks.
// Their Jacobians are computed by numerical finite differences
// against the same callbacks (no analytical-Jacobian requirement).
//
// **Limitations** (UKF / particle filter for highly-nonlinear
// systems, square-root form for numerical stability, and analytical-
// Jacobian fast paths land in v0.6 if needed):
// - Standard EKF (no UKF / sigma-point variants).
// - No square-root form (Joseph or UD decomposition) — for very
//   long-running filters with tight covariance, prefer UKF or
//   manually re-symmetrize P periodically.
// - Numerical-FD Jacobians (slower than analytical).
//
// Compile: clang -c stdlib/runtime/ekf_rt.c -o target/ekf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*meas_fn_t)(long long x_ptr, long long z_out_ptr);

typedef struct {
    int n_x, n_z, n_u;
    double *x;        // n_x
    double *P;        // n_x * n_x  row-major covariance
    double *Q;        // n_x * n_x  process noise
    double *R;        // n_z * n_z  measurement noise
} NEKF;

// In-place Gauss-Jordan inverse (n×n). Returns 1 on success.
static int _gj_inv(const double *A, int n, double *Ainv) {
    int aug_w = 2 * n;
    double *aug = (double *)malloc((size_t)n * aug_w * sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*aug_w + j] = A[i*n + j];
        for (int j = 0; j < n; j++) aug[i*aug_w + n + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < n; i++) {
        int piv = i;
        for (int r = i + 1; r < n; r++) {
            double a1 = fabs(aug[r*aug_w + i]);
            double a2 = fabs(aug[piv*aug_w + i]);
            if (a1 > a2) piv = r;
        }
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

// Numerical Jacobian of f wrt x via central differences. Writes
// out (n_x × n_x).
static void _dyn_jacobian(dyn_fn_t f, double *x, double *u,
    int n_x, double *F_out, double *scratch_xp, double *scratch_xn)
{
    double eps = 1e-6;
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xp);
        x[j] = sv - eps;
        f((long long)(size_t)x, (long long)(size_t)u, (long long)(size_t)scratch_xn);
        x[j] = sv;
        for (int i = 0; i < n_x; i++) {
            F_out[i*n_x + j] = (scratch_xp[i] - scratch_xn[i]) / (2.0 * eps);
        }
    }
}

// Numerical Jacobian of h wrt x. Writes out (n_z × n_x).
static void _meas_jacobian(meas_fn_t h, double *x, int n_x, int n_z,
    double *H_out, double *scratch_zp, double *scratch_zn)
{
    double eps = 1e-6;
    for (int j = 0; j < n_x; j++) {
        double sv = x[j];
        x[j] = sv + eps;
        h((long long)(size_t)x, (long long)(size_t)scratch_zp);
        x[j] = sv - eps;
        h((long long)(size_t)x, (long long)(size_t)scratch_zn);
        x[j] = sv;
        for (int i = 0; i < n_z; i++) {
            H_out[i*n_x + j] = (scratch_zp[i] - scratch_zn[i]) / (2.0 * eps);
        }
    }
}

long long nuc_ekf_new(long long n_x, long long n_z, long long n_u) {
    if (n_x <= 0 || n_z <= 0) return 0;
    NEKF *e = (NEKF *)calloc(1, sizeof(NEKF));
    e->n_x = (int)n_x;
    e->n_z = (int)n_z;
    e->n_u = (int)n_u;
    e->x = (double *)calloc(e->n_x, sizeof(double));
    e->P = (double *)calloc((size_t)(e->n_x) * e->n_x, sizeof(double));
    e->Q = (double *)calloc((size_t)(e->n_x) * e->n_x, sizeof(double));
    e->R = (double *)calloc((size_t)(e->n_z) * e->n_z, sizeof(double));
    // Default: identity covariance + identity noise.
    for (int i = 0; i < e->n_x; i++) {
        e->P[i*e->n_x + i] = 1.0;
        e->Q[i*e->n_x + i] = 0.01;
    }
    for (int i = 0; i < e->n_z; i++) e->R[i*e->n_z + i] = 0.1;
    return (long long)(size_t)e;
}

void nuc_ekf_set_state(long long h, long long x_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *x = (double *)(void *)(size_t)x_ptr;
    if (x) memcpy(e->x, x, e->n_x * sizeof(double));
}

void nuc_ekf_set_covariance(long long h, long long P_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *P = (double *)(void *)(size_t)P_ptr;
    if (P) memcpy(e->P, P, (size_t)(e->n_x) * e->n_x * sizeof(double));
}

void nuc_ekf_set_process_noise(long long h, long long Q_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *Q = (double *)(void *)(size_t)Q_ptr;
    if (Q) memcpy(e->Q, Q, (size_t)(e->n_x) * e->n_x * sizeof(double));
}

void nuc_ekf_set_measurement_noise(long long h, long long R_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *R = (double *)(void *)(size_t)R_ptr;
    if (R) memcpy(e->R, R, (size_t)(e->n_z) * e->n_z * sizeof(double));
}

void nuc_ekf_get_state(long long h, long long x_out_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *x = (double *)(void *)(size_t)x_out_ptr;
    if (x) memcpy(x, e->x, e->n_x * sizeof(double));
}

void nuc_ekf_get_covariance(long long h, long long P_out_ptr) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    double *P = (double *)(void *)(size_t)P_out_ptr;
    if (P) memcpy(P, e->P, (size_t)(e->n_x) * e->n_x * sizeof(double));
}

// Predict step: x⁻ = f(x, u); F = ∂f/∂x; P⁻ = F·P·Fᵀ + Q.
long long nuc_ekf_predict(long long h_, long long u_ptr, long long dynamics_fp) {
    NEKF *e = (NEKF *)(void *)(size_t)h_;
    if (!e) return -1;
    int n = e->n_x;
    double *u = (double *)(void *)(size_t)u_ptr;
    dyn_fn_t f = (dyn_fn_t)(void *)(size_t)dynamics_fp;
    if (!f) return -1;

    double *x_new = (double *)malloc(n * sizeof(double));
    double *F     = (double *)malloc((size_t)n * n * sizeof(double));
    double *FP    = (double *)malloc((size_t)n * n * sizeof(double));
    double *FPFt  = (double *)malloc((size_t)n * n * sizeof(double));
    double *scr1  = (double *)malloc(n * sizeof(double));
    double *scr2  = (double *)malloc(n * sizeof(double));

    // Linearize at the current x.
    _dyn_jacobian(f, e->x, u, n, F, scr1, scr2);
    // Propagate the mean.
    f((long long)(size_t)e->x, (long long)(size_t)u, (long long)(size_t)x_new);
    memcpy(e->x, x_new, n * sizeof(double));
    // P⁻ = F·P·Fᵀ + Q.
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double s = 0;
            for (int k = 0; k < n; k++) s += F[i*n + k] * e->P[k*n + j];
            FP[i*n + j] = s;
        }
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double s = 0;
            for (int k = 0; k < n; k++) s += FP[i*n + k] * F[j*n + k];
            FPFt[i*n + j] = s;
        }
    for (int i = 0; i < n*n; i++) e->P[i] = FPFt[i] + e->Q[i];

    free(x_new); free(F); free(FP); free(FPFt); free(scr1); free(scr2);
    return 0;
}

// Update step: integrates a new measurement z. Returns 0 on
// success, -1 on bad input or singular S.
long long nuc_ekf_update(long long h_, long long z_ptr, long long measurement_fp) {
    NEKF *e = (NEKF *)(void *)(size_t)h_;
    if (!e) return -1;
    int n_x = e->n_x, n_z = e->n_z;
    double *z = (double *)(void *)(size_t)z_ptr;
    meas_fn_t h_fn = (meas_fn_t)(void *)(size_t)measurement_fp;
    if (!z || !h_fn) return -1;

    double *z_pred = (double *)malloc(n_z * sizeof(double));
    double *H      = (double *)malloc((size_t)n_z * n_x * sizeof(double));
    double *PHt    = (double *)malloc((size_t)n_x * n_z * sizeof(double));
    double *S      = (double *)malloc((size_t)n_z * n_z * sizeof(double));
    double *Sinv   = (double *)malloc((size_t)n_z * n_z * sizeof(double));
    double *K      = (double *)malloc((size_t)n_x * n_z * sizeof(double));
    double *KH     = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    double *scr1   = (double *)malloc(n_z * sizeof(double));
    double *scr2   = (double *)malloc(n_z * sizeof(double));

    _meas_jacobian(h_fn, e->x, n_x, n_z, H, scr1, scr2);
    h_fn((long long)(size_t)e->x, (long long)(size_t)z_pred);

    // P · Hᵀ  (n_x × n_z).
    for (int i = 0; i < n_x; i++)
        for (int j = 0; j < n_z; j++) {
            double s = 0;
            for (int k = 0; k < n_x; k++) s += e->P[i*n_x + k] * H[j*n_x + k];
            PHt[i*n_z + j] = s;
        }
    // S = H · PHt + R  (n_z × n_z).
    for (int i = 0; i < n_z; i++)
        for (int j = 0; j < n_z; j++) {
            double s = 0;
            for (int k = 0; k < n_x; k++) s += H[i*n_x + k] * PHt[k*n_z + j];
            S[i*n_z + j] = s + e->R[i*n_z + j];
        }
    if (!_gj_inv(S, n_z, Sinv)) {
        free(z_pred); free(H); free(PHt); free(S); free(Sinv); free(K); free(KH);
        free(scr1); free(scr2);
        return -1;
    }
    // K = PHt · Sinv  (n_x × n_z).
    for (int i = 0; i < n_x; i++)
        for (int j = 0; j < n_z; j++) {
            double s = 0;
            for (int k = 0; k < n_z; k++) s += PHt[i*n_z + k] * Sinv[k*n_z + j];
            K[i*n_z + j] = s;
        }
    // y = z − z_pred (length n_z).
    double *y = scr1;
    for (int i = 0; i < n_z; i++) y[i] = z[i] - z_pred[i];
    // x ← x + K·y.
    for (int i = 0; i < n_x; i++) {
        double s = 0;
        for (int j = 0; j < n_z; j++) s += K[i*n_z + j] * y[j];
        e->x[i] += s;
    }
    // P ← (I − K·H) · P. Compute KH (n_x × n_x), then form A = I - KH,
    // then P ← A · P.
    for (int i = 0; i < n_x; i++)
        for (int j = 0; j < n_x; j++) {
            double s = 0;
            for (int k = 0; k < n_z; k++) s += K[i*n_z + k] * H[k*n_x + j];
            KH[i*n_x + j] = s;
        }
    double *Pnew = (double *)malloc((size_t)n_x * n_x * sizeof(double));
    for (int i = 0; i < n_x; i++)
        for (int j = 0; j < n_x; j++) {
            double Aij = (i == j ? 1.0 : 0.0) - KH[i*n_x + j];
            double s = 0;
            for (int k = 0; k < n_x; k++) {
                double Aik = (i == k ? 1.0 : 0.0) - KH[i*n_x + k];
                s += Aik * e->P[k*n_x + j];
            }
            (void)Aij;
            Pnew[i*n_x + j] = s;
        }
    memcpy(e->P, Pnew, (size_t)n_x * n_x * sizeof(double));
    free(Pnew);

    free(z_pred); free(H); free(PHt); free(S); free(Sinv); free(K); free(KH);
    free(scr1); free(scr2);
    return 0;
}

void nuc_ekf_free(long long h) {
    NEKF *e = (NEKF *)(void *)(size_t)h;
    if (!e) return;
    if (e->x) free(e->x);
    if (e->P) free(e->P);
    if (e->Q) free(e->Q);
    if (e->R) free(e->R);
    free(e);
}
