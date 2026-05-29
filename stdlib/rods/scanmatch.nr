// rods/scanmatch — 2D point-cloud / laser-scan ICP alignment.
//
// Given two 2D point clouds (typically reconstructed from
// successive LiDAR scans), find the rigid transform `(Δx, Δy, Δθ)`
// that best aligns scan1 onto scan2. Standard SLAM front-end
// scan-matcher primitive.
//
// Complement to `icp.nr` (3D point-to-point ICP) — `scanmatch.nr`
// is the 2D specialization with a closed-form 2D Procrustes step.
//
// Workflow:
//
//   import "stdlib/rods/scanmatch.nr"
//
//   // src and dst: caller-allocated double[N*2] (interleaved xy).
//   // dx_dy_dt: double[3] initial guess on entry, refined on return.
//   let dx_dy_dt: double[3] = (0, 0, 0);
//   let iters = scanmatch_icp_2d(src_ptr, n_src,
//                                  dst_ptr, n_dst,
//                                  max_iters, tol_b,
//                                  dx_dy_dt_out_ptr);
//
// Algorithm:
//   for iter:
//     warp src by current (dx, dy, dt)
//     match each warped src → nearest dst (brute force)
//     Procrustes: closed-form 2D rigid transform from matched pairs
//     compose new transform with old; check convergence
//
// Limitations (point-to-line ICP / KD-tree NN / outlier
// rejection land in v0.6 if needed):
// - Brute-force NN: `O(N_src · N_dst)` per iter.
// - No outlier rejection — every src point gets a match.
// - Point-to-point only.
//
// See `stdlib/runtime/scanmatch_rt.c`.
#cfile "../runtime/scanmatch_rt.c"

extern fn nuc_scanmatch_icp_2d(src_ptr: i64, n_src: i64,
    dst_ptr: i64, n_dst: i64,
    max_iters: i64, tol_b: i64,
    dx_dy_dt_out_ptr: i64) -> i64;

// 2D ICP. `dx_dy_dt_out_ptr` is `double[3]` initial-guess on entry,
// refined estimate on return. Returns number of iterations actually
// performed.
fn scanmatch_icp_2d(src_ptr: i64, n_src: i64,
    dst_ptr: i64, n_dst: i64,
    max_iters: i64, tol_b: i64,
    dx_dy_dt_out_ptr: i64) -> i64
{
    return nuc_scanmatch_icp_2d(src_ptr, n_src, dst_ptr, n_dst,
        max_iters, tol_b, dx_dy_dt_out_ptr);
}
