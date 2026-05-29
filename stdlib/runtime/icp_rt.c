// icp_rt.c — Iterative Closest Point (ICP) for 3D point cloud
// alignment.
//
// Given a source point cloud P (N_src points) and a target point
// cloud Q (N_tgt points), ICP iteratively finds the rigid
// transform (R, t) that minimizes
//
//     min Σ |R·P_i + t − Q_{nn(i)}|²
//
// where nn(i) is the nearest target point to the transformed
// source point. Standard algorithm:
//
//   1. For each source point, find its nearest neighbor in target.
//   2. Compute the optimal rigid transform (Horn 1987 quaternion
//      method) that aligns each source point with its match.
//   3. Apply the transform; check convergence.
//
// Foundation for robotics perception:
// - Point-cloud registration (LiDAR / depth camera / RGBD).
// - Object pose estimation against a CAD-model point cloud.
// - SLAM scan-matching front-end.
//
// Limitations (KD-tree nearest-neighbor + outlier rejection
// land in v0.6 if needed for big point clouds):
// - Brute-force nearest neighbor: O(N_src · N_tgt) per iteration.
//   Fine for clouds ≤ 1000 points; for full LiDAR scans, use
//   the v0.6 KD-tree variant.
// - No outlier rejection (every source point gets a match,
//   regardless of distance). Caller can pre-filter.
// - Point-to-point only (point-to-plane is the common
//   alternative for surface-rich scenes; lands in v0.6).
//
// Compile: clang -c stdlib/runtime/icp_rt.c -o target/icp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Find nearest neighbor of point p in the target cloud Q (M points).
// Returns the index of the closest target point.
static int _nearest_in(const double *p, const double *Q, int M) {
    int best = 0;
    double dx = p[0] - Q[0], dy = p[1] - Q[1], dz = p[2] - Q[2];
    double best_d2 = dx*dx + dy*dy + dz*dz;
    for (int i = 1; i < M; i++) {
        dx = p[0] - Q[i*3+0]; dy = p[1] - Q[i*3+1]; dz = p[2] - Q[i*3+2];
        double d2 = dx*dx + dy*dy + dz*dz;
        if (d2 < best_d2) { best_d2 = d2; best = i; }
    }
    return best;
}

// Apply (R, t) to a 3-vector: out = R·v + t.
static void _apply_Rt(const double *R, const double *t, const double *v, double *out) {
    out[0] = R[0]*v[0] + R[1]*v[1] + R[2]*v[2] + t[0];
    out[1] = R[3]*v[0] + R[4]*v[1] + R[5]*v[2] + t[1];
    out[2] = R[6]*v[0] + R[7]*v[1] + R[8]*v[2] + t[2];
}

// Convert unit quaternion (w, x, y, z) to a 3×3 rotation matrix
// (row-major).
static void _quat_to_R(const double *q, double *R) {
    double w = q[0], x = q[1], y = q[2], z = q[3];
    R[0] = 1 - 2*(y*y + z*z);  R[1] = 2*(x*y - w*z);      R[2] = 2*(x*z + w*y);
    R[3] = 2*(x*y + w*z);      R[4] = 1 - 2*(x*x + z*z);  R[5] = 2*(y*z - w*x);
    R[6] = 2*(x*z - w*y);      R[7] = 2*(y*z + w*x);      R[8] = 1 - 2*(x*x + y*y);
}

// Multiply 3×3 matrices: C = A·B.
static void _mat3_mul(const double *A, const double *B, double *C) {
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            C[i*3 + j] = A[i*3+0]*B[0*3+j] + A[i*3+1]*B[1*3+j] + A[i*3+2]*B[2*3+j];
        }
}

// Top-eigenvector of a 4×4 symmetric matrix via shifted power
// iteration. Returns the unit eigenvector in `v_out`. Uses a
// single shift `μ = trace/4` to ensure the largest eigenvalue
// dominates.
static void _top_eigenvec_4x4(const double *N, double *v_out) {
    // Shift by trace/4 so all eigenvalues are positive (or close).
    double tr = N[0] + N[5] + N[10] + N[15];
    double mu = tr / 4.0;
    double M[16];
    for (int i = 0; i < 16; i++) M[i] = N[i];
    for (int i = 0; i < 4; i++) M[i*4 + i] -= mu;
    // Power iteration: 50 iters typically suffices for 4×4.
    double v[4] = {1, 0, 0, 0};
    for (int it = 0; it < 80; it++) {
        double v2[4];
        for (int i = 0; i < 4; i++) {
            v2[i] = M[i*4+0]*v[0] + M[i*4+1]*v[1] + M[i*4+2]*v[2] + M[i*4+3]*v[3];
        }
        double nrm = sqrt(v2[0]*v2[0] + v2[1]*v2[1] + v2[2]*v2[2] + v2[3]*v2[3]);
        if (nrm < 1e-18) break;
        for (int i = 0; i < 4; i++) v[i] = v2[i] / nrm;
    }
    // Power iteration converges to the eigenvector of LARGEST
    // |eigenvalue|. After shift, the largest is the original
    // top + (-mu) which has the most positive value if N's top
    // eigenvalue exceeds the trace/4 average. For Horn's N this
    // is always true for any non-degenerate point cloud.
    v_out[0] = v[0]; v_out[1] = v[1]; v_out[2] = v[2]; v_out[3] = v[3];
}

