// mps_rt.c — Matrix Product State Tensor Network Simulator
// For S12b Section 11: scale to 20-50 qubits
//
// MPS representation: chain of rank-3 tensors A[i] of shape [bond_left, 2, bond_right]
// Gates applied via 2-site contraction + SVD truncation
// Compile: clang -c mps_rt.c -o target/mps_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _mi2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _mf2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

#define MPS_MAX_QUBITS 64
#define MPS_MAX_BOND 64   // max bond dimension (truncation limit)

typedef struct {
    int nq;
    int bond[MPS_MAX_QUBITS + 1]; // bond dimensions: bond[0]=1, bond[nq]=1
    // A[i] tensor: shape [bond[i], 2, bond[i+1]]
    // Stored as flat array: A[i][l][s][r] at index l*2*bond[i+1] + s*bond[i+1] + r
    double *A[MPS_MAX_QUBITS]; // real part
    double *A_im[MPS_MAX_QUBITS]; // imaginary part
    int max_bond;
    int step;
    long long last_swap_overhead;
    long long total_swap_overhead;
    int last_svd_converged;
    int last_svd_sweeps;
    double last_svd_off_norm;
    int last_svd_negative_clamps;
    long long total_svd_nonconverged;
    long long total_svd_negative_clamps;
} MPS;

typedef struct {
    long long *data;
    int len;
    int cap;
    long long inline_data[2];
} MPSVec;

static int mps_tensor_size(MPS *mps, int i) {
    return mps->bond[i] * 2 * mps->bond[i + 1];
}

static MPSVec *mps_vec_with_len(long long len) {
    if (len < 0 || len > 2147483647LL) return NULL;
    int cap = len < 2 ? 2 : (int)len;
    MPSVec *v = (MPSVec *)calloc(1, sizeof(MPSVec));
    if (!v) return NULL;
    v->len = (int)len;
    v->cap = cap;
    if (cap <= 2) {
        v->data = v->inline_data;
    } else {
        v->data = (long long *)calloc((size_t)cap, sizeof(long long));
        if (!v->data) { free(v); return NULL; }
    }
    return v;
}

static long long mps_complex_new(double re, double im) {
    long long *p = (long long *)malloc(2 * sizeof(long long));
    if (!p) return 0;
    p[0] = _mf2i(re);
    p[1] = _mf2i(im);
    return (long long)p;
}

long long nuc_mps_init(long long nq, long long max_bond) {
    MPS *mps = (MPS *)calloc(1, sizeof(MPS));
    mps->nq = (int)nq;
    mps->max_bond = (int)max_bond;
    if (mps->max_bond > MPS_MAX_BOND) mps->max_bond = MPS_MAX_BOND;
    mps->step = 0;
    mps->last_swap_overhead = 0;
    mps->total_swap_overhead = 0;
    mps->last_svd_converged = 1;
    mps->last_svd_sweeps = 0;
    mps->last_svd_off_norm = 0.0;
    mps->last_svd_negative_clamps = 0;
    mps->total_svd_nonconverged = 0;
    mps->total_svd_negative_clamps = 0;

    // Initialize to |00...0> state
    // Each tensor A[i] has bond[i]=1, bond[i+1]=1, shape [1,2,1]
    // A[i][0][0][0] = 1.0 (|0> component), A[i][0][1][0] = 0.0 (|1> component)
    for (int i = 0; i <= (int)nq; i++) mps->bond[i] = 1;
    for (int i = 0; i < (int)nq; i++) {
        int sz = mps_tensor_size(mps, i); // 1*2*1 = 2
        mps->A[i] = (double *)calloc(sz, sizeof(double));
        mps->A_im[i] = (double *)calloc(sz, sizeof(double));
        mps->A[i][0] = 1.0; // |0> amplitude = 1
        // A[i][1] = 0 already (|1> amplitude)
    }
    return (long long)mps;
}

// Apply single-qubit gate [2x2 matrix] to qubit q
// gate[0]=g00_re, gate[1]=g00_im, gate[2]=g01_re, gate[3]=g01_im,
// gate[4]=g10_re, gate[5]=g10_im, gate[6]=g11_re, gate[7]=g11_im
static void mps_apply_1q(MPS *mps, int q, double *gate) {
    int bl = mps->bond[q], br = mps->bond[q + 1];
    int sz = bl * 2 * br;
    double *new_re = (double *)calloc(sz, sizeof(double));
    double *new_im = (double *)calloc(sz, sizeof(double));

    for (int l = 0; l < bl; l++)
        for (int r = 0; r < br; r++)
            for (int s_out = 0; s_out < 2; s_out++) {
                double re = 0, im = 0;
                for (int s_in = 0; s_in < 2; s_in++) {
                    int gi = s_out * 4 + s_in * 2; // gate index
                    double g_re = gate[gi], g_im = gate[gi + 1];
                    int ai = l * 2 * br + s_in * br + r;
                    double a_re = mps->A[q][ai], a_im = mps->A_im[q][ai];
                    re += g_re * a_re - g_im * a_im;
                    im += g_re * a_im + g_im * a_re;
                }
                int oi = l * 2 * br + s_out * br + r;
                new_re[oi] = re;
                new_im[oi] = im;
            }

    free(mps->A[q]); free(mps->A_im[q]);
    mps->A[q] = new_re;
    mps->A_im[q] = new_im;
}

