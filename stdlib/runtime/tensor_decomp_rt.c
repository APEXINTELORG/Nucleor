// tensor_decomp_rt.c — Tensor Decompositions for Nucleor
// CP decomposition, Tucker, Tensor Train (TT-SVD), tensor contraction.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/tensor_decomp_rt.c -o target/tensor_decomp_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _td_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _td_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } TDVec;

static TDVec *tdvec_new(int n) {
    TDVec *v = (TDVec *)malloc(sizeof(TDVec));
    v->len = n; v->cap = n; v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// In-place R x R Gauss-Jordan inverse with partial pivoting. Returns
// 0 on success, -1 on singular matrix. Used by CP-ALS audit fix
// F-MATH-002 (2026-05-08) to replace the diagonal-only "solve".
static int _td_invert_rxr(double *gram, int R) {
    // Build augmented [gram | I] and reduce.
    double *aug = (double *)calloc((size_t)R * 2 * R, sizeof(double));
    if (!aug) return -1;
    for (int i = 0; i < R; i++) {
        for (int j = 0; j < R; j++) aug[i * 2 * R + j] = gram[i * R + j];
        aug[i * 2 * R + R + i] = 1.0;
    }
    for (int k = 0; k < R; k++) {
        int max_row = k;
        double max_val = fabs(aug[k * 2 * R + k]);
        for (int i = k + 1; i < R; i++) {
            double v = fabs(aug[i * 2 * R + k]);
            if (v > max_val) { max_val = v; max_row = i; }
        }
        if (max_val < 1e-15) { free(aug); return -1; }
        if (max_row != k) {
            for (int j = 0; j < 2 * R; j++) {
                double t = aug[k * 2 * R + j];
                aug[k * 2 * R + j] = aug[max_row * 2 * R + j];
                aug[max_row * 2 * R + j] = t;
            }
        }
        double pivot = aug[k * 2 * R + k];
        for (int j = 0; j < 2 * R; j++) aug[k * 2 * R + j] /= pivot;
        for (int i = 0; i < R; i++) {
            if (i == k) continue;
            double factor = aug[i * 2 * R + k];
            for (int j = 0; j < 2 * R; j++)
                aug[i * 2 * R + j] -= factor * aug[k * 2 * R + j];
        }
    }
    for (int i = 0; i < R; i++)
        for (int j = 0; j < R; j++) gram[i * R + j] = aug[i * 2 * R + R + j];
    free(aug);
    return 0;
}

// dst[I, R] = V[I, R] * gram_inv[R, R]   (dense matmul; if gram is
// singular, falls back to the Tikhonov-regularized diagonal pattern
// to remain numerically robust). CP-ALS audit fix helper.
static void _td_factor_update(double *dst, const double *V, double *gram,
                               int I, int R) {
    if (_td_invert_rxr(gram, R) == 0) {
        for (int i = 0; i < I; i++)
            for (int r = 0; r < R; r++) {
                double s = 0;
                for (int rp = 0; rp < R; rp++)
                    s += V[i * R + rp] * gram[rp * R + r];
                dst[i * R + r] = s;
            }
    } else {
        // Singular fallback: per-rank diagonal solve (legacy behavior).
        for (int i = 0; i < I; i++)
            for (int r = 0; r < R; r++)
                dst[i * R + r] = (fabs(gram[r * R + r]) > 1e-15)
                    ? V[i * R + r] / gram[r * R + r] : 0;
    }
}

// ================================================================
//  CP Decomposition (ALS — Alternating Least Squares)
//  Decomposes 3D tensor X[I,J,K] into sum of R rank-1 terms:
//  X ≈ sum_r a_r ⊗ b_r ⊗ c_r
//  Returns factors A[I,R], B[J,R], C[K,R] packed flat.
// ================================================================

long long nuc_td_cp_als(long long X_h, long long I, long long J, long long K, long long R, long long max_iter) {
    TDVec *X = (TDVec *)(void *)X_h;
    int ii = (int)I, jj = (int)J, kk = (int)K, rr = (int)R, mi = (int)max_iter;

    double *A = (double *)malloc((size_t)ii * rr * sizeof(double));
    double *B = (double *)malloc((size_t)jj * rr * sizeof(double));
    double *C = (double *)malloc((size_t)kk * rr * sizeof(double));

    // Random init
    unsigned int rng = 12345;
    for (int i = 0; i < ii * rr; i++) { rng = rng * 1103515245 + 12345; A[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }
    for (int i = 0; i < jj * rr; i++) { rng = rng * 1103515245 + 12345; B[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }
    for (int i = 0; i < kk * rr; i++) { rng = rng * 1103515245 + 12345; C[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }

    double *Xd = (double *)malloc((size_t)ii * jj * kk * sizeof(double));
    for (int i = 0; i < ii * jj * kk && i < X->len; i++) Xd[i] = _td_i2f(X->data[i]);

    for (int iter = 0; iter < mi; iter++) {
        // Update A: solve X_(1) ≈ A * (C ⊙ B)^T
        // where ⊙ is Khatri-Rao product, X_(1) is mode-1 unfolding [I, J*K]
        double *BtB = (double *)calloc((size_t)rr * rr, sizeof(double));
        double *CtC = (double *)calloc((size_t)rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int j = 0; j < jj; j++) BtB[r1 * rr + r2] += B[j * rr + r1] * B[j * rr + r2];
                for (int k = 0; k < kk; k++) CtC[r1 * rr + r2] += C[k * rr + r1] * C[k * rr + r2];
            }
        // Hadamard product
        double *gram = (double *)malloc((size_t)rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = BtB[i] * CtC[i];

        // MTTKRP: V = X_(1) * (C ⊙ B) [I, R]
        double *V = (double *)calloc((size_t)ii * rr, sizeof(double));
        for (int i = 0; i < ii; i++)
            for (int j = 0; j < jj; j++)
                for (int k = 0; k < kk; k++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++)
                        V[i * rr + r] += xval * B[j * rr + r] * C[k * rr + r];
                }

        // Audit fix F-MATH-002 (HIGH, 2026-05-08): use full pseudoinverse
        // of the R x R gram matrix instead of the diagonal-only "solve".
        // Real CP-ALS (Kolda & Bader 2009 §3.4) requires solving
        // A^T = (gram)^{-1} V^T against the dense gram, NOT just the
        // diagonal. The helper falls back to the diagonal pattern only
        // when gram is numerically singular.
        _td_factor_update(A, V, gram, ii, rr);

        free(BtB); free(CtC); free(gram); free(V);

        // Similar updates for B and C (symmetric structure)
        // Update B
        double *AtA = (double *)calloc((size_t)rr * rr, sizeof(double));
        CtC = (double *)calloc((size_t)rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int i = 0; i < ii; i++) AtA[r1 * rr + r2] += A[i * rr + r1] * A[i * rr + r2];
                for (int k = 0; k < kk; k++) CtC[r1 * rr + r2] += C[k * rr + r1] * C[k * rr + r2];
            }
        gram = (double *)malloc((size_t)rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = AtA[i] * CtC[i];
        V = (double *)calloc((size_t)jj * rr, sizeof(double));
        for (int j = 0; j < jj; j++)
            for (int i = 0; i < ii; i++)
                for (int k = 0; k < kk; k++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++) V[j * rr + r] += xval * A[i * rr + r] * C[k * rr + r];
                }
        // F-MATH-002 (HIGH): full pseudoinverse update for B.
        _td_factor_update(B, V, gram, jj, rr);
        free(AtA); free(CtC); free(gram); free(V);

        // Update C
        AtA = (double *)calloc((size_t)rr * rr, sizeof(double));
        BtB = (double *)calloc((size_t)rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int i = 0; i < ii; i++) AtA[r1 * rr + r2] += A[i * rr + r1] * A[i * rr + r2];
                for (int j = 0; j < jj; j++) BtB[r1 * rr + r2] += B[j * rr + r1] * B[j * rr + r2];
            }
        gram = (double *)malloc((size_t)rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = AtA[i] * BtB[i];
        V = (double *)calloc((size_t)kk * rr, sizeof(double));
        for (int k = 0; k < kk; k++)
            for (int i = 0; i < ii; i++)
                for (int j = 0; j < jj; j++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++) V[k * rr + r] += xval * A[i * rr + r] * B[j * rr + r];
                }
        // F-MATH-002 (HIGH): full pseudoinverse update for C.
        _td_factor_update(C, V, gram, kk, rr);
        free(AtA); free(BtB); free(gram); free(V);
    }
    free(Xd);

    // Pack result: [A..., B..., C...]
    int total = ii * rr + jj * rr + kk * rr;
    TDVec *result = tdvec_new(total);
    int off = 0;
    for (int i = 0; i < ii * rr; i++) result->data[off++] = _td_f2i(A[i]);
    for (int i = 0; i < jj * rr; i++) result->data[off++] = _td_f2i(B[i]);
    for (int i = 0; i < kk * rr; i++) result->data[off++] = _td_f2i(C[i]);
    free(A); free(B); free(C);
    return (long long)result;
}

// ================================================================
//  Tensor Train SVD (TT-SVD)
//  Decomposes tensor T[n1, n2, ..., nd] into chain of cores.
//  Simplified for 3D: T[n1, n2, n3] → G1[1, n1, r1] * G2[r1, n2, r2] * G3[r2, n3, 1]
// ================================================================

// Internal: thin-SVD A (m x n) -> U (m x k), S (k), Vt (k x n) where
// k = min(m, n). Uses the symmetric Jacobi eigensolver on A^T A (or
// A A^T for tall matrices, whichever is smaller) to extract right /
// left singular vectors. Returns 0 on success.
//
// This is the same numerical recipe as nuc_mat_svd in linalg_rt.c,
// reimplemented here as a flat-buffer helper so tensor_decomp_rt.c
// does not depend on the LAMat handle ABI. Used by the TT-SVD
// implementation below (audit fix F-MATH-001, 2026-05-08).
static int _td_thin_svd(const double *A, int m, int n,
                        double *U, double *S, double *Vt) {
    int k = m < n ? m : n;
    // Operate on the smaller of A^T A (n x n) or A A^T (m x m).
    if (n <= m) {
        // Form M = A^T A (n x n).
        double *M = (double *)calloc((size_t)n * n, sizeof(double));
        if (!M) return -1;
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++) {
                double s = 0;
                for (int l = 0; l < m; l++) s += A[l * n + i] * A[l * n + j];
                M[i * n + j] = s;
            }
        // Jacobi eigendecomposition: M = V * diag(eig) * V^T.
        double *V = (double *)calloc((size_t)n * n, sizeof(double));
        if (!V) { free(M); return -1; }
        for (int i = 0; i < n; i++) V[i * n + i] = 1.0;
        for (int iter = 0; iter < 200; iter++) {
            double off = 0;
            for (int i = 0; i < n; i++)
                for (int j = i + 1; j < n; j++)
                    off += M[i * n + j] * M[i * n + j];
            if (off < 1e-24) break;
            int p = 0, q = 1; double max_off = 0;
            for (int i = 0; i < n; i++)
                for (int j = i + 1; j < n; j++)
                    if (fabs(M[i * n + j]) > max_off) {
                        max_off = fabs(M[i * n + j]); p = i; q = j;
                    }
            double app = M[p * n + p], aqq = M[q * n + q], apq = M[p * n + q];
            double theta = (fabs(app - aqq) < 1e-15)
                ? 3.14159265358979323846 / 4.0
                : 0.5 * atan2(2.0 * apq, app - aqq);
            double c = cos(theta), s = sin(theta);
            for (int i = 0; i < n; i++) {
                double aip = M[i * n + p], aiq = M[i * n + q];
                M[i * n + p] = c * aip + s * aiq;
                M[i * n + q] = -s * aip + c * aiq;
            }
            for (int j = 0; j < n; j++) {
                double apj = M[p * n + j], aqj = M[q * n + j];
                M[p * n + j] = c * apj + s * aqj;
                M[q * n + j] = -s * apj + c * aqj;
            }
            for (int i = 0; i < n; i++) {
                double vip = V[i * n + p], viq = V[i * n + q];
                V[i * n + p] = c * vip + s * viq;
                V[i * n + q] = -s * vip + c * viq;
            }
        }
        // Sort eigenvalues descending.
        int *order = (int *)malloc((size_t)n * sizeof(int));
        if (!order) { free(M); free(V); return -1; }
        for (int i = 0; i < n; i++) order[i] = i;
        for (int i = 0; i < n - 1; i++)
            for (int j = i + 1; j < n; j++)
                if (M[order[j] * n + order[j]] > M[order[i] * n + order[i]]) {
                    int t = order[i]; order[i] = order[j]; order[j] = t;
                }
        // S = sqrt(eig) (top k), Vt = V[:, order[0..k]]^T.
        for (int i = 0; i < k; i++) {
            double ev = M[order[i] * n + order[i]];
            S[i] = (ev > 0) ? sqrt(ev) : 0.0;
        }
        for (int i = 0; i < k; i++)
            for (int j = 0; j < n; j++)
                Vt[i * n + j] = V[j * n + order[i]];
        // U = A * V * diag(1/S).
        for (int j = 0; j < k; j++) {
            if (S[j] < 1e-15) {
                for (int i = 0; i < m; i++) U[i * k + j] = 0;
                continue;
            }
            double inv_s = 1.0 / S[j];
            for (int i = 0; i < m; i++) {
                double sum = 0;
                for (int l = 0; l < n; l++) sum += A[i * n + l] * V[l * n + order[j]];
                U[i * k + j] = sum * inv_s;
            }
        }
        free(order); free(M); free(V);
    } else {
        // Form M = A A^T (m x m), get U directly, derive Vt by V = A^T U / S.
        double *M = (double *)calloc((size_t)m * m, sizeof(double));
        if (!M) return -1;
        for (int i = 0; i < m; i++)
            for (int j = 0; j < m; j++) {
                double s = 0;
                for (int l = 0; l < n; l++) s += A[i * n + l] * A[j * n + l];
                M[i * m + j] = s;
            }
        double *Vmat = (double *)calloc((size_t)m * m, sizeof(double));
        if (!Vmat) { free(M); return -1; }
        for (int i = 0; i < m; i++) Vmat[i * m + i] = 1.0;
        for (int iter = 0; iter < 200; iter++) {
            double off = 0;
            for (int i = 0; i < m; i++)
                for (int j = i + 1; j < m; j++)
                    off += M[i * m + j] * M[i * m + j];
            if (off < 1e-24) break;
            int p = 0, q = 1; double max_off = 0;
            for (int i = 0; i < m; i++)
                for (int j = i + 1; j < m; j++)
                    if (fabs(M[i * m + j]) > max_off) {
                        max_off = fabs(M[i * m + j]); p = i; q = j;
                    }
            double app = M[p * m + p], aqq = M[q * m + q], apq = M[p * m + q];
            double theta = (fabs(app - aqq) < 1e-15)
                ? 3.14159265358979323846 / 4.0
                : 0.5 * atan2(2.0 * apq, app - aqq);
            double c = cos(theta), s = sin(theta);
            for (int i = 0; i < m; i++) {
                double aip = M[i * m + p], aiq = M[i * m + q];
                M[i * m + p] = c * aip + s * aiq;
                M[i * m + q] = -s * aip + c * aiq;
            }
            for (int j = 0; j < m; j++) {
                double apj = M[p * m + j], aqj = M[q * m + j];
                M[p * m + j] = c * apj + s * aqj;
                M[q * m + j] = -s * apj + c * aqj;
            }
            for (int i = 0; i < m; i++) {
                double vip = Vmat[i * m + p], viq = Vmat[i * m + q];
                Vmat[i * m + p] = c * vip + s * viq;
                Vmat[i * m + q] = -s * vip + c * viq;
            }
        }
        int *order = (int *)malloc((size_t)m * sizeof(int));
        if (!order) { free(M); free(Vmat); return -1; }
        for (int i = 0; i < m; i++) order[i] = i;
        for (int i = 0; i < m - 1; i++)
            for (int j = i + 1; j < m; j++)
                if (M[order[j] * m + order[j]] > M[order[i] * m + order[i]]) {
                    int t = order[i]; order[i] = order[j]; order[j] = t;
                }
        for (int i = 0; i < k; i++) {
            double ev = M[order[i] * m + order[i]];
            S[i] = (ev > 0) ? sqrt(ev) : 0.0;
        }
        for (int j = 0; j < k; j++)
            for (int i = 0; i < m; i++)
                U[i * k + j] = Vmat[i * m + order[j]];
        for (int j = 0; j < k; j++) {
            if (S[j] < 1e-15) {
                for (int l = 0; l < n; l++) Vt[j * n + l] = 0;
                continue;
            }
            double inv_s = 1.0 / S[j];
            for (int l = 0; l < n; l++) {
                double sum = 0;
                for (int i = 0; i < m; i++) sum += A[i * n + l] * U[i * k + j];
                Vt[j * n + l] = sum * inv_s;
            }
        }
        free(order); free(M); free(Vmat);
    }
    return 0;
}

