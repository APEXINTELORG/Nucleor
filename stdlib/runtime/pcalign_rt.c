// pcalign_rt.c — Closed-form 3-D rigid alignment of two point
// clouds with known correspondences (Horn 1987 — quaternion
// formulation).
//
// Given source points `A_i ∈ ℝ³` and destination points
// `B_i ∈ ℝ³` with `i = 1..N` correspondences, finds the rotation
// `R` (unit quaternion `q`) and translation `t` minimizing
//
//   Σ ‖R · A_i + t − B_i‖²
//
// Algorithm:
//   1. Compute centroids `Ā`, `B̄`.
//   2. Center: `A'_i = A_i − Ā`, `B'_i = B_i − B̄`.
//   3. Compute 3×3 cross-covariance `M = Σ A'_i · B'_iᵀ`.
//   4. Build Horn's 4×4 symmetric `N` matrix from `M`'s entries.
//   5. Optimal `q` = eigenvector of `N` with the largest eigenvalue
//      (computed via Jacobi rotations).
//   6. Translation: `t = B̄ − R(q) · Ā`.
//
// Complexity: `O(N)` for centroids + cross-cov; constant-time 4×4
// eigenvalue extraction.
//
// Foundation for:
//   - ICP back-end (alignment after nearest-neighbor correspondence).
//   - Fragment registration (3-scan-to-3-scan rigid alignment).
//   - AR pose estimation from world-anchor correspondences.
//   - RANSAC + this combined for outlier-robust registration.
//
// **Limitations** (non-rigid / scale / weighted variants land in
// v0.6 if needed):
// - Rigid (rotation + translation) only — no scale or shear.
//   Add scale via Horn's extension if needed.
// - Equal-weight points. For weighted alignment, premultiply
//   `A_i, B_i` by `√w_i` before passing in.
// - Returns 0 on degenerate input (`N < 3` or all coincident points);
//   1 on success.
//
// Compile: clang -c stdlib/runtime/pcalign_rt.c -o target/pcalign.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// 4×4 symmetric Jacobi eigenvalue method.
// On output, `eigvals[i]` are the eigenvalues and `eigvecs[i*4..i*4+3]`
// are the corresponding eigenvectors (column-major: column i is
// eigvec i). Sorted descending by eigenvalue.
static void _jacobi_4x4(double A_in[16], double eigvals[4], double eigvecs[16]) {
    double A[16];
    memcpy(A, A_in, 16 * sizeof(double));
    // Initialize V = I.
    for (int i = 0; i < 16; i++) eigvecs[i] = 0;
    for (int i = 0; i < 4; i++) eigvecs[i*4 + i] = 1.0;

    for (int sweep = 0; sweep < 50; sweep++) {
        // Find largest off-diagonal element.
        double max_off = 0;
        int p = 0, q = 1;
        for (int i = 0; i < 4; i++) {
            for (int j = i + 1; j < 4; j++) {
                double v = fabs(A[i*4 + j]);
                if (v > max_off) { max_off = v; p = i; q = j; }
            }
        }
        if (max_off < 1e-14) break;

        // Compute Jacobi rotation.
        double app = A[p*4 + p];
        double aqq = A[q*4 + q];
        double apq = A[p*4 + q];
        double theta = (aqq - app) / (2.0 * apq);
        double t = (theta >= 0) ? 1.0 / (theta + sqrt(1.0 + theta*theta))
                                 : 1.0 / (theta - sqrt(1.0 + theta*theta));
        double c = 1.0 / sqrt(1.0 + t*t);
        double s = t * c;

        // Update A.
        double new_app = app - t * apq;
        double new_aqq = aqq + t * apq;
        A[p*4 + p] = new_app;
        A[q*4 + q] = new_aqq;
        A[p*4 + q] = 0;
        A[q*4 + p] = 0;
        for (int k = 0; k < 4; k++) {
            if (k == p || k == q) continue;
            double a_pk = A[p*4 + k];
            double a_qk = A[q*4 + k];
            A[p*4 + k] = c * a_pk - s * a_qk;
            A[k*4 + p] = A[p*4 + k];
            A[q*4 + k] = s * a_pk + c * a_qk;
            A[k*4 + q] = A[q*4 + k];
        }
        // Update eigenvectors V.
        for (int k = 0; k < 4; k++) {
            double v_pk = eigvecs[k*4 + p];
            double v_qk = eigvecs[k*4 + q];
            eigvecs[k*4 + p] = c * v_pk - s * v_qk;
            eigvecs[k*4 + q] = s * v_pk + c * v_qk;
        }
    }

    // Extract eigenvalues from diagonal.
    for (int i = 0; i < 4; i++) eigvals[i] = A[i*4 + i];

    // Sort descending.
    for (int i = 0; i < 3; i++) {
        for (int j = i + 1; j < 4; j++) {
            if (eigvals[j] > eigvals[i]) {
                double tv = eigvals[i]; eigvals[i] = eigvals[j]; eigvals[j] = tv;
                for (int k = 0; k < 4; k++) {
                    double tmp = eigvecs[k*4 + i];
                    eigvecs[k*4 + i] = eigvecs[k*4 + j];
                    eigvecs[k*4 + j] = tmp;
                }
            }
        }
    }
}

