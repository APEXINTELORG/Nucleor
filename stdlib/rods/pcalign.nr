// rods/pcalign — Closed-form 3-D rigid alignment of two point
// clouds with known correspondences (Horn 1987 quaternion
// formulation).
//
// Given source points `A_i ∈ ℝ³` and destination points
// `B_i ∈ ℝ³` with `i = 1..N` correspondences, finds the rotation
// and translation `(R, t)` minimizing `Σ ‖R · A_i + t − B_i‖²`.
//
// Foundation for:
//   - ICP back-end (alignment after nearest-neighbor matching).
//   - Fragment registration (3-scan-to-3-scan rigid alignment).
//   - AR pose estimation from world-anchor correspondences.
//   - RANSAC + this combined for outlier-robust registration:
//     `ransac_run` with `pcalign_horn` as the `fit` callback, and
//     reprojection-error-threshold as `score`.
//
// Workflow:
//
//   import "stdlib/rods/pcalign.nr"
//
//   // src and dst are caller-allocated double[N * 3], row-major XYZ.
//   let ok = pcalign_horn(src_ptr, dst_ptr, n_points,
//                          t_out_ptr, q_out_ptr);
//
//   // Now (t_out, q_out) is the rigid transform sending src into dst.
//
// Algorithm:
//   1. Compute centroids Ā, B̄.
//   2. Compute 3×3 cross-covariance `M = Σ A'_i · B'_iᵀ` (centered).
//   3. Build Horn's symmetric 4×4 `N` matrix from `M`.
//   4. Optimal `q` = eigenvector of `N` with the LARGEST eigenvalue
//      (4×4 Jacobi rotations).
//   5. `t = B̄ − R(q) · Ā`.
//
// Limitations (non-rigid / scale / weighted variants land in
// v0.6 if needed):
// - Rigid (rotation + translation) only. For scale-aware alignment,
//   pre-normalize by point-cloud sigma and rescale post-hoc.
// - Equal-weight points. For weighted, premultiply `A_i, B_i` by `√w_i`.
// - Returns 0 on degenerate input (`N < 3` or all coincident points).
//
// See `stdlib/runtime/pcalign_rt.c`.
#cfile "../runtime/pcalign_rt.c"

extern fn nuc_pcalign_horn(src_ptr: i64, dst_ptr: i64, n: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64;

// Outlier-robust variant (v0.2.289): RANSAC over correspondences.
extern fn nuc_pcalign_horn_ransac(src_ptr: i64, dst_ptr: i64, n: i64,
    n_iters: i64, threshold_b: i64, seed: i64,
    t_out_ptr: i64, q_out_ptr: i64, inlier_mask_out_ptr: i64) -> i64;

// Closed-form rigid alignment via Horn's quaternion method.
// Returns 1 on success (writes `(t, q)` to caller buffers — `t_out`
// is `double[3]`, `q_out` is `double[4]`); 0 on degenerate input
// or fewer than 3 correspondences.
fn pcalign_horn(src_ptr: i64, dst_ptr: i64, n: i64,
    t_out_ptr: i64, q_out_ptr: i64) -> i64
{
    return nuc_pcalign_horn(src_ptr, dst_ptr, n, t_out_ptr, q_out_ptr);
}

// Outlier-robust rigid alignment via RANSAC over 3-correspondence
// samples + Horn fit + reprojection-error inlier scoring + final
// refit on inlier set.
//
// `threshold_b`: max Euclidean reprojection error (m) for an inlier.
// `inlier_mask_out_ptr`: caller-allocated `i64[n]` (or 0 to skip);
//   filled with 1 = inlier, 0 = outlier under best model.
// Returns the inlier count of the best model.
//
// Useful for feature-based registration where some correspondences
// are bad matches (visual feature mismatches, scan-to-scan
// confusion, etc.).
fn pcalign_horn_ransac(src_ptr: i64, dst_ptr: i64, n: i64,
    n_iters: i64, threshold_b: i64, seed: i64,
    t_out_ptr: i64, q_out_ptr: i64, inlier_mask_out_ptr: i64) -> i64
{
    return nuc_pcalign_horn_ransac(src_ptr, dst_ptr, n,
        n_iters, threshold_b, seed,
        t_out_ptr, q_out_ptr, inlier_mask_out_ptr);
}