// SVD via Hermitian eigendecomposition of M^H * M (Jacobi method)
// For M[m x n]: compute A = M^H * M [n x n Hermitian], eigendecompose A = V * diag(s^2) * V^H,
// then S = sqrt(eigenvalues), U = M * V * diag(1/S)
// This is exact for the small matrices in MPS (typically 2-128 rows/cols)
static void simple_svd(double *M_re, double *M_im, int m, int n, int max_k,
                        double *U_re, double *U_im, double *S, double *Vt_re, double *Vt_im, int *k_out,
                        int *converged_out, int *sweeps_out, double *off_norm_out, int *negative_clamps_out) {
    int k = m < n ? m : n;
    if (k > max_k) k = max_k;
    int converged = 0;
    int sweeps = 0;
    double final_off_norm = 0.0;
    int negative_clamps = 0;

    // Step 1: Compute A = M^H * M [n x n], Hermitian positive semi-definite
    double *A_re = (double *)calloc(n * n, sizeof(double));
    double *A_im = (double *)calloc(n * n, sizeof(double));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double re = 0, im = 0;
            for (int l = 0; l < m; l++) {
                // M^H[i][l] = conj(M[l][i])
                double mhi_re = M_re[l * n + i], mhi_im = -M_im[l * n + i];
                double mj_re = M_re[l * n + j], mj_im = M_im[l * n + j];
                re += mhi_re * mj_re - mhi_im * mj_im;
                im += mhi_re * mj_im + mhi_im * mj_re;
            }
            A_re[i * n + j] = re;
            A_im[i * n + j] = im;
        }

    // Step 2: Jacobi eigendecomposition of Hermitian A
    // V starts as identity
    double *V_re = (double *)calloc(n * n, sizeof(double));
    double *V_im = (double *)calloc(n * n, sizeof(double));
    for (int i = 0; i < n; i++) V_re[i * n + i] = 1.0;

    // Jacobi sweeps: rotate off-diagonal elements to zero
    // Audit fix MED-LAYER9B-013 (2026-05-08): raised hard cap from 100
    // to 1000 sweeps. For ill-conditioned 2-site SVDs at high MPS bond
    // dimension (e.g., RZ on highly-entangled MPS near max bond), 100
    // sweeps was insufficient — the result was written with whatever
    // state the half-converged eigendecomposition held, and only the
    // observability surface (`mps_total_svd_nonconverged`) reflected
    // the failure. 1000 sweeps converges the typical ill-conditioned
    // case while still bounding worst-case wall time.
    for (int sweep = 0; sweep < 1000; sweep++) {
        double off_norm = 0;
        for (int i = 0; i < n; i++)
            for (int j = i + 1; j < n; j++)
                off_norm += A_re[i*n+j]*A_re[i*n+j] + A_im[i*n+j]*A_im[i*n+j];
        final_off_norm = off_norm;
        sweeps = sweep + 1;
        if (off_norm < 1e-28) { converged = 1; break; }

        for (int p = 0; p < n; p++)
            for (int q = p + 1; q < n; q++) {
                double apq_re = A_re[p*n+q], apq_im = A_im[p*n+q];
                double apq_abs = sqrt(apq_re*apq_re + apq_im*apq_im);
                if (apq_abs < 1e-15) continue;

                // For Hermitian matrix: A[p][q] = conj(A[q][p])
                // Phase factor to make A[p][q] real: e^{-i*phi} where phi = arg(A[p][q])
                double phase_re = apq_re / apq_abs, phase_im = -apq_im / apq_abs;

                // After phase rotation, the 2x2 subproblem is real symmetric:
                // [[app, apq_abs], [apq_abs, aqq]]
                double app = A_re[p*n+p], aqq = A_re[q*n+q];
                double tau = (aqq - app) / (2.0 * apq_abs);
                double t;
                if (tau >= 0) t = 1.0 / (tau + sqrt(1.0 + tau*tau));
                else          t = -1.0 / (-tau + sqrt(1.0 + tau*tau));
                double c = 1.0 / sqrt(1.0 + t*t);
                double s = t * c;

                // Givens rotation G: combines real Jacobi rotation with phase
                // G[p][p] = c, G[q][q] = c
                // G[p][q] = s * e^{i*phi}, G[q][p] = -s * e^{-i*phi}
                double g_pq_re = s * phase_re, g_pq_im = s * phase_im;
                double g_qp_re = -s * phase_re, g_qp_im = s * phase_im; // -conj(g_pq)

                // Update A: A' = G^H * A * G (update rows/cols p,q)
                // First: update columns p,q of A for all rows
                for (int i = 0; i < n; i++) {
                    double aip_re = A_re[i*n+p], aip_im = A_im[i*n+p];
                    double aiq_re = A_re[i*n+q], aiq_im = A_im[i*n+q];
                    // new A[i][p] = c*A[i][p] - conj(g_pq)*A[i][q]
                    // = c*A[i][p] - (s*phase_re - i*s*phase_im) * A[i][q]  [conj of g_pq]
                    double cg_re = s*phase_re, cg_im = -s*phase_im; // conj(g_pq)
                    A_re[i*n+p] = c*aip_re - (cg_re*aiq_re - cg_im*aiq_im);
                    A_im[i*n+p] = c*aip_im - (cg_re*aiq_im + cg_im*aiq_re);
                    // new A[i][q] = g_pq*A[i][p_old] + c*A[i][q]
                    A_re[i*n+q] = (g_pq_re*aip_re - g_pq_im*aip_im) + c*aiq_re;
                    A_im[i*n+q] = (g_pq_re*aip_im + g_pq_im*aip_re) + c*aiq_im;
                }
                // Then: update rows p,q of A for all columns
                for (int j = 0; j < n; j++) {
                    double apj_re = A_re[p*n+j], apj_im = A_im[p*n+j];
                    double aqj_re = A_re[q*n+j], aqj_im = A_im[q*n+j];
                    // new A[p][j] = c*A[p][j] - g_pq*A[q][j]
                    A_re[p*n+j] = c*apj_re - (g_pq_re*aqj_re - g_pq_im*aqj_im);
                    A_im[p*n+j] = c*apj_im - (g_pq_re*aqj_im + g_pq_im*aqj_re);
                    // new A[q][j] = conj(g_pq)*A[p][j_old] + c*A[q][j]
                    double cg2_re = s*phase_re, cg2_im = -s*phase_im;
                    A_re[q*n+j] = (cg2_re*apj_re - cg2_im*apj_im) + c*aqj_re;
                    A_im[q*n+j] = (cg2_re*apj_im + cg2_im*apj_re) + c*aqj_im;
                }
                // Enforce Hermitian: A[p][q] should now be ~0
                A_re[p*n+q] = 0; A_im[p*n+q] = 0;
                A_re[q*n+p] = 0; A_im[q*n+p] = 0;

                // Accumulate eigenvectors: V = V * G
                for (int i = 0; i < n; i++) {
                    double vip_re = V_re[i*n+p], vip_im = V_im[i*n+p];
                    double viq_re = V_re[i*n+q], viq_im = V_im[i*n+q];
                    V_re[i*n+p] = c*vip_re - (g_pq_re*viq_re + g_pq_im*viq_im);
                    V_im[i*n+p] = c*vip_im - (g_pq_re*viq_im - g_pq_im*viq_re);
                    V_re[i*n+q] = (s*phase_re*vip_re + s*phase_im*vip_im) + c*viq_re;
                    V_im[i*n+q] = (s*phase_re*vip_im - s*phase_im*vip_re) + c*viq_im;
                }
            }
    }

    // Step 3: Extract eigenvalues (diagonal of A) and sort descending
    double *eig = (double *)calloc(n, sizeof(double));
    int *idx = (int *)calloc(n, sizeof(int));
    for (int i = 0; i < n; i++) {
        if (A_re[i*n+i] < 0.0) negative_clamps++;
        eig[i] = A_re[i*n+i] > 0 ? A_re[i*n+i] : 0; // clamp negative eigenvalues
        idx[i] = i;
    }
    // Selection sort descending
    for (int i = 0; i < n - 1; i++) {
        int best = i;
        for (int j = i + 1; j < n; j++)
            if (eig[idx[j]] > eig[idx[best]]) best = j;
        if (best != i) { int tmp = idx[i]; idx[i] = idx[best]; idx[best] = tmp; }
    }

    // Step 4: Fill S (singular values = sqrt of eigenvalues), V†, and U
    int actual_k = 0;
    for (int j = 0; j < k; j++) {
        double sv = sqrt(eig[idx[j]]);
        if (sv < 1e-12) break; // truncate negligible singular values
        S[j] = sv;
        // Vt[j][:] = conj(V[:, idx[j]])^T — j-th row of Vt is conjugate of idx[j]-th column of V
        for (int i = 0; i < n; i++) {
            Vt_re[j * n + i] = V_re[i * n + idx[j]];
            Vt_im[j * n + i] = -V_im[i * n + idx[j]]; // conjugate transpose
        }
        // U[:, j] = M * V[:, idx[j]] / S[j]
        for (int i = 0; i < m; i++) {
            double re = 0, im = 0;
            for (int l = 0; l < n; l++) {
                re += M_re[i*n+l] * V_re[l*n+idx[j]] - M_im[i*n+l] * V_im[l*n+idx[j]];
                im += M_re[i*n+l] * V_im[l*n+idx[j]] + M_im[i*n+l] * V_re[l*n+idx[j]];
            }
            U_re[i * k + j] = re / sv;
            U_im[i * k + j] = im / sv;
        }
        actual_k = j + 1;
    }
    if (actual_k == 0) actual_k = 1; // keep at least 1
    *k_out = actual_k;

    // Zero out unused entries
    for (int j = actual_k; j < k; j++) {
        S[j] = 0;
        for (int i = 0; i < n; i++) { Vt_re[j*n+i] = 0; Vt_im[j*n+i] = 0; }
        for (int i = 0; i < m; i++) { U_re[i*k+j] = 0; U_im[i*k+j] = 0; }
    }

    if (converged_out) *converged_out = converged;
    if (sweeps_out) *sweeps_out = sweeps;
    if (off_norm_out) *off_norm_out = final_off_norm;
    if (negative_clamps_out) *negative_clamps_out = negative_clamps;

    free(A_re); free(A_im); free(V_re); free(V_im); free(eig); free(idx);
}