// Compute optimal R, t aligning source points P (N) to target
// points P_match (N) per Horn's quaternion method (closed-form).
static void _kabsch_horn(const double *P, const double *Q, int N,
                         double *R_out, double *t_out)
{
    // Centroids.
    double cP[3] = {0,0,0}, cQ[3] = {0,0,0};
    for (int i = 0; i < N; i++) {
        cP[0] += P[i*3+0]; cP[1] += P[i*3+1]; cP[2] += P[i*3+2];
        cQ[0] += Q[i*3+0]; cQ[1] += Q[i*3+1]; cQ[2] += Q[i*3+2];
    }
    cP[0] /= N; cP[1] /= N; cP[2] /= N;
    cQ[0] /= N; cQ[1] /= N; cQ[2] /= N;
    // Cross-covariance H = Σ (P_i - cP)·(Q_i - cQ)ᵀ  (3×3).
    double Sxx=0, Sxy=0, Sxz=0, Syx=0, Syy=0, Syz=0, Szx=0, Szy=0, Szz=0;
    for (int i = 0; i < N; i++) {
        double px = P[i*3+0] - cP[0], py = P[i*3+1] - cP[1], pz = P[i*3+2] - cP[2];
        double qx = Q[i*3+0] - cQ[0], qy = Q[i*3+1] - cQ[1], qz = Q[i*3+2] - cQ[2];
        Sxx += px*qx; Sxy += px*qy; Sxz += px*qz;
        Syx += py*qx; Syy += py*qy; Syz += py*qz;
        Szx += pz*qx; Szy += pz*qy; Szz += pz*qz;
    }
    // Horn's 4×4 N matrix (symmetric).
    double Nm[16] = {
         Sxx + Syy + Szz,    Syz - Szy,           Szx - Sxz,           Sxy - Syx,
         Syz - Szy,          Sxx - Syy - Szz,     Sxy + Syx,           Szx + Sxz,
         Szx - Sxz,          Sxy + Syx,          -Sxx + Syy - Szz,     Syz + Szy,
         Sxy - Syx,          Szx + Sxz,           Syz + Szy,          -Sxx - Syy + Szz
    };
    double q[4];
    _top_eigenvec_4x4(Nm, q);
    // Ensure proper rotation (q's sign doesn't matter for rotation).
    _quat_to_R(q, R_out);
    // Translation: t = cQ - R·cP.
    t_out[0] = cQ[0] - (R_out[0]*cP[0] + R_out[1]*cP[1] + R_out[2]*cP[2]);
    t_out[1] = cQ[1] - (R_out[3]*cP[0] + R_out[4]*cP[1] + R_out[5]*cP[2]);
    t_out[2] = cQ[2] - (R_out[6]*cP[0] + R_out[7]*cP[1] + R_out[8]*cP[2]);
}

// Mean squared error between transformed source and matched targets.
static double _mse(const double *P, int N, const double *Q,
                   const double *R, const double *t)
{
    double err = 0;
    for (int i = 0; i < N; i++) {
        double tp[3];
        _apply_Rt(R, t, P + i*3, tp);
        // Q[i*3..] is the matched target; assumed pre-matched.
        double dx = tp[0] - Q[i*3+0];
        double dy = tp[1] - Q[i*3+1];
        double dz = tp[2] - Q[i*3+2];
        err += dx*dx + dy*dy + dz*dz;
    }
    return err / N;
}

// Centroid-alignment initial guess: returns (R = I, t = cQ - cP).
// Useful as an ICP initialization to handle large translations that
// would otherwise cause the nearest-neighbor matching to degenerate
// (every source point matches the same closest target vertex).
// Caller must run ICP afterward to refine the rotation.
long long nuc_icp_centroid_init(
    long long src_ptr, long long n_src,
    long long tgt_ptr, long long n_tgt,
    long long R_out_ptr, long long t_out_ptr)
{
    int N = (int)n_src, M = (int)n_tgt;
    if (N <= 0 || M <= 0) return -1;
    const double *P = (const double *)(void *)(size_t)src_ptr;
    const double *Q = (const double *)(void *)(size_t)tgt_ptr;
    double *R = (double *)(void *)(size_t)R_out_ptr;
    double *t = (double *)(void *)(size_t)t_out_ptr;
    if (!P || !Q || !R || !t) return -1;
    double cP[3] = {0,0,0}, cQ[3] = {0,0,0};
    for (int i = 0; i < N; i++) { cP[0]+=P[i*3+0]; cP[1]+=P[i*3+1]; cP[2]+=P[i*3+2]; }
    for (int i = 0; i < M; i++) { cQ[0]+=Q[i*3+0]; cQ[1]+=Q[i*3+1]; cQ[2]+=Q[i*3+2]; }
    cP[0] /= N; cP[1] /= N; cP[2] /= N;
    cQ[0] /= M; cQ[1] /= M; cQ[2] /= M;
    for (int i = 0; i < 9; i++) R[i] = (i % 4 == 0) ? 1.0 : 0.0;
    t[0] = cQ[0] - cP[0]; t[1] = cQ[1] - cP[1]; t[2] = cQ[2] - cP[2];
    return 0;
}

