// rods/icp — Iterative Closest Point for 3D point cloud
// alignment.
//
// Standard scan-matching / object-pose-estimation primitive used
// throughout robotics perception. Given a source point cloud and
// a target point cloud, finds the rigid transform (R, t) that
// best aligns the source onto the target by alternating between:
//
//   1. Match each source point to its nearest neighbor in target.
//   2. Compute the optimal rigid transform via Horn 1987's
//      quaternion-based closed-form solution.
//
// Foundation for:
// - Point-cloud registration (LiDAR / depth camera / RGBD).
// - Object pose estimation against a CAD-model point cloud.
// - SLAM scan-matching front-end.
//
// Workflow:
//   // R is a 9-double row-major rotation, t is 3-double translation.
//   // Pre-fill with the initial guess; ICP refines in place.
//   icp_align(src_ptr, n_src, tgt_ptr, n_tgt,
//             max_iters, tol_b, R_ptr, t_ptr);
//
//   // Verify the residual.
//   let mse = icp_residual(src_ptr, n_src, tgt_ptr, n_tgt, R_ptr, t_ptr);
//
// **Limitations** (KD-tree nearest-neighbor + outlier rejection
// land in v0.6 if needed):
// - Brute-force nearest neighbor: O(N_src · N_tgt) per iteration.
// - No outlier rejection — every source point gets a match.
//   Caller can pre-filter the input.
// - Point-to-point only (point-to-plane is the surface-rich-
//   scene alternative; lands in v0.6).
//
// See `stdlib/runtime/icp_rt.c`.
#cfile "../runtime/icp_rt.c"

extern fn nuc_icp_centroid_init(
    src_ptr: i64, n_src: i64,
    tgt_ptr: i64, n_tgt: i64,
    R_out_ptr: i64, t_out_ptr: i64) -> i64;

extern fn nuc_icp_align(
    src_ptr: i64, n_src: i64,
    tgt_ptr: i64, n_tgt: i64,
    max_iters: i64, tol_b: i64,
    R_inout_ptr: i64, t_inout_ptr: i64) -> i64;

extern fn nuc_icp_residual(
    src_ptr: i64, n_src: i64,
    tgt_ptr: i64, n_tgt: i64,
    R_ptr: i64, t_ptr: i64) -> i64;

// Centroid-based initial guess: writes R = identity, t = cQ - cP
// where cP and cQ are the source/target centroids. Useful as an
// `icp_align` initialization for clouds with large translation
// offsets — without this, all source points may degenerate to
// matching the same closest target vertex on the first iteration.
fn icp_centroid_init(src_ptr: i64, n_src: i64,
                     tgt_ptr: i64, n_tgt: i64,
                     R_out_ptr: i64, t_out_ptr: i64) -> i64
{
    return nuc_icp_centroid_init(src_ptr, n_src, tgt_ptr, n_tgt,
                                  R_out_ptr, t_out_ptr);
}

// Align source onto target via ICP. `R_inout_ptr` is a `double[9]`
// row-major rotation and `t_inout_ptr` is a `double[3]`
// translation; both hold the initial guess on entry and the
// refined transform on exit. Returns the number of iterations
// actually performed.
fn icp_align(src_ptr: i64, n_src: i64,
             tgt_ptr: i64, n_tgt: i64,
             max_iters: i64, tol_b: i64,
             R_inout_ptr: i64, t_inout_ptr: i64) -> i64
{
    return nuc_icp_align(src_ptr, n_src, tgt_ptr, n_tgt,
                         max_iters, tol_b, R_inout_ptr, t_inout_ptr);
}

// Residual mean-squared-error after applying (R, t) to source and
// taking nearest-neighbor distance in target. Useful for verifying
// that ICP converged to a good fit. Returned as bit-cast f64.
fn icp_residual(src_ptr: i64, n_src: i64,
                tgt_ptr: i64, n_tgt: i64,
                R_ptr: i64, t_ptr: i64) -> i64
{
    return nuc_icp_residual(src_ptr, n_src, tgt_ptr, n_tgt, R_ptr, t_ptr);
}
