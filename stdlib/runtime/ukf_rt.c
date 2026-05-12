// ukf_rt.c — Unscented Kalman Filter for nonlinear state
// estimation.
//
// The UKF avoids the explicit Jacobian linearization of the EKF
// by sampling 2n+1 deterministic "sigma points" around the
// current mean, propagating each through the nonlinear dynamics
// or measurement function, and reconstructing the posterior mean
// + covariance from the propagated samples.
//
//   Predict:
//     1. Generate 2n+1 sigma points X_i around (x, P).
//     2. Propagate: Y_i = f(X_i, u).
//     3. x⁻       = Σ wm_i · Y_i
//        P⁻       = Σ wc_i · (Y_i − x⁻)(Y_i − x⁻)ᵀ + Q
//
//   Update (with measurement z):
//     1. Generate 2n+1 sigma points Y_i around (x⁻, P⁻).
//     2. Z_i       = h(Y_i)
//     3. z_pred    = Σ wm_i · Z_i
//        S         = Σ wc_i · (Z_i − z_pred)(Z_i − z_pred)ᵀ + R
//        Pxz       = Σ wc_i · (Y_i − x⁻)(Z_i − z_pred)ᵀ
//        K         = Pxz · S⁻¹
//        x         = x⁻ + K·(z − z_pred)
//        P         = P⁻ − K·S·Kᵀ
//
// Better than EKF for systems where the Jacobian doesn't capture
// the local geometry well (e.g., orientation-dependent dynamics,
// non-monotonic measurement functions, multi-modal posteriors).
// Same callback contract as `ekf_rt.c`.
//
// Standard scaled-sigma-point parameters (Wan & van der Merwe
// 2000): α = 1e-3, β = 2 (Gaussian assumption), κ = 0.
//
// **Limitations** (square-root form for numerical stability lands
// in v0.6 if needed):
// - Standard form (no square-root variant) — for very long-running
//   filters with tight covariance, may need periodic re-symmetrize
//   of P.
// - Cholesky via Jacobi eigendecomposition + sqrt of eigenvalues
//   (more numerically stable than naïve Cholesky for ill-
//   conditioned P).
//
// Compile: clang -c stdlib/runtime/ukf_rt.c -o target/ukf.obj -O2

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
    double *P;        // n_x * n_x
    double *Q;        // n_x * n_x
    double *R;        // n_z * n_z
    double alpha, beta, kappa;
    double lambda;    // = α²·(n+κ) − n
    double *wm;       // 2n+1 mean weights
    double *wc;       // 2n+1 covariance weights
} NUKF;

// Gauss-Jordan inverse (n×n).
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
            if (fabs(aug[r*aug_w + i]) > fabs(aug[piv*aug_w + i])) piv = r;
        }
        if (fabs(aug[piv*aug_w + i]) < 1e-14) { free(aug); return 0; }
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