// ICP entry point. `R_inout_ptr` (double[9] row-major) and
// `t_inout_ptr` (double[3]) hold the initial transform on entry
// and the refined transform on exit. Returns the number of
// iterations actually performed (≤ max_iters).
long long nuc_icp_align(
    long long src_ptr, long long n_src,
    long long tgt_ptr, long long n_tgt,
    long long max_iters, long long tol_b,
    long long R_inout_ptr, long long t_inout_ptr)
{
    int N = (int)n_src, M = (int)n_tgt;
    if (N <= 0 || M <= 0) return -1;
    const double *P = (const double *)(void *)(size_t)src_ptr;
    const double *Q = (const double *)(void *)(size_t)tgt_ptr;
    double *R = (double *)(void *)(size_t)R_inout_ptr;
    double *t = (double *)(void *)(size_t)t_inout_ptr;
    if (!P || !Q || !R || !t) return -1;
    double tol = _i2f(tol_b);

    double *Pt = (double *)malloc(N * 3 * sizeof(double));      // transformed source
    double *Qm = (double *)malloc(N * 3 * sizeof(double));      // matched target

    long long iter;
    double prev_err = 1e300;
    for (iter = 0; iter < max_iters; iter++) {
        // Apply current transform to source.
        for (int i = 0; i < N; i++) _apply_Rt(R, t, P + i*3, Pt + i*3);
        // Find nearest neighbor for each transformed source point.
        for (int i = 0; i < N; i++) {
            int j = _nearest_in(Pt + i*3, Q, M);
            Qm[i*3+0] = Q[j*3+0]; Qm[i*3+1] = Q[j*3+1]; Qm[i*3+2] = Q[j*3+2];
        }
        // Find optimal incremental transform Pt → Qm.
        double R_inc[9], t_inc[3];
        _kabsch_horn(Pt, Qm, N, R_inc, t_inc);
        // Compose: new R = R_inc · R_old; new t = R_inc · t_old + t_inc.
        double R_new[9];
        _mat3_mul(R_inc, R, R_new);
        double t_rotated[3];
        t_rotated[0] = R_inc[0]*t[0] + R_inc[1]*t[1] + R_inc[2]*t[2];
        t_rotated[1] = R_inc[3]*t[0] + R_inc[4]*t[1] + R_inc[5]*t[2];
        t_rotated[2] = R_inc[6]*t[0] + R_inc[7]*t[1] + R_inc[8]*t[2];
        for (int i = 0; i < 9; i++) R[i] = R_new[i];
        for (int i = 0; i < 3; i++) t[i] = t_rotated[i] + t_inc[i];
        // Convergence check on MSE.
        double err = _mse(P, N, Qm, R, t);
        if (fabs(prev_err - err) < tol) { iter++; break; }
        prev_err = err;
    }

    free(Pt); free(Qm);
    return iter;
}

// Diagnostic: residual MSE between transformed source and nearest
// targets after applying (R, t).
long long nuc_icp_residual(
    long long src_ptr, long long n_src,
    long long tgt_ptr, long long n_tgt,
    long long R_ptr, long long t_ptr)
{
    int N = (int)n_src, M = (int)n_tgt;
    if (N <= 0 || M <= 0) return _f2i(0.0);
    const double *P = (const double *)(void *)(size_t)src_ptr;
    const double *Q = (const double *)(void *)(size_t)tgt_ptr;
    const double *R = (const double *)(void *)(size_t)R_ptr;
    const double *t = (const double *)(void *)(size_t)t_ptr;
    double err = 0;
    for (int i = 0; i < N; i++) {
        double tp[3];
        _apply_Rt(R, t, P + i*3, tp);
        int j = _nearest_in(tp, Q, M);
        double dx = tp[0] - Q[j*3+0];
        double dy = tp[1] - Q[j*3+1];
        double dz = tp[2] - Q[j*3+2];
        err += dx*dx + dy*dy + dz*dz;
    }
    return _f2i(err / N);
}
