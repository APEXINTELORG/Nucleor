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

// ================================================================
//  CP Decomposition (ALS — Alternating Least Squares)
//  Decomposes 3D tensor X[I,J,K] into sum of R rank-1 terms:
//  X ≈ sum_r a_r ⊗ b_r ⊗ c_r
//  Returns factors A[I,R], B[J,R], C[K,R] packed flat.
// ================================================================

long long nuc_td_cp_als(long long X_h, long long I, long long J, long long K, long long R, long long max_iter) {
    TDVec *X = (TDVec *)(void *)X_h;
    int ii = (int)I, jj = (int)J, kk = (int)K, rr = (int)R, mi = (int)max_iter;

    double *A = (double *)malloc(ii * rr * sizeof(double));
    double *B = (double *)malloc(jj * rr * sizeof(double));
    double *C = (double *)malloc(kk * rr * sizeof(double));

    // Random init
    unsigned int rng = 12345;
    for (int i = 0; i < ii * rr; i++) { rng = rng * 1103515245 + 12345; A[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }
    for (int i = 0; i < jj * rr; i++) { rng = rng * 1103515245 + 12345; B[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }
    for (int i = 0; i < kk * rr; i++) { rng = rng * 1103515245 + 12345; C[i] = ((double)((rng>>16)&0x7FFF))/32767.0 - 0.5; }

    double *Xd = (double *)malloc(ii * jj * kk * sizeof(double));
    for (int i = 0; i < ii * jj * kk && i < X->len; i++) Xd[i] = _td_i2f(X->data[i]);

    for (int iter = 0; iter < mi; iter++) {
        // Update A: solve X_(1) ≈ A * (C ⊙ B)^T
        // where ⊙ is Khatri-Rao product, X_(1) is mode-1 unfolding [I, J*K]
        double *BtB = (double *)calloc(rr * rr, sizeof(double));
        double *CtC = (double *)calloc(rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int j = 0; j < jj; j++) BtB[r1 * rr + r2] += B[j * rr + r1] * B[j * rr + r2];
                for (int k = 0; k < kk; k++) CtC[r1 * rr + r2] += C[k * rr + r1] * C[k * rr + r2];
            }
        // Hadamard product
        double *gram = (double *)malloc(rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = BtB[i] * CtC[i];

        // MTTKRP: V = X_(1) * (C ⊙ B) [I, R]
        double *V = (double *)calloc(ii * rr, sizeof(double));
        for (int i = 0; i < ii; i++)
            for (int j = 0; j < jj; j++)
                for (int k = 0; k < kk; k++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++)
                        V[i * rr + r] += xval * B[j * rr + r] * C[k * rr + r];
                }

        // A = V * gram^{-1} (simplified: use gram as diagonal approx)
        for (int i = 0; i < ii; i++)
            for (int r = 0; r < rr; r++)
                A[i * rr + r] = (fabs(gram[r * rr + r]) > 1e-15) ? V[i * rr + r] / gram[r * rr + r] : 0;

        free(BtB); free(CtC); free(gram); free(V);

        // Similar updates for B and C (symmetric structure)
        // Update B
        double *AtA = (double *)calloc(rr * rr, sizeof(double));
        CtC = (double *)calloc(rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int i = 0; i < ii; i++) AtA[r1 * rr + r2] += A[i * rr + r1] * A[i * rr + r2];
                for (int k = 0; k < kk; k++) CtC[r1 * rr + r2] += C[k * rr + r1] * C[k * rr + r2];
            }
        gram = (double *)malloc(rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = AtA[i] * CtC[i];
        V = (double *)calloc(jj * rr, sizeof(double));
        for (int j = 0; j < jj; j++)
            for (int i = 0; i < ii; i++)
                for (int k = 0; k < kk; k++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++) V[j * rr + r] += xval * A[i * rr + r] * C[k * rr + r];
                }
        for (int j = 0; j < jj; j++)
            for (int r = 0; r < rr; r++)
                B[j * rr + r] = (fabs(gram[r * rr + r]) > 1e-15) ? V[j * rr + r] / gram[r * rr + r] : 0;
        free(AtA); free(CtC); free(gram); free(V);

        // Update C
        AtA = (double *)calloc(rr * rr, sizeof(double));
        BtB = (double *)calloc(rr * rr, sizeof(double));
        for (int r1 = 0; r1 < rr; r1++)
            for (int r2 = 0; r2 < rr; r2++) {
                for (int i = 0; i < ii; i++) AtA[r1 * rr + r2] += A[i * rr + r1] * A[i * rr + r2];
                for (int j = 0; j < jj; j++) BtB[r1 * rr + r2] += B[j * rr + r1] * B[j * rr + r2];
            }
        gram = (double *)malloc(rr * rr * sizeof(double));
        for (int i = 0; i < rr * rr; i++) gram[i] = AtA[i] * BtB[i];
        V = (double *)calloc(kk * rr, sizeof(double));
        for (int k = 0; k < kk; k++)
            for (int i = 0; i < ii; i++)
                for (int j = 0; j < jj; j++) {
                    double xval = Xd[i * jj * kk + j * kk + k];
                    for (int r = 0; r < rr; r++) V[k * rr + r] += xval * A[i * rr + r] * B[j * rr + r];
                }
        for (int k = 0; k < kk; k++)
            for (int r = 0; r < rr; r++)
                C[k * rr + r] = (fabs(gram[r * rr + r]) > 1e-15) ? V[k * rr + r] / gram[r * rr + r] : 0;
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

long long nuc_td_tt_svd_3d_max_rank(long long X_h, long long n1, long long n2, long long n3,
                                      long long max_rank) {
    TDVec *X = (TDVec *)(void *)X_h;
    int d1 = (int)n1, d2 = (int)n2, d3 = (int)n3, mr = (int)max_rank;

    double *Xd = (double *)malloc(d1 * d2 * d3 * sizeof(double));
    for (int i = 0; i < d1 * d2 * d3 && i < X->len; i++) Xd[i] = _td_i2f(X->data[i]);

    // Reshape to [d1, d2*d3] and SVD
    int m = d1, n = d2 * d3;
    int r1 = m < n ? m : n;
    if (r1 > mr) r1 = mr;

    // Simple truncated SVD via Gram matrix
    // A^T A [m x m] if m < n
    double *G1 = (double *)calloc(d1 * r1, sizeof(double));
    double *remainder = (double *)calloc(r1 * d2 * d3, sizeof(double));

    // Crude SVD approximation: use first r1 left singular vectors via power iteration
    // For simplicity: just take first r1 rows as the "core" (proper impl would use SVD)
    for (int i = 0; i < d1; i++)
        for (int r = 0; r < r1; r++)
            G1[i * r1 + r] = (i == r) ? 1.0 : 0.0; // Identity start

    // remainder = G1^T @ X_reshape [r1, d2*d3]
    for (int r = 0; r < r1; r++)
        for (int j = 0; j < d2 * d3; j++) {
            double sum = 0;
            for (int i = 0; i < d1; i++) sum += G1[i * r1 + r] * Xd[i * (d2 * d3) + j];
            remainder[r * d2 * d3 + j] = sum;
        }

    // Reshape remainder to [r1*d2, d3] and repeat
    int r2 = r1 * d2 < d3 ? r1 * d2 : d3;
    if (r2 > mr) r2 = mr;

    double *G2 = (double *)calloc(r1 * d2 * r2, sizeof(double));
    double *G3 = (double *)calloc(r2 * d3, sizeof(double));

    // Simple: G2 = identity-like, G3 = remainder tail
    for (int i = 0; i < r1; i++)
        for (int j = 0; j < d2; j++)
            for (int r = 0; r < r2; r++)
                G2[i * d2 * r2 + j * r2 + r] = (i * d2 + j == r) ? 1.0 : 0.0;

    for (int r = 0; r < r2 && r < r1 * d2; r++)
        for (int k = 0; k < d3; k++)
            G3[r * d3 + k] = remainder[r * d3 + k]; // rough approximation

    // Pack: [r1, G1_size, G1..., r2, G2_size, G2..., G3_size, G3...]
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