// Apply two-qubit gate to adjacent qubits (q, q+1)
// Contracts A[q] and A[q+1], applies gate, SVD splits back
void nuc_mps_gate_2q(long long handle, long long q_val, double *gate_4x4_re, double *gate_4x4_im) {
    MPS *mps = (MPS *)(void *)handle;
    int q = (int)q_val;
    if (q < 0 || q >= mps->nq - 1) return;

    int bl = mps->bond[q];      // left bond of qubit q
    int bm = mps->bond[q + 1];  // middle bond
    int br = mps->bond[q + 2];  // right bond of qubit q+1

    // Contract: theta[l, s0, s1, r] = sum_m A[q][l,s0,m] * A[q+1][m,s1,r]
    // Shape: bl * 4 * br (s0s1 combined as 0-3)
    int theta_size = bl * 4 * br;
    double *theta_re = (double *)calloc(theta_size, sizeof(double));
    double *theta_im = (double *)calloc(theta_size, sizeof(double));

    for (int l = 0; l < bl; l++)
        for (int s0 = 0; s0 < 2; s0++)
            for (int s1 = 0; s1 < 2; s1++)
                for (int r = 0; r < br; r++) {
                    double re = 0, im = 0;
                    for (int m = 0; m < bm; m++) {
                        int ai = l * 2 * bm + s0 * bm + m;
                        int bi = m * 2 * br + s1 * br + r;
                        double a_re = mps->A[q][ai], a_im = mps->A_im[q][ai];
                        double b_re = mps->A[q+1][bi], b_im = mps->A_im[q+1][bi];
                        re += a_re * b_re - a_im * b_im;
                        im += a_re * b_im + a_im * b_re;
                    }
                    int ss = s0 * 2 + s1;
                    theta_re[l * 4 * br + ss * br + r] = re;
                    theta_im[l * 4 * br + ss * br + r] = im;
                }

    // Apply gate: theta'[l, s0', s1', r] = sum_{s0,s1} gate[s0's1', s0s1] * theta[l, s0, s1, r]
    double *theta2_re = (double *)calloc(theta_size, sizeof(double));
    double *theta2_im = (double *)calloc(theta_size, sizeof(double));
    for (int l = 0; l < bl; l++)
        for (int r = 0; r < br; r++)
            for (int ss_out = 0; ss_out < 4; ss_out++)
                for (int ss_in = 0; ss_in < 4; ss_in++) {
                    int gi = ss_out * 8 + ss_in * 2;
                    double g_re = gate_4x4_re[ss_out * 4 + ss_in];
                    double g_im = gate_4x4_im[ss_out * 4 + ss_in];
                    double t_re = theta_re[l * 4 * br + ss_in * br + r];
                    double t_im = theta_im[l * 4 * br + ss_in * br + r];
                    theta2_re[l * 4 * br + ss_out * br + r] += g_re * t_re - g_im * t_im;
                    theta2_im[l * 4 * br + ss_out * br + r] += g_re * t_im + g_im * t_re;
                }

    // Reshape theta2 to matrix M[bl*2, 2*br] for SVD
    int M_rows = bl * 2, M_cols = 2 * br;
    double *M_re = (double *)calloc(M_rows * M_cols, sizeof(double));
    double *M_im = (double *)calloc(M_rows * M_cols, sizeof(double));
    for (int l = 0; l < bl; l++)
        for (int s0 = 0; s0 < 2; s0++)
            for (int s1 = 0; s1 < 2; s1++)
                for (int r = 0; r < br; r++) {
                    int row = l * 2 + s0;
                    int col = s1 * br + r;
                    int ss = s0 * 2 + s1;
                    M_re[row * M_cols + col] = theta2_re[l * 4 * br + ss * br + r];
                    M_im[row * M_cols + col] = theta2_im[l * 4 * br + ss * br + r];
                }

    // SVD: M = U * S * Vt
    int new_bond;
    double *U_re = (double *)calloc(M_rows * mps->max_bond, sizeof(double));
    double *U_im = (double *)calloc(M_rows * mps->max_bond, sizeof(double));
    double *S = (double *)calloc(mps->max_bond, sizeof(double));
    double *Vt_re = (double *)calloc(mps->max_bond * M_cols, sizeof(double));
    double *Vt_im = (double *)calloc(mps->max_bond * M_cols, sizeof(double));

    int svd_converged = 0;
    int svd_sweeps = 0;
    double svd_off_norm = 0.0;
    int svd_negative_clamps = 0;
    simple_svd(M_re, M_im, M_rows, M_cols, mps->max_bond, U_re, U_im, S, Vt_re, Vt_im, &new_bond,
               &svd_converged, &svd_sweeps, &svd_off_norm, &svd_negative_clamps);
    mps->last_svd_converged = svd_converged;
    mps->last_svd_sweeps = svd_sweeps;
    mps->last_svd_off_norm = svd_off_norm;
    mps->last_svd_negative_clamps = svd_negative_clamps;
    if (!svd_converged) mps->total_svd_nonconverged++;
    mps->total_svd_negative_clamps += svd_negative_clamps;

    // Truncate: keep only singular values above threshold
    double thresh = 1e-10;
    int kept = 0;
    for (int i = 0; i < new_bond; i++)
        if (S[i] > thresh) kept++;
    if (kept == 0) kept = 1;
    new_bond = kept;

    // Update bond dimension
    mps->bond[q + 1] = new_bond;

    // Rebuild A[q] from U*S: A[q][l,s,r'] = U[l*2+s, r'] * S[r']
    free(mps->A[q]); free(mps->A_im[q]);
    int sz_q = bl * 2 * new_bond;
    mps->A[q] = (double *)calloc(sz_q, sizeof(double));
    mps->A_im[q] = (double *)calloc(sz_q, sizeof(double));
    for (int l = 0; l < bl; l++)
        for (int s = 0; s < 2; s++)
            for (int r = 0; r < new_bond; r++) {
                int row = l * 2 + s;
                mps->A[q][l * 2 * new_bond + s * new_bond + r] = U_re[row * kept + r] * S[r];
                mps->A_im[q][l * 2 * new_bond + s * new_bond + r] = U_im[row * kept + r] * S[r];
            }

    // Rebuild A[q+1] from Vt: A[q+1][l',s,r] = Vt[l', s*br+r]
    free(mps->A[q+1]); free(mps->A_im[q+1]);
    int sz_q1 = new_bond * 2 * br;
    mps->A[q+1] = (double *)calloc(sz_q1, sizeof(double));
    mps->A_im[q+1] = (double *)calloc(sz_q1, sizeof(double));
    for (int l = 0; l < new_bond; l++)
        for (int s = 0; s < 2; s++)
            for (int r = 0; r < br; r++) {
                int col = s * br + r;
                mps->A[q+1][l * 2 * br + s * br + r] = Vt_re[l * M_cols + col];
                mps->A_im[q+1][l * 2 * br + s * br + r] = Vt_im[l * M_cols + col];
            }

    free(theta_re); free(theta_im); free(theta2_re); free(theta2_im);
    free(M_re); free(M_im); free(U_re); free(U_im); free(S); free(Vt_re); free(Vt_im);
    mps->step++;
}

