// rods/pnp — Perspective-n-Point camera pose estimation.
//
// Given N known 3D points X_i in world frame and their observed
// 2D pixel projections u_i, plus the camera intrinsics K, find
// the camera pose (R, t) such that K(R·X_i + t) projects to u_i.
//
// Iterative Gauss-Newton on reprojection error. Pose increment is
// SE(3) (δω, δt); each iteration linearizes around the current
// pose, solves the 6×6 normal equations, applies the increment.
//
// Foundation for:
// - Object pose estimation against a known CAD-model point cloud.
// - Visual odometry front-end (track 3D landmarks across frames).
// - AR markers / fiducials (estimate camera pose from corner pixels).
// - Hand-eye calibration target tracking.
//
// Workflow:
//   // 3D points and 2D pixels are caller-allocated buffers.
//   // R is double[9] row-major, t is double[3]; both hold the
//   // initial guess on entry and the refined pose on exit.
//   pnp_solve(pts3d_ptr, pts2d_ptr, n_pts,
//             fx_b, fy_b, cx_b, cy_b,
//             max_iters,
//             R_inout_ptr, t_inout_ptr);
//
//   let rms = pnp_reprojection_rms(...);   // diagnostic
//
// Limitations (closed-form EPnP / P3P initialization, RANSAC-
// based outlier rejection land in v0.6 if needed):
// - Iterative-only — caller supplies initial guess. Identity pose
//   works for typical visual servoing setups (converges 5-10 iters).
// - No outlier rejection (caller pre-filters via `ransac.nr` if
//   correspondences are noisy).
// - Pinhole intrinsics only (no distortion).
//
// See `stdlib/runtime/pnp_rt.c`.
#cfile "../runtime/pnp_rt.c"

extern fn nuc_pnp_solve(
    pts3d_ptr: i64, pts2d_ptr: i64, n_pts: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64,
    max_iters: i64,
    R_inout_ptr: i64, t_inout_ptr: i64) -> i64;

extern fn nuc_pnp_reprojection_rms(
    pts3d_ptr: i64, pts2d_ptr: i64, n_pts: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64,
    R_ptr: i64, t_ptr: i64) -> i64;

// Iterative PnP. R is `double[9]` row-major, t is `double[3]`;
// both hold initial guess on entry and refined pose on exit.
// Returns iterations performed (≤ max_iters).
fn pnp_solve(pts3d_ptr: i64, pts2d_ptr: i64, n_pts: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64,
    max_iters: i64,
    R_inout_ptr: i64, t_inout_ptr: i64) -> i64
{
    return nuc_pnp_solve(pts3d_ptr, pts2d_ptr, n_pts,
        fx_b, fy_b, cx_b, cy_b, max_iters,
        R_inout_ptr, t_inout_ptr);
}

// Reprojection RMS error (in pixels) after applying (R, t).
// Useful for verifying convergence quality.
fn pnp_reprojection_rms(pts3d_ptr: i64, pts2d_ptr: i64, n_pts: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64,
    R_ptr: i64, t_ptr: i64) -> i64
{
    return nuc_pnp_reprojection_rms(pts3d_ptr, pts2d_ptr, n_pts,
        fx_b, fy_b, cx_b, cy_b, R_ptr, t_ptr);
}