// Audit fix F-MATH-001 (CRITICAL, 2026-05-08): real TT-SVD via two
// truncated SVDs. The prior code returned identity-shaped placeholder
// cores (G1 = identity, G2 = identity-indicator, G3 = first slice of
// remainder), which means G1 ×_3 G2 ×_3 G3 did NOT approximate the
// input tensor. Now follows Oseledets 2011 §3.1 (TT-SVD):
//
//   1) Reshape X[d1, d2, d3] -> A1 [d1, d2*d3].
//   2) SVD: A1 = U1 S1 V1^T, truncate to rank r1 = min(d1, d2*d3, max_rank).
//      Set G1 = U1 (shape [d1, r1]).
//   3) Form B = (S1 * V1^T)[:r1, :]  (shape [r1, d2*d3])
//      reshape -> A2 [r1*d2, d3].
//   4) SVD: A2 = U2 S2 V2^T, truncate to rank r2 = min(r1*d2, d3, max_rank).
//      Set G2 = U2 reshaped to [r1, d2, r2], G3 = (S2 * V2^T)[:r2, :]
//      shape [r2, d3].
//
// G1 ×_3 G2 ×_3 G3 now approximates the input to within the truncation
// tolerance set by max_rank.
long long nuc_td_tt_svd_3d_max_rank(long long X_h, long long n1, long long n2, long long n3,
                                      long long max_rank) {
    TDVec *X = (TDVec *)(void *)X_h;
    int d1 = (int)n1, d2 = (int)n2, d3 = (int)n3, mr = (int)max_rank;
    if (mr < 1) mr = 1;

    double *Xd = (double *)malloc((size_t)d1 * d2 * d3 * sizeof(double));
    for (int i = 0; i < d1 * d2 * d3 && i < X->len; i++) Xd[i] = _td_i2f(X->data[i]);

    // ---- First SVD: A1 = X reshape [d1, d2*d3] = U1 S1 V1^T --------
    int m1 = d1, n_1 = d2 * d3;
    int k1 = m1 < n_1 ? m1 : n_1;          // exact min
    int r1 = k1 < mr ? k1 : mr;            // truncated rank

    double *U1 = (double *)calloc((size_t)m1 * k1, sizeof(double));
    double *S1 = (double *)calloc((size_t)k1, sizeof(double));
    double *Vt1 = (double *)calloc((size_t)k1 * n_1, sizeof(double));
    _td_thin_svd(Xd, m1, n_1, U1, S1, Vt1);

    // G1 = U1[:, :r1]   (shape [d1, r1])
    double *G1 = (double *)calloc((size_t)d1 * r1, sizeof(double));
    for (int i = 0; i < d1; i++)
        for (int r = 0; r < r1; r++) G1[i * r1 + r] = U1[i * k1 + r];

    // remainder = (S1 * V1^T)[:r1, :]   shape [r1, d2*d3]
    double *remainder = (double *)calloc((size_t)r1 * d2 * d3, sizeof(double));
    for (int r = 0; r < r1; r++)
        for (int j = 0; j < d2 * d3; j++)
            remainder[r * d2 * d3 + j] = S1[r] * Vt1[r * n_1 + j];

    // ---- Second SVD: A2 = remainder reshape [r1*d2, d3] = U2 S2 V2^T ----
    int m2 = r1 * d2, n_2 = d3;
    int k2 = m2 < n_2 ? m2 : n_2;
    int r2 = k2 < mr ? k2 : mr;

    double *U2 = (double *)calloc((size_t)m2 * k2, sizeof(double));
    double *S2 = (double *)calloc((size_t)k2, sizeof(double));
    double *Vt2 = (double *)calloc((size_t)k2 * n_2, sizeof(double));
    _td_thin_svd(remainder, m2, n_2, U2, S2, Vt2);

    // G2 = U2[:, :r2] reshaped to [r1, d2, r2]
    double *G2 = (double *)calloc((size_t)r1 * d2 * r2, sizeof(double));
    for (int i = 0; i < r1; i++)
        for (int j = 0; j < d2; j++)
            for (int r = 0; r < r2; r++)
                G2[i * d2 * r2 + j * r2 + r] = U2[(i * d2 + j) * k2 + r];

    // G3 = (S2 * V2^T)[:r2, :]   shape [r2, d3]
    double *G3 = (double *)calloc((size_t)r2 * d3, sizeof(double));
    for (int r = 0; r < r2; r++)
        for (int k = 0; k < d3; k++)
            G3[r * d3 + k] = S2[r] * Vt2[r * n_2 + k];

    // Pack: [r1, r2, g1s, g2s, g3s, padding, G1..., G2..., G3...]
    int g1s = d1 * r1, g2s = r1 * d2 * r2, g3s = r2 * d3;
    TDVec *result = tdvec_new(6 + g1s + g2s + g3s);
    result->data[0] = r1; result->data[1] = r2;
    result->data[2] = g1s; result->data[3] = g2s; result->data[4] = g3s;
    result->data[5] = 0; // padding
    int off = 6;
    for (int i = 0; i < g1s; i++) result->data[off++] = _td_f2i(G1[i]);
    for (int i = 0; i < g2s; i++) result->data[off++] = _td_f2i(G2[i]);
    for (int i = 0; i < g3s; i++) result->data[off++] = _td_f2i(G3[i]);

    free(Xd); free(G1); free(G2); free(G3); free(remainder);
    free(U1); free(S1); free(Vt1);
    free(U2); free(S2); free(Vt2);
    return (long long)result;
}