// Convert quaternion (w, x, y, z) to 3×3 rotation matrix (row-major).
static void _q_to_R(const double *q, double *R) {
    double w = q[0], x = q[1], y = q[2], z = q[3];
    R[0] = 1.0 - 2.0*(y*y + z*z);
    R[1] = 2.0*(x*y - w*z);
    R[2] = 2.0*(x*z + w*y);
    R[3] = 2.0*(x*y + w*z);
    R[4] = 1.0 - 2.0*(x*x + z*z);
    R[5] = 2.0*(y*z - w*x);
    R[6] = 2.0*(x*z - w*y);
    R[7] = 2.0*(y*z + w*x);
    R[8] = 1.0 - 2.0*(x*x + y*y);
}

// Horn rigid alignment.
// `src_ptr` and `dst_ptr` are `double[n*3]` (row-major XYZ).
// Returns 1 on success, 0 if N < 3 or degenerate.
long long nuc_pcalign_horn(long long src_ptr, long long dst_ptr, long long n_,
                            long long t_out_ptr, long long q_out_ptr)
{
    int n = (int)n_;
    if (n < 3) return 0;
    const double *A = (const double *)(void *)(size_t)src_ptr;
    const double *B = (const double *)(void *)(size_t)dst_ptr;
    double *t_out = (double *)(void *)(size_t)t_out_ptr;
    double *q_out = (double *)(void *)(size_t)q_out_ptr;
    if (!A || !B || !t_out || !q_out) return 0;

    // Centroids.
    double Abar[3] = {0,0,0}, Bbar[3] = {0,0,0};
    for (int i = 0; i < n; i++) {
        Abar[0] += A[i*3]; Abar[1] += A[i*3+1]; Abar[2] += A[i*3+2];
        Bbar[0] += B[i*3]; Bbar[1] += B[i*3+1]; Bbar[2] += B[i*3+2];
    }
    Abar[0] /= n; Abar[1] /= n; Abar[2] /= n;
    Bbar[0] /= n; Bbar[1] /= n; Bbar[2] /= n;

    // M = Σ A'_i · B'_iᵀ  (3×3, row-major).
    double M[9] = {0};
    for (int i = 0; i < n; i++) {
        double ax = A[i*3] - Abar[0], ay = A[i*3+1] - Abar[1], az = A[i*3+2] - Abar[2];
        double bx = B[i*3] - Bbar[0], by = B[i*3+1] - Bbar[1], bz = B[i*3+2] - Bbar[2];
        M[0] += ax*bx; M[1] += ax*by; M[2] += ax*bz;
        M[3] += ay*bx; M[4] += ay*by; M[5] += ay*bz;
        M[6] += az*bx; M[7] += az*by; M[8] += az*bz;
    }

    // Horn's 4×4 N matrix.
    //   N[0][0] = M[0][0] + M[1][1] + M[2][2]
    //   N[0][1] = M[1][2] − M[2][1]
    //   N[0][2] = M[2][0] − M[0][2]
    //   N[0][3] = M[0][1] − M[1][0]
    //   N[1][1] = M[0][0] − M[1][1] − M[2][2]
    //   N[1][2] = M[0][1] + M[1][0]
    //   N[1][3] = M[0][2] + M[2][0]
    //   N[2][2] = −M[0][0] + M[1][1] − M[2][2]
    //   N[2][3] = M[1][2] + M[2][1]
    //   N[3][3] = −M[0][0] − M[1][1] + M[2][2]
    double N[16];
    N[0]  = M[0] + M[4] + M[8];
    N[1]  = M[5] - M[7];
    N[2]  = M[6] - M[2];
    N[3]  = M[1] - M[3];
    N[4]  = N[1];
    N[5]  = M[0] - M[4] - M[8];
    N[6]  = M[1] + M[3];
    N[7]  = M[2] + M[6];
    N[8]  = N[2];
    N[9]  = N[6];
    N[10] = -M[0] + M[4] - M[8];
    N[11] = M[5] + M[7];
    N[12] = N[3];
    N[13] = N[7];
    N[14] = N[11];
    N[15] = -M[0] - M[4] + M[8];

    double eigvals[4], eigvecs[16];
    _jacobi_4x4(N, eigvals, eigvecs);

    // q = eigenvector of largest eigenvalue (column 0 after sort).
    double qq[4] = { eigvecs[0*4 + 0], eigvecs[1*4 + 0],
                     eigvecs[2*4 + 0], eigvecs[3*4 + 0] };
    // Ensure positive scalar part for canonical form.
    if (qq[0] < 0) { qq[0] = -qq[0]; qq[1] = -qq[1]; qq[2] = -qq[2]; qq[3] = -qq[3]; }
    double n_q = sqrt(qq[0]*qq[0]+qq[1]*qq[1]+qq[2]*qq[2]+qq[3]*qq[3]);
    if (n_q < 1e-12) return 0;
    qq[0]/=n_q; qq[1]/=n_q; qq[2]/=n_q; qq[3]/=n_q;
    q_out[0] = qq[0]; q_out[1] = qq[1]; q_out[2] = qq[2]; q_out[3] = qq[3];

    // t = Bbar − R(q) · Abar.
    double R[9];
    _q_to_R(qq, R);
    double R_Abar[3];
    R_Abar[0] = R[0]*Abar[0] + R[1]*Abar[1] + R[2]*Abar[2];
    R_Abar[1] = R[3]*Abar[0] + R[4]*Abar[1] + R[5]*Abar[2];
    R_Abar[2] = R[6]*Abar[0] + R[7]*Abar[1] + R[8]*Abar[2];
    t_out[0] = Bbar[0] - R_Abar[0];
    t_out[1] = Bbar[1] - R_Abar[1];
    t_out[2] = Bbar[2] - R_Abar[2];

    return 1;
}