// Symmetric matrix square root via eigendecomposition. For an
// n×n SPD matrix M, returns L such that L·Lᵀ = M (more stable
// than naïve Cholesky on ill-conditioned matrices). Uses Jacobi
// rotations.
static void _sym_sqrt(double *M, int n, double *L) {
    // Copy M into a working buffer.
    double *A = (double *)malloc((size_t)n * n * sizeof(double));
    double *V = (double *)malloc((size_t)n * n * sizeof(double));
    memcpy(A, M, (size_t)n * n * sizeof(double));
    for (int i = 0; i < n*n; i++) V[i] = (i / n == i % n) ? 1.0 : 0.0;

    // Jacobi diagonalization (max sweeps).
    for (int sweep = 0; sweep < 100; sweep++) {
        // Find largest off-diagonal element.
        int p = 0, q = 1;
        double best = fabs(A[0*n + 1]);
        for (int i = 0; i < n; i++)
            for (int j = i+1; j < n; j++) {
                if (fabs(A[i*n + j]) > best) { best = fabs(A[i*n + j]); p = i; q = j; }
            }
        if (best < 1e-14) break;
        double a_pp = A[p*n + p], a_qq = A[q*n + q], a_pq = A[p*n + q];
        double theta = (a_qq - a_pp) / (2.0 * a_pq);
        double t = (theta > 0)
            ?  1.0 / ( theta + sqrt(1.0 + theta*theta))
            : -1.0 / (-theta + sqrt(1.0 + theta*theta));
        double c = 1.0 / sqrt(1.0 + t*t);
        double s = t * c;
        A[p*n + p] = a_pp - t * a_pq;
        A[q*n + q] = a_qq + t * a_pq;
        A[p*n + q] = 0; A[q*n + p] = 0;
        for (int i = 0; i < n; i++) {
            if (i == p || i == q) continue;
            double a_ip = A[i*n + p], a_iq = A[i*n + q];
            A[i*n + p] = c * a_ip - s * a_iq; A[p*n + i] = A[i*n + p];
            A[i*n + q] = s * a_ip + c * a_iq; A[q*n + i] = A[i*n + q];
        }
        for (int i = 0; i < n; i++) {
            double v_ip = V[i*n + p], v_iq = V[i*n + q];
            V[i*n + p] = c * v_ip - s * v_iq;
            V[i*n + q] = s * v_ip + c * v_iq;
        }
    }
    // L = V · diag(sqrt(eigenvalues)). Clamp negatives to 0 for
    // numerical robustness.
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            double ev = A[j*n + j];
            if (ev < 0) ev = 0;
            L[i*n + j] = V[i*n + j] * sqrt(ev);
        }
    }
    free(A); free(V);
}

long long nuc_ukf_new(long long n_x, long long n_z, long long n_u) {
    if (n_x <= 0 || n_z <= 0) return 0;
    NUKF *u = (NUKF *)calloc(1, sizeof(NUKF));
    u->n_x = (int)n_x; u->n_z = (int)n_z; u->n_u = (int)n_u;
    u->x = (double *)calloc(u->n_x, sizeof(double));
    u->P = (double *)calloc((size_t)(u->n_x) * u->n_x, sizeof(double));
    u->Q = (double *)calloc((size_t)(u->n_x) * u->n_x, sizeof(double));
    u->R = (double *)calloc((size_t)(u->n_z) * u->n_z, sizeof(double));
    for (int i = 0; i < u->n_x; i++) {
        u->P[i*u->n_x + i] = 1.0;
        u->Q[i*u->n_x + i] = 0.01;
    }
    for (int i = 0; i < u->n_z; i++) u->R[i*u->n_z + i] = 0.1;
    // Default scaled-sigma-point params (Wan & van der Merwe 2000).
    u->alpha = 1e-3;
    u->beta  = 2.0;
    u->kappa = 0.0;
    u->lambda = u->alpha * u->alpha * (u->n_x + u->kappa) - u->n_x;
    int n_sig = 2 * u->n_x + 1;
    u->wm = (double *)malloc(n_sig * sizeof(double));
    u->wc = (double *)malloc(n_sig * sizeof(double));
    u->wm[0] = u->lambda / (u->n_x + u->lambda);
    u->wc[0] = u->lambda / (u->n_x + u->lambda) + (1 - u->alpha*u->alpha + u->beta);
    for (int i = 1; i < n_sig; i++) {
        u->wm[i] = u->wc[i] = 1.0 / (2.0 * (u->n_x + u->lambda));
    }
    return (long long)(size_t)u;
}