// High-level gate API matching diff_sim
// gate_type: 0=H, 1=CNOT, 2=X, 3=Z, 4=RZ
void nuc_mps_gate(long long handle, long long gate_type, long long q0, long long q1, long long angle_bits) {
    MPS *mps = (MPS *)(void *)handle;
    int gt = (int)gate_type;
    double angle = _mi2f(angle_bits);
    long long swap_overhead = 0;
    if (!mps) return;
    mps->last_swap_overhead = 0;

    if (gt == 0) { // H
        double g[8] = {0.7071067811865476, 0, 0.7071067811865476, 0,
                       0.7071067811865476, 0, -0.7071067811865476, 0};
        mps_apply_1q(mps, (int)q0, g);
    } else if (gt == 2) { // X
        double g[8] = {0,0, 1,0, 1,0, 0,0};
        mps_apply_1q(mps, (int)q0, g);
    } else if (gt == 3) { // Z
        double g[8] = {1,0, 0,0, 0,0, -1,0};
        mps_apply_1q(mps, (int)q0, g);
    } else if (gt == 4) { // RZ: [[e^{-iθ/2}, 0], [0, e^{iθ/2}]]
        double half = angle * 0.5;
        double g[8] = {cos(half), -sin(half), 0, 0, 0, 0, cos(half), sin(half)};
        mps_apply_1q(mps, (int)q0, g);
    } else if (gt == 5) { // RX: [[cos(θ/2), -i*sin(θ/2)], [-i*sin(θ/2), cos(θ/2)]]
        double half = angle * 0.5;
        double g[8] = {cos(half), 0, 0, -sin(half), 0, -sin(half), cos(half), 0};
        mps_apply_1q(mps, (int)q0, g);
    } else if (gt == 1) { // CNOT — with SWAP decomposition for non-adjacent
        double cnot_re[16] = {1,0,0,0, 0,1,0,0, 0,0,0,1, 0,0,1,0};
        double cnot_im[16] = {0};
        // SWAP = CNOT(a,b) CNOT(b,a) CNOT(a,b) — only for adjacent
        double swap_re[16] = {1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,0,1};
        double swap_im[16] = {0};

        int qa = (int)q0, qb = (int)q1;
        if (qa < 0 || qb < 0 || qa >= mps->nq || qb >= mps->nq || qa == qb) {
            // invalid — skip
        } else if (abs(qb - qa) == 1) {
            // Adjacent — direct CNOT
            int qq = qa < qb ? qa : qb;
            nuc_mps_gate_2q(handle, qq, cnot_re, cnot_im);
        } else {
            // Non-adjacent: SWAP qb next to qa, apply CNOT, SWAP back
            // Move qb toward qa one step at a time
            int target_pos = (qb > qa) ? qa + 1 : qa - 1;
            int cur = qb;

            // SWAP chain: move cur toward target_pos
            if (cur > target_pos) {
                for (int i = cur; i > target_pos; i--) {
                    nuc_mps_gate_2q(handle, i - 1, swap_re, swap_im);
                    swap_overhead++;
                }
            } else {
                for (int i = cur; i < target_pos; i++) {
                    nuc_mps_gate_2q(handle, i, swap_re, swap_im);
                    swap_overhead++;
                }
            }

            // Now qb is at target_pos (adjacent to qa). Apply CNOT.
            int qq = qa < target_pos ? qa : target_pos;
            nuc_mps_gate_2q(handle, qq, cnot_re, cnot_im);

            // SWAP back
            if (cur > target_pos) {
                for (int i = target_pos; i < cur; i++) {
                    nuc_mps_gate_2q(handle, i, swap_re, swap_im);
                    swap_overhead++;
                }
            } else {
                for (int i = target_pos; i > cur; i--) {
                    nuc_mps_gate_2q(handle, i - 1, swap_re, swap_im);
                    swap_overhead++;
                }
            }
        }
        mps->last_swap_overhead = swap_overhead;
        mps->total_swap_overhead += swap_overhead;
    } else if (gt == 6) { // XX+YY rotation: e^{-i*angle*(XX+YY)/2}
        // 4x4 matrix in computational basis {|00>, |01>, |10>, |11>}:
        // |00> → |00>,  |11> → |11>  (unchanged)
        // |01> → cos(angle/2)|01> - i*sin(angle/2)|10>
        // |10> → -i*sin(angle/2)|01> + cos(angle/2)|10>
        double h = angle * 0.5;
        double ca = cos(h), sa = sin(h);
        double xxyy_re[16] = {1,0,0,0, 0,ca,0,0, 0,0,ca,0, 0,0,0,1};
        double xxyy_im[16] = {0,0,0,0, 0,0,-sa,0, 0,-sa,0,0, 0,0,0,0};
        int qa = (int)q0;
        if (qa >= 0 && qa < mps->nq - 1)
            nuc_mps_gate_2q(handle, qa, xxyy_re, xxyy_im);
    } else if (gt == 7) { // ZZ rotation: e^{-i*angle*ZZ/2}
        // |00> → e^{-i*angle/2}|00>,  |01> → e^{+i*angle/2}|01>
        // |10> → e^{+i*angle/2}|10>,  |11> → e^{-i*angle/2}|11>
        double h = angle * 0.5;
        double ca = cos(h), sa = sin(h);
        double zz_re[16] = {ca,0,0,0, 0,ca,0,0, 0,0,ca,0, 0,0,0,ca};
        double zz_im[16] = {-sa,0,0,0, 0,sa,0,0, 0,0,sa,0, 0,0,0,-sa};
        int qa = (int)q0;
        if (qa >= 0 && qa < mps->nq - 1)
            nuc_mps_gate_2q(handle, qa, zz_re, zz_im);
    }
    mps->step++;
}

