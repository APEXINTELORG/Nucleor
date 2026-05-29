// scanmatch_rt.c — 2D point-cloud / laser-scan ICP alignment.
//
// Given two 2D point clouds (typically reconstructed from
// successive LiDAR scans), find the rigid transform `(Δx, Δy, Δθ)`
// that best aligns scan1 onto scan2. Standard SLAM front-end
// scan-matcher primitive.
//
// Algorithm (vanilla ICP):
//   for iter in 1..max_iters:
//     for each src point: nearest-neighbor in dst
//     compute optimal 2D rigid transform via closed-form Procrustes
//     apply transform to all src points; accumulate
//     if step < tol: break
//
// Closed-form 2D Procrustes (Umeyama 1991, 2D specialization):
//   centroids cA, cB
//   cross-cov M = Σ (a_i − cA)·(b_i − cB)ᵀ      (2×2)
//   θ = atan2(M[0,1] − M[1,0], M[0,0] + M[1,1])
//   t = cB − R(θ) · cA
//
// Use:
//   - 2D LiDAR scan-to-scan alignment for mobile-robot odometry.
//   - Loop-closure scoring (run scan-match between non-adjacent
//     scans, accept loop if residual is low).
//   - Sub-map alignment.
//
// Limitations (point-to-line ICP / KD-tree NN / outlier
// rejection land in v0.6 if needed):
// - Brute-force nearest-neighbor: `O(N_src · N_dst)` per iter.
// - No outlier rejection — every src point gets a match.
// - Point-to-point only — for noisy LiDAR a point-to-line variant
//   is more robust.
//
// Compile: clang -c stdlib/runtime/scanmatch_rt.c -o target/scanmatch.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// 2D Procrustes from corresponding pairs (A_i, B_i). Writes
// (dx, dy, dtheta) such that B_i ≈ R(dtheta) · A_i + (dx, dy).
static void _procrustes_2d(const double *A, const double *B, int N,
                           double *dx, double *dy, double *dt)
{
    double cAx = 0, cAy = 0, cBx = 0, cBy = 0;
    for (int i = 0; i < N; i++) {
        cAx += A[i*2+0]; cAy += A[i*2+1];
        cBx += B[i*2+0]; cBy += B[i*2+1];
    }
    cAx /= N; cAy /= N; cBx /= N; cBy /= N;
    // Centered cross-cov M (2×2).
    double M00 = 0, M01 = 0, M10 = 0, M11 = 0;
    for (int i = 0; i < N; i++) {
        double ax = A[i*2+0] - cAx, ay = A[i*2+1] - cAy;
        double bx = B[i*2+0] - cBx, by = B[i*2+1] - cBy;
        M00 += ax * bx; M01 += ax * by;
        M10 += ay * bx; M11 += ay * by;
    }
    *dt = atan2(M01 - M10, M00 + M11);
    double c = cos(*dt), s = sin(*dt);
    // t = cB − R(θ)·cA
    double rcAx = c * cAx - s * cAy;
    double rcAy = s * cAx + c * cAy;
    *dx = cBx - rcAx;
    *dy = cBy - rcAy;
}

// Brute-force nearest neighbor of (px, py) in dst.
static int _nearest(const double *dst, int n_dst, double px, double py) {
    int best = 0;
    double bd = 1e30;
    for (int i = 0; i < n_dst; i++) {
        double dx = dst[i*2+0] - px, dy = dst[i*2+1] - py;
        double d = dx*dx + dy*dy;
        if (d < bd) { bd = d; best = i; }
    }
    return best;
}

// Run 2D ICP. `dx_dy_dt_out_ptr` is a `double[3]` initial-guess
// (mutated to refined estimate). Returns the number of iterations
// actually performed.
long long nuc_scanmatch_icp_2d(long long src_ptr, long long n_src_,
                                long long dst_ptr, long long n_dst_,
                                long long max_iters_, long long tol_b,
                                long long dx_dy_dt_out_ptr)
{
    int n_src = (int)n_src_, n_dst = (int)n_dst_;
    int max_iters = (int)max_iters_;
    if (max_iters <= 0) max_iters = 30;
    if (n_src < 1 || n_dst < 1) return 0;
    const double *src = (const double *)(void *)(size_t)src_ptr;
    const double *dst = (const double *)(void *)(size_t)dst_ptr;
    double *out = (double *)(void *)(size_t)dx_dy_dt_out_ptr;
    if (!src || !dst || !out) return 0;
    double tol = _i2f(tol_b);
    if (tol <= 0) tol = 1e-6;

    double dx = out[0], dy = out[1], dt = out[2];

    double *src_warped = (double *)malloc(n_src * 2 * sizeof(double));
    double *src_matched = (double *)malloc(n_src * 2 * sizeof(double));
    double *dst_matched = (double *)malloc(n_src * 2 * sizeof(double));

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        // Warp src by current (dx, dy, dt).
        double c = cos(dt), s = sin(dt);
        for (int i = 0; i < n_src; i++) {
            src_warped[i*2+0] = c * src[i*2+0] - s * src[i*2+1] + dx;
            src_warped[i*2+1] = s * src[i*2+0] + c * src[i*2+1] + dy;
        }
        // Match each warped src → nearest dst.
        for (int i = 0; i < n_src; i++) {
            int j = _nearest(dst, n_dst, src_warped[i*2+0], src_warped[i*2+1]);
            src_matched[i*2+0] = src_warped[i*2+0];
            src_matched[i*2+1] = src_warped[i*2+1];
            dst_matched[i*2+0] = dst[j*2+0];
            dst_matched[i*2+1] = dst[j*2+1];
        }
        // Procrustes: find incremental (ddx, ddy, ddt).
        double ddx, ddy, ddt;
        _procrustes_2d(src_matched, dst_matched, n_src, &ddx, &ddy, &ddt);
        // Compose: new = incremental ∘ old. The incremental update
        // applies AFTER the current warp, so:
        //   new_dx = ddx + cos(ddt)·dx − sin(ddt)·dy ... wait.
        // Actually we computed Procrustes between WARPED src and dst.
        // The incremental transform takes warped src to dst. We want
        // to update (dx, dy, dt) such that new_R · src + new_t = warped.
        // Composition: new_R = R(ddt) · R(dt), new_t = R(ddt) · t + (ddx, ddy).
        double cdt = cos(ddt), sdt = sin(ddt);
        double new_dt = dt + ddt;
        double new_dx = cdt * dx - sdt * dy + ddx;
        double new_dy = sdt * dx + cdt * dy + ddy;
        dx = new_dx; dy = new_dy; dt = new_dt;

        if (fabs(ddx) < tol && fabs(ddy) < tol && fabs(ddt) < tol) { iter++; break; }
    }

    out[0] = dx; out[1] = dy; out[2] = dt;
    free(src_warped); free(src_matched); free(dst_matched);
    return iter;
}