void nuc_ukf_set_state(long long h, long long x_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *x = (double *)(void *)(size_t)x_ptr;
    if (x) memcpy(u->x, x, u->n_x * sizeof(double));
}
void nuc_ukf_set_covariance(long long h, long long P_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *P = (double *)(void *)(size_t)P_ptr;
    if (P) memcpy(u->P, P, (size_t)(u->n_x) * u->n_x * sizeof(double));
}
void nuc_ukf_set_process_noise(long long h, long long Q_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *Q = (double *)(void *)(size_t)Q_ptr;
    if (Q) memcpy(u->Q, Q, (size_t)(u->n_x) * u->n_x * sizeof(double));
}
void nuc_ukf_set_measurement_noise(long long h, long long R_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *R = (double *)(void *)(size_t)R_ptr;
    if (R) memcpy(u->R, R, (size_t)(u->n_z) * u->n_z * sizeof(double));
}
void nuc_ukf_get_state(long long h, long long x_out_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *x = (double *)(void *)(size_t)x_out_ptr;
    if (x) memcpy(x, u->x, u->n_x * sizeof(double));
}
void nuc_ukf_get_covariance(long long h, long long P_out_ptr) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    double *P = (double *)(void *)(size_t)P_out_ptr;
    if (P) memcpy(P, u->P, (size_t)(u->n_x) * u->n_x * sizeof(double));
}

// Generate 2n+1 sigma points: X_0 = x, X_{i} = x + sqrt((n+λ)·P)_i,
// X_{i+n} = x − sqrt((n+λ)·P)_i.
static void _gen_sigma(double *x, double *P, int n, double lambda,
                       double *sigma_out)
{
    double *L = (double *)malloc((size_t)n * n * sizeof(double));
    double *Ps = (double *)malloc((size_t)n * n * sizeof(double));
    double scale = (double)(n) + lambda;
    for (int i = 0; i < n*n; i++) Ps[i] = scale * P[i];
    _sym_sqrt(Ps, n, L);
    // sigma 0 = x.
    for (int i = 0; i < n; i++) sigma_out[0*n + i] = x[i];
    // sigma i = x + L column i (i = 1..n); sigma i+n = x − L column i.
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            sigma_out[(i+1)*n     + j] = x[j] + L[j*n + i];
            sigma_out[(i+1+n)*n   + j] = x[j] - L[j*n + i];
        }
    }
    free(L); free(Ps);
}

long long nuc_ukf_predict(long long h_, long long u_ptr, long long dynamics_fp) {
    NUKF *u = (NUKF *)(void *)(size_t)h_;
    if (!u) return -1;
    int n = u->n_x;
    int n_sig = 2 * n + 1;
    dyn_fn_t f = (dyn_fn_t)(void *)(size_t)dynamics_fp;
    if (!f) return -1;

    double *sig = (double *)malloc((size_t)n_sig * n * sizeof(double));
    double *prop = (double *)malloc((size_t)n_sig * n * sizeof(double));
    _gen_sigma(u->x, u->P, n, u->lambda, sig);
    for (int i = 0; i < n_sig; i++) {
        f((long long)(size_t)(sig + i*n), u_ptr, (long long)(size_t)(prop + i*n));
    }
    // Mean.
    double *x_new = (double *)calloc(n, sizeof(double));
    for (int i = 0; i < n_sig; i++)
        for (int j = 0; j < n; j++) x_new[j] += u->wm[i] * prop[i*n + j];
    // Covariance.
    double *P_new = (double *)calloc((size_t)n * n, sizeof(double));
    for (int i = 0; i < n_sig; i++) {
        double w = u->wc[i];
        for (int r = 0; r < n; r++) {
            double dr = prop[i*n + r] - x_new[r];
            for (int c = 0; c < n; c++) {
                double dc = prop[i*n + c] - x_new[c];
                P_new[r*n + c] += w * dr * dc;
            }
        }
    }
    for (int i = 0; i < n*n; i++) P_new[i] += u->Q[i];

    memcpy(u->x, x_new, n * sizeof(double));
    memcpy(u->P, P_new, (size_t)n * n * sizeof(double));
    free(sig); free(prop); free(x_new); free(P_new);
    return 0;
}