long long nuc_mps_last_swap_overhead(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->last_swap_overhead;
}

long long nuc_mps_total_swap_overhead(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->total_swap_overhead;
}

long long nuc_mps_cnot_swap_overhead(long long nq, long long q0, long long q1) {
    if (nq <= 0 || q0 < 0 || q1 < 0 || q0 >= nq || q1 >= nq || q0 == q1) return -1;
    long long d = q0 > q1 ? q0 - q1 : q1 - q0;
    if (d <= 1) return 0;
    return 2 * (d - 1);
}

long long nuc_mps_last_svd_converged(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->last_svd_converged ? 1 : 0;
}

long long nuc_mps_last_svd_sweeps(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->last_svd_sweeps;
}

long long nuc_mps_last_svd_off_norm(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return _mf2i(0.0);
    return _mf2i(mps->last_svd_off_norm);
}

long long nuc_mps_last_svd_negative_clamps(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->last_svd_negative_clamps;
}

long long nuc_mps_total_svd_nonconverged(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->total_svd_nonconverged;
}

long long nuc_mps_total_svd_negative_clamps(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return 0;
    return mps->total_svd_negative_clamps;
}

// Extract features: max bond dimension, mean entropy
long long nuc_mps_extract(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

    // Max bond dimension
    int max_b = 0;
    for (int i = 0; i <= mps->nq; i++)
        if (mps->bond[i] > max_b) max_b = mps->bond[i];

    // Mean entanglement entropy across bipartitions
    // For each cut between qubit i and i+1, entropy = -sum(s^2 * log2(s^2))
    // where s are the singular values = sqrt of Schmidt coefficients
    double mean_ent = 0;
    for (int cut = 1; cut < mps->nq; cut++) {
        int b = mps->bond[cut];
        // Approximate: entropy ~ log2(bond_dim) for maximally entangled
        // Better: compute actual Schmidt values from the MPS
        // For now use the approximation
        if (b > 1) mean_ent += log2((double)b);
    }
    if (mps->nq > 1) mean_ent /= (mps->nq - 1);

    NVec *feats = (NVec *)malloc(sizeof(NVec));
    feats->cap = 8; feats->len = 0;
    feats->data = (long long *)malloc(feats->cap * sizeof(long long));

    #define MPF(v, val) do { double _v=(val); long long _i; memcpy(&_i,&_v,sizeof(double)); \
        (v)->data[(v)->len++] = _i; } while(0)

    MPF(feats, (double)max_b);        // [0] max bond dimension
    MPF(feats, mean_ent);             // [1] mean entanglement entropy
    MPF(feats, (double)mps->nq);      // [2] n_qubits
    MPF(feats, (double)mps->step);    // [3] n_steps

    #undef MPF
    return (long long)feats;
}