// 6-arg shim — match the rod's declared arity. Pre-2026-05-05 the rod
// declared 6-arg `(X, n1, n2, n3, r1, r2)` but C took 5
// `(X, n1, n2, n3, max_rank)`. The rod's `r2` was silently dropped by
// Windows x64 calling convention, and the rod's `r1` was used as the
// single max_rank cap for both TT bond dimensions.
//
// The current 5-arg implementation uses one rank cap for both bonds
// (G1↔G2 and G2↔G3); future Phase B may refactor to true per-bond
// ranks. The shim collapses r1 and r2 to `max(r1, r2)` — the
// conservative cap that preserves enough singular values for either
// bond. Callers wanting the explicit one-cap form call
// `tdecomp_tt_svd_3d_max_rank`.
long long nuc_td_tt_svd_3d(long long X_h, long long n1, long long n2, long long n3,
                             long long r1, long long r2) {
    long long max_rank = r1 > r2 ? r1 : r2;
    return nuc_td_tt_svd_3d_max_rank(X_h, n1, n2, n3, max_rank);
}

// ================================================================
//  Kronecker Product: A ⊗ B
// ================================================================

long long nuc_td_kronecker(long long A_h, long long B_h,
                            long long Ar, long long Ac, long long Br, long long Bc) {
    TDVec *A = (TDVec *)(void *)A_h, *B = (TDVec *)(void *)B_h;
    int ar = (int)Ar, ac = (int)Ac, br = (int)Br, bc = (int)Bc;
    int cr = ar * br, cc = ac * bc;
    TDVec *C = tdvec_new(cr * cc);

    for (int ia = 0; ia < ar; ia++)
        for (int ja = 0; ja < ac; ja++)
            for (int ib = 0; ib < br; ib++)
                for (int jb = 0; jb < bc; jb++) {
                    double a = _td_i2f(A->data[ia * ac + ja]);
                    double b = _td_i2f(B->data[ib * bc + jb]);
                    C->data[(ia * br + ib) * cc + ja * bc + jb] = _td_f2i(a * b);
                }
    return (long long)C;
}

// ================================================================
//  Khatri-Rao Product (column-wise Kronecker): A ⊙ B
//  A: [I, R], B: [J, R] → C: [I*J, R]
// ================================================================

long long nuc_td_khatri_rao(long long A_h, long long B_h, long long I, long long J, long long R) {
    TDVec *A = (TDVec *)(void *)A_h, *B = (TDVec *)(void *)B_h;
    int ii = (int)I, jj = (int)J, rr = (int)R;
    TDVec *C = tdvec_new(ii * jj * rr);

    for (int r = 0; r < rr; r++)
        for (int i = 0; i < ii; i++)
            for (int j = 0; j < jj; j++)
                C->data[(i * jj + j) * rr + r] = _td_f2i(
                    _td_i2f(A->data[i * rr + r]) * _td_i2f(B->data[j * rr + r]));
    return (long long)C;
}
