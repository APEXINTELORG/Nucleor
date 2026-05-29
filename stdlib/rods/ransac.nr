// rods/ransac — RANSAC outlier-robust geometric fitting.
//
// RANSAC (RANdom SAmple Consensus, Fischler & Bolles 1981) is the
// standard outlier-robust fitting algorithm in robotics
// perception: repeatedly sample minimum points, fit, count inliers,
// keep best, refit on inliers.
//
// This rod ships the most common single instantiation: 3D plane
// fitting. Use cases:
// - LiDAR ground-plane detection (segment ground from obstacles).
// - Depth-scan surface fitting (table tops, walls).
// - Point-cloud preprocessing for ICP (filter outliers first).
//
// Workflow:
//   // pts is a double[N * 3] buffer of point cloud.
//   // plane_out is double[4] for (nx, ny, nz, d) with n unit and
//   // plane equation: n · p + d = 0.
//   // inlier_count_out is i64.
//   ransac_plane_3d(pts_ptr, n_pts,
//                   n_trials,
//                   inlier_thresh_b,
//                   seed,
//                   plane_out_ptr, inlier_count_out_ptr);
//
// Limitations (generic-callback RANSAC for line/sphere/transform
// fitting + adaptive trial-count via inlier ratio land in v0.6 if
// needed):
// - 3D plane only.
// - Fixed trial count (no early termination).
// - Final refit uses unweighted PCA on all inliers.
//
// See `stdlib/runtime/ransac_rt.c`.
#cfile "../runtime/ransac_rt.c"

extern fn nuc_ransac_plane_3d(
    pts_ptr: i64, n_pts: i64,
    n_trials: i64,
    inlier_thresh_b: i64,
    seed: i64,
    plane_out_ptr: i64, inlier_count_out_ptr: i64) -> i64;

// Generic RANSAC orchestrator (v0.2.281).
extern fn nuc_ransac_run(
    n_data: i64, n_min_samples: i64, model_size: i64,
    n_iters: i64, seed: i64,
    fit_fp: i64, score_fp: i64,
    best_model_out_ptr: i64, inlier_mask_out_ptr: i64) -> i64;

// Fit a 3D plane to a point cloud via RANSAC. Returns 0 on success
// (writes (nx, ny, nz, d) to `plane_out_ptr` and inlier count to
// `inlier_count_out_ptr`); -1 on bad input.
//
// The plane equation is `nx·x + ny·y + nz·z + d = 0` with the
// normal vector unit-length. After RANSAC selects the trial with
// the most inliers, the final plane is refit by PCA on those
// inliers (smallest-eigenvalue eigenvector of the centered
// covariance is the normal).
fn ransac_plane_3d(pts_ptr: i64, n_pts: i64,
    n_trials: i64,
    inlier_thresh_b: i64,
    seed: i64,
    plane_out_ptr: i64, inlier_count_out_ptr: i64) -> i64
{
    return nuc_ransac_plane_3d(pts_ptr, n_pts, n_trials,
        inlier_thresh_b, seed, plane_out_ptr, inlier_count_out_ptr);
}

// Generic RANSAC orchestrator (v0.2.281). Caller supplies a `fit`
// callback that fits a candidate model from a sample of indices,
// and a `score` callback that returns 1 if a data point is an
// inlier under a candidate model. The rod handles random sampling,
// best-model tracking, and inlier-mask reporting.
//
// Callbacks:
//   fit_fp:   fn(indices_ptr, n_indices, model_out_ptr) -> i64
//             - indices_ptr: i64[n_indices] — sampled data indices
//             - model_out_ptr: caller-allocated double[model_size]
//             - return 1 on success, 0 on degenerate sample
//   score_fp: fn(model_ptr, data_index) -> i64
//             - return 1 if inlier, 0 otherwise
//
// Returns the inlier count of the best model (also written to
// `best_model_out_ptr` and `inlier_mask_out_ptr` (i64[n_data])).
//
// Use this for any geometric model not covered by the specialized
// `ransac_plane_3d`: 2-D line / circle, 3-D sphere, fundamental /
// essential matrix, similarity transform between point clouds, etc.
fn ransac_run(n_data: i64, n_min_samples: i64, model_size: i64,
    n_iters: i64, seed: i64,
    fit_fp: i64, score_fp: i64,
    best_model_out_ptr: i64, inlier_mask_out_ptr: i64) -> i64
{
    return nuc_ransac_run(n_data, n_min_samples, model_size,
        n_iters, seed, fit_fp, score_fp,
        best_model_out_ptr, inlier_mask_out_ptr);
}