void nuc_mps_free(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps) return;
    for (int i = 0; i < mps->nq; i++) {
        if (mps->A[i]) free(mps->A[i]);
        if (mps->A_im[i]) free(mps->A_im[i]);
    }
    free(mps);
}

long long nuc_mps_max_bond(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    int max_b = 0;
    for (int i = 0; i <= mps->nq; i++)
        if (mps->bond[i] > max_b) max_b = mps->bond[i];
    return max_b;
}

// Compute <Z_q> = <psi|Z_q|psi> for a single qubit q.
// Z|0> = +|0>, Z|1> = -|1>, so <Z> = prob(0) - prob(1).
// Uses left-to-right contraction of transfer matrices.
// Returns f64 (bitcast to i64).
long long nuc_mps_expect_z(long long handle, long long q_val) {
    MPS *mps = (MPS *)(void *)handle;
    int q = (int)q_val;
    int n = mps->nq;
    if (q < 0 || q >= n) { double z = 0.0; long long r; memcpy(&r, &z, 8); return r; }

    // Contract from left: env_re[l][l'] + i*env_im[l][l']
    // Start with identity: env[0][0] = 1
    int max_b = mps->max_bond > MPS_MAX_BOND ? MPS_MAX_BOND : mps->max_bond;
    double *env_re = (double *)calloc(max_b * max_b, sizeof(double));
    double *env_im = (double *)calloc(max_b * max_b, sizeof(double));
    double *tmp_re = (double *)calloc(max_b * max_b, sizeof(double));
    double *tmp_im = (double *)calloc(max_b * max_b, sizeof(double));
    env_re[0] = 1.0; // bond[0]=1, so env is 1x1

    for (int i = 0; i < n; i++) {
        int bl = mps->bond[i];
        int br = mps->bond[i + 1];
        memset(tmp_re, 0, br * br * sizeof(double));
        memset(tmp_im, 0, br * br * sizeof(double));

        // For each physical index s (0 or 1):
        // op_val = (i == q) ? (s == 0 ? +1.0 : -1.0) : 1.0
        for (int s = 0; s < 2; s++) {
            double op = 1.0;
            if (i == q) op = (s == 0) ? 1.0 : -1.0;

            // tmp[r1][r2] += sum_{l1,l2} env[l1][l2] * conj(A[l1,s,r1]) * op * A[l2,s,r2]
            for (int l1 = 0; l1 < bl; l1++) {
                for (int l2 = 0; l2 < bl; l2++) {
                    double e_re = env_re[l1 * bl + l2];
                    double e_im = env_im[l1 * bl + l2];
                    if (e_re == 0.0 && e_im == 0.0) continue;

                    for (int r1 = 0; r1 < br; r1++) {
                        int idx1 = l1 * 2 * br + s * br + r1;
                        double a1_re = mps->A[i][idx1];
                        double a1_im = mps->A_im[i][idx1];
                        // conj(A1) = a1_re - i*a1_im
                        double ca1_re = a1_re;
                        double ca1_im = -a1_im;
                        // e * conj(A1) * op
                        double ec_re = (e_re * ca1_re - e_im * ca1_im) * op;
                        double ec_im = (e_re * ca1_im + e_im * ca1_re) * op;

                        for (int r2 = 0; r2 < br; r2++) {
                            int idx2 = l2 * 2 * br + s * br + r2;
                            double a2_re = mps->A[i][idx2];
                            double a2_im = mps->A_im[i][idx2];
                            // ec * A2
                            tmp_re[r1 * br + r2] += ec_re * a2_re - ec_im * a2_im;
                            tmp_im[r1 * br + r2] += ec_re * a2_im + ec_im * a2_re;
                        }
                    }
                }
            }
        }
        // Swap env <-> tmp
        double *sw;
        sw = env_re; env_re = tmp_re; tmp_re = sw;
        sw = env_im; env_im = tmp_im; tmp_im = sw;
    }

    // Final: env is 1x1 (bond[n]=1), result is env[0][0]
    double result = env_re[0];
    free(env_re); free(env_im); free(tmp_re); free(tmp_im);
    long long r; memcpy(&r, &result, 8); return r;
}

long long nuc_mps_prob0(long long handle, long long q_val) {
    long long z_bits = nuc_mps_expect_z(handle, q_val);
    double z;
    memcpy(&z, &z_bits, sizeof(double));
    double p0 = 0.5 * (1.0 + z);
    if (p0 < 0.0) p0 = 0.0;
    if (p0 > 1.0) p0 = 1.0;
    long long r;
    memcpy(&r, &p0, sizeof(double));
    return r;
}