long long nuc_ukf_update(long long h_, long long z_ptr, long long measurement_fp) {
    NUKF *u = (NUKF *)(void *)(size_t)h_;
    if (!u) return -1;
    int n_x = u->n_x, n_z = u->n_z;
    int n_sig = 2 * n_x + 1;
    double *z = (double *)(void *)(size_t)z_ptr;
    meas_fn_t h_fn = (meas_fn_t)(void *)(size_t)measurement_fp;
    if (!z || !h_fn) return -1;

    double *sig = (double *)malloc((size_t)n_sig * n_x * sizeof(double));
    double *Z   = (double *)malloc((size_t)n_sig * n_z * sizeof(double));
    _gen_sigma(u->x, u->P, n_x, u->lambda, sig);
    for (int i = 0; i < n_sig; i++) {
        h_fn((long long)(size_t)(sig + i*n_x), (long long)(size_t)(Z + i*n_z));
    }
    // Mean of measurement sigma points.
    double *z_pred = (double *)calloc(n_z, sizeof(double));
    for (int i = 0; i < n_sig; i++)
        for (int j = 0; j < n_z; j++) z_pred[j] += u->wm[i] * Z[i*n_z + j];
    // Innovation covariance S and cross-covariance Pxz.
    double *S = (double *)calloc((size_t)n_z * n_z, sizeof(double));
    double *Pxz = (double *)calloc((size_t)n_x * n_z, sizeof(double));
    for (int i = 0; i < n_sig; i++) {
        double w = u->wc[i];
        for (int r = 0; r < n_z; r++) {
            double dr = Z[i*n_z + r] - z_pred[r];
            for (int c = 0; c < n_z; c++) {
                double dc = Z[i*n_z + c] - z_pred[c];
                S[r*n_z + c] += w * dr * dc;
            }
        }
        for (int r = 0; r < n_x; r++) {
            double dxr = sig[i*n_x + r] - u->x[r];
            for (int c = 0; c < n_z; c++) {
                double dzc = Z[i*n_z + c] - z_pred[c];
                Pxz[r*n_z + c] += w * dxr * dzc;
            }
        }
    }
    for (int i = 0; i < n_z*n_z; i++) S[i] += u->R[i];

    double *Sinv = (double *)malloc((size_t)n_z * n_z * sizeof(double));
    if (!_gj_inv(S, n_z, Sinv)) {
        free(sig); free(Z); free(z_pred); free(S); free(Pxz); free(Sinv);
        return -1;
    }
    // K = Pxz · Sinv (n_x × n_z).
    double *K = (double *)malloc((size_t)n_x * n_z * sizeof(double));
    for (int r = 0; r < n_x; r++)
        for (int c = 0; c < n_z; c++) {
            double s = 0;
            for (int k = 0; k < n_z; k++) s += Pxz[r*n_z + k] * Sinv[k*n_z + c];
            K[r*n_z + c] = s;
        }
    // x ← x + K·(z − z_pred).
    for (int i = 0; i < n_x; i++) {
        double s = 0;
        for (int k = 0; k < n_z; k++) s += K[i*n_z + k] * (z[k] - z_pred[k]);
        u->x[i] += s;
    }
    // P ← P − K·S·Kᵀ.
    double *KS = (double *)malloc((size_t)n_x * n_z * sizeof(double));
    for (int r = 0; r < n_x; r++)
        for (int c = 0; c < n_z; c++) {
            double s = 0;
            for (int k = 0; k < n_z; k++) s += K[r*n_z + k] * S[k*n_z + c];
            KS[r*n_z + c] = s;
        }
    for (int r = 0; r < n_x; r++)
        for (int c = 0; c < n_x; c++) {
            double s = 0;
            for (int k = 0; k < n_z; k++) s += KS[r*n_z + k] * K[c*n_z + k];
            u->P[r*n_x + c] -= s;
        }

    free(sig); free(Z); free(z_pred); free(S); free(Pxz); free(Sinv); free(K); free(KS);
    return 0;
}

void nuc_ukf_free(long long h) {
    NUKF *u = (NUKF *)(void *)(size_t)h;
    if (!u) return;
    if (u->x) free(u->x); if (u->P) free(u->P);
    if (u->Q) free(u->Q); if (u->R) free(u->R);
    if (u->wm) free(u->wm); if (u->wc) free(u->wc);
    free(u);
}