static int mps_basis_amplitude(MPS *mps, unsigned long long bits,
                               double *vec_re, double *vec_im,
                               double *next_re, double *next_im,
                               double *out_re, double *out_im) {
    if (!mps || !vec_re || !vec_im || !next_re || !next_im || !out_re || !out_im) return 0;
    int n = mps->nq;
    if (n < 0 || n > 64) return 0;
    if (n < 64 && (bits >> n) != 0ULL) return 0;

    memset(vec_re, 0, MPS_MAX_BOND * sizeof(double));
    memset(vec_im, 0, MPS_MAX_BOND * sizeof(double));
    memset(next_re, 0, MPS_MAX_BOND * sizeof(double));
    memset(next_im, 0, MPS_MAX_BOND * sizeof(double));
    vec_re[0] = 1.0;

    for (int i = 0; i < n; i++) {
        int bl = mps->bond[i];
        int br = mps->bond[i + 1];
        if (bl < 1 || br < 1 || bl > MPS_MAX_BOND || br > MPS_MAX_BOND) return 0;

        memset(next_re, 0, (size_t)br * sizeof(double));
        memset(next_im, 0, (size_t)br * sizeof(double));

        int s = (int)((bits >> i) & 1ULL);
        for (int l = 0; l < bl; l++) {
            double v_re = vec_re[l];
            double v_im = vec_im[l];
            if (v_re == 0.0 && v_im == 0.0) continue;

            for (int r = 0; r < br; r++) {
                int ai = l * 2 * br + s * br + r;
                double a_re = mps->A[i][ai];
                double a_im = mps->A_im[i][ai];
                next_re[r] += v_re * a_re - v_im * a_im;
                next_im[r] += v_re * a_im + v_im * a_re;
            }
        }

        double *sw;
        sw = vec_re; vec_re = next_re; next_re = sw;
        sw = vec_im; vec_im = next_im; next_im = sw;
    }

    *out_re = vec_re[0];
    *out_im = vec_im[0];
    return 1;
}

// Return the joint probability for one computational-basis state.
// `basis_bits` uses the same little-endian qubit convention as qsim:
// bit q is the requested measured value for qubit q.
long long nuc_mps_prob_basis(long long handle, long long basis_bits) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps || mps->nq < 0 || mps->nq > 64 || basis_bits < 0) return _mf2i(0.0);

    int n = mps->nq;
    unsigned long long bits = (unsigned long long)basis_bits;
    if (n < 64 && (bits >> n) != 0ULL) return _mf2i(0.0);

    double *vec_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *vec_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    if (!vec_re || !vec_im || !next_re || !next_im) {
        free(vec_re); free(vec_im); free(next_re); free(next_im);
        return _mf2i(0.0);
    }

    double amp_re = 0.0;
    double amp_im = 0.0;
    int ok = mps_basis_amplitude(mps, bits, vec_re, vec_im, next_re, next_im, &amp_re, &amp_im);
    if (!ok) { free(vec_re); free(vec_im); free(next_re); free(next_im); return _mf2i(0.0); }

    double prob = amp_re * amp_re + amp_im * amp_im;
    if (prob < 1e-15) prob = 0.0;
    if (prob > 1.0 && prob < 1.0 + 1e-9) prob = 1.0;

    free(vec_re); free(vec_im); free(next_re); free(next_im);
    return _mf2i(prob);
}

long long nuc_mps_statevector_max_qubits(void) {
    return 16;
}

long long nuc_mps_statevector_range_max_count(void) {
    return 4096;
}

// Materialize a bounded basis-state range without constructing the full 2^n
// statevector. This keeps high-qubit MPS readout usable for focused probes
// while preserving the full-state extraction cap above.
long long nuc_mps_statevector_range(long long handle, long long start_basis_, long long count_) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps || mps->nq < 0 || mps->nq > 62) return 0;
    if (start_basis_ < 0 || count_ < 0) return 0;
    if (count_ > nuc_mps_statevector_range_max_count()) return 0;

    unsigned long long start_basis = (unsigned long long)start_basis_;
    unsigned long long count = (unsigned long long)count_;
    unsigned long long total = 1ULL << mps->nq;
    if (start_basis > total) return 0;
    if (count > total - start_basis) return 0;

    MPSVec *out = mps_vec_with_len((long long)count);
    if (!out) return 0;

    double *vec_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *vec_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    if (!vec_re || !vec_im || !next_re || !next_im) {
        if (out->data && out->data != out->inline_data) free(out->data);
        free(out);
        free(vec_re); free(vec_im); free(next_re); free(next_im);
        return 0;
    }

    for (unsigned long long i = 0; i < count; i++) {
        double amp_re = 0.0;
        double amp_im = 0.0;
        int ok = mps_basis_amplitude(mps, start_basis + i,
                                     vec_re, vec_im, next_re, next_im,
                                     &amp_re, &amp_im);
        if (!ok) {
            for (unsigned long long j = 0; j < i; j++) free((void *)(size_t)out->data[j]);
            if (out->data && out->data != out->inline_data) free(out->data);
            free(out);
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return 0;
        }
        if (amp_re > -1e-15 && amp_re < 1e-15) amp_re = 0.0;
        if (amp_im > -1e-15 && amp_im < 1e-15) amp_im = 0.0;
        out->data[i] = mps_complex_new(amp_re, amp_im);
        if (out->data[i] == 0) {
            for (unsigned long long j = 0; j < i; j++) free((void *)(size_t)out->data[j]);
            if (out->data && out->data != out->inline_data) free(out->data);
            free(out);
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return 0;
        }
    }

    free(vec_re); free(vec_im); free(next_re); free(next_im);
    return (long long)out;
}

// =====================================================
// QM-6 Phase 2e bounded streaming-range folds (v0842)
// =====================================================
//
// These fold a basis-range scan into a single scalar without
// materializing the per-amplitude Vec<complex>. Memory stays
// O(MPS_MAX_BOND) regardless of `count`. The fold cap is higher
// than the materializing cap because there is no per-state
// allocation; only the bounded amplitude scratch buffers + a
// single accumulator. Real callback-style streaming (per-state
// user callbacks across the FFI boundary) remains future work
// per QM-6 Phase 2f.

#define MPS_RANGE_FOLD_MAX_COUNT (1LL << 20) // 1,048,576

long long nuc_mps_statevector_range_max_fold_count(void) {
    return MPS_RANGE_FOLD_MAX_COUNT;
}

// Sum of |amp|^2 over [start_basis, start_basis + count). Returns
// _mf2i(prob_sum) on success (prob_sum in [0.0, 1.0]). On invalid
// handle / out-of-range / over-cap inputs returns _mf2i(-1.0); a
// valid empty range (count == 0) returns _mf2i(0.0). The same
// 1e-15 zero-clamp used by nuc_mps_statevector_range is applied to
// the per-state amplitude before squaring, so the fold value is
// numerically consistent with a fold over the materialized vec.
long long nuc_mps_statevector_range_prob_sum(long long handle,
                                             long long start_basis_,
                                             long long count_) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps || mps->nq < 0 || mps->nq > 62) return _mf2i(-1.0);
    if (start_basis_ < 0 || count_ < 0) return _mf2i(-1.0);
    if (count_ > MPS_RANGE_FOLD_MAX_COUNT) return _mf2i(-1.0);

    unsigned long long start_basis = (unsigned long long)start_basis_;
    unsigned long long count = (unsigned long long)count_;
    unsigned long long total = 1ULL << mps->nq;
    if (start_basis > total) return _mf2i(-1.0);
    if (count > total - start_basis) return _mf2i(-1.0);
    if (count == 0) return _mf2i(0.0);

    double *vec_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *vec_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    if (!vec_re || !vec_im || !next_re || !next_im) {
        free(vec_re); free(vec_im); free(next_re); free(next_im);
        return _mf2i(-1.0);
    }

    double sum = 0.0;
    for (unsigned long long i = 0; i < count; i++) {
        double amp_re = 0.0;
        double amp_im = 0.0;
        int ok = mps_basis_amplitude(mps, start_basis + i,
                                     vec_re, vec_im, next_re, next_im,
                                     &amp_re, &amp_im);
        if (!ok) {
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return _mf2i(-1.0);
        }
        if (amp_re > -1e-15 && amp_re < 1e-15) amp_re = 0.0;
        if (amp_im > -1e-15 && amp_im < 1e-15) amp_im = 0.0;
        sum += amp_re * amp_re + amp_im * amp_im;
    }

    free(vec_re); free(vec_im); free(next_re); free(next_im);
    if (sum > 1.0 && sum < 1.0 + 1e-9) sum = 1.0;
    return _mf2i(sum);
}

// Count of basis states in [start_basis, start_basis + count) whose
// |amp|^2 exceeds the same 1e-15 zero-clamp threshold the
// materializing range path applies. Returns -1 on invalid handle /
// out-of-range / over-cap inputs and 0..count on success. A valid
// empty range returns 0.
long long nuc_mps_statevector_range_nonzero_count(long long handle,
                                                  long long start_basis_,
                                                  long long count_) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps || mps->nq < 0 || mps->nq > 62) return -1;
    if (start_basis_ < 0 || count_ < 0) return -1;
    if (count_ > MPS_RANGE_FOLD_MAX_COUNT) return -1;

    unsigned long long start_basis = (unsigned long long)start_basis_;
    unsigned long long count = (unsigned long long)count_;
    unsigned long long total = 1ULL << mps->nq;
    if (start_basis > total) return -1;
    if (count > total - start_basis) return -1;
    if (count == 0) return 0;

    double *vec_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *vec_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    if (!vec_re || !vec_im || !next_re || !next_im) {
        free(vec_re); free(vec_im); free(next_re); free(next_im);
        return -1;
    }

    long long nonzero = 0;
    for (unsigned long long i = 0; i < count; i++) {
        double amp_re = 0.0;
        double amp_im = 0.0;
        int ok = mps_basis_amplitude(mps, start_basis + i,
                                     vec_re, vec_im, next_re, next_im,
                                     &amp_re, &amp_im);
        if (!ok) {
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return -1;
        }
        if (amp_re > -1e-15 && amp_re < 1e-15) amp_re = 0.0;
        if (amp_im > -1e-15 && amp_im < 1e-15) amp_im = 0.0;
        double prob = amp_re * amp_re + amp_im * amp_im;
        if (prob > 1e-15) nonzero++;
    }

    free(vec_re); free(vec_im); free(next_re); free(next_im);
    return nonzero;
}

// Materialize a qsim-compatible Vec<complex> statevector for small MPS states.
// This is intentionally capped: MPS is useful because it avoids 2^n storage,
// so large-state extraction must fail closed instead of becoming a memory footgun.
long long nuc_mps_statevector(long long handle) {
    MPS *mps = (MPS *)(void *)handle;
    if (!mps || mps->nq < 0 || mps->nq > nuc_mps_statevector_max_qubits()) return 0;

    long long size = 1LL << mps->nq;
    MPSVec *out = mps_vec_with_len(size);
    if (!out) return 0;

    double *vec_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *vec_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_re = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    double *next_im = (double *)calloc(MPS_MAX_BOND, sizeof(double));
    if (!vec_re || !vec_im || !next_re || !next_im) {
        if (out->data && out->data != out->inline_data) free(out->data);
        free(out);
        free(vec_re); free(vec_im); free(next_re); free(next_im);
        return 0;
    }

    for (long long basis = 0; basis < size; basis++) {
        double amp_re = 0.0;
        double amp_im = 0.0;
        int ok = mps_basis_amplitude(mps, (unsigned long long)basis,
                                     vec_re, vec_im, next_re, next_im,
                                     &amp_re, &amp_im);
        if (!ok) {
            for (long long j = 0; j < basis; j++) free((void *)(size_t)out->data[j]);
            if (out->data && out->data != out->inline_data) free(out->data);
            free(out);
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return 0;
        }
        if (amp_re > -1e-15 && amp_re < 1e-15) amp_re = 0.0;
        if (amp_im > -1e-15 && amp_im < 1e-15) amp_im = 0.0;
        out->data[basis] = mps_complex_new(amp_re, amp_im);
        if (out->data[basis] == 0) {
            for (long long j = 0; j < basis; j++) free((void *)(size_t)out->data[j]);
            if (out->data && out->data != out->inline_data) free(out->data);
            free(out);
            free(vec_re); free(vec_im); free(next_re); free(next_im);
            return 0;
        }
    }

    free(vec_re); free(vec_im); free(next_re); free(next_im);
    return (long long)out;
}
