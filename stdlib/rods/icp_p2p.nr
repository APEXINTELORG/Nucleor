// rods/icp_p2p — Point-to-plane ICP (Chen & Medioni 1991).
//
// Variant of ICP that minimises point-to-tangent-plane distance
// rather than point-to-point:
//
//   `min Σ ((R·P_i + t − Q_j) · n_j)²`,   `j = nn(i)`
//
// Requires per-point surface NORMALS on the target cloud (compute
// with `normal_estimation.nr` or your depth-sensor pipeline).
// Typically converges 3–10× faster than point-to-point ICP on
// planar scenes (room walls, floor, CAD models).
//
// Each iteration linearises the rigid transform around the current
// estimate (small-angle Rodrigues), builds a 6×6 Gauss-Newton
// normal system `JᵀJ δ = −Jᵀr`, solves for the 6-DOF update
// `δ = (α, β, γ, tx, ty, tz)`, applies it, and iterates.
//
// Use:
//   - RGBD / LiDAR alignment (KinectFusion-style front end).
//   - CAD-model registration when you have surface normals.
//   - Scan-matching on a surfel map.
//
// Workflow:
//
//   import "stdlib/rods/icp_p2p.nr"
//
//   let R_out: [9]double;
//   let t_out: [3]double;
//   let iters = icp_p2p(src_ptr, n_src,
//                        tgt_ptr, tgt_normals_ptr, n_tgt,
//                        max_iters, tol_b,
//                        f64_ptr(&R_out[0]),
//                        f64_ptr(&t_out[0]));
//
// Point clouds are `double[N*3]` interleaved `(x, y, z)`. Normals
// are same layout `double[N_tgt*3]`, one unit vector per TARGET
// point.
//
// **Limitations** (KD-tree NN / robust kernel / symmetric
// plane-to-plane metric land in v0.6 if needed):
// - Brute-force nearest-neighbour O(N_src · N_tgt) per iteration.
// - Caller supplies target normals (no estimation here).
// - No outlier rejection (gate residuals externally if needed).
// - Small-angle linearisation assumes approximate pre-alignment.
//
// See `stdlib/runtime/icp_p2p_rt.c`.
#cfile "../runtime/icp_p2p_rt.c"

extern fn nuc_icp_p2p(src_ptr: i64, n_src_: i64,
    tgt_ptr: i64, tgt_normals_ptr: i64, n_tgt_: i64,
    max_iters_: i64, tol_b: i64,
    R_out_ptr: i64, t_out_ptr: i64) -> i64;

// Run point-to-plane ICP. Returns the number of iterations actually
// run (≤ max_iters_). Final transform written to R_out (row-major
// double[9]) and t_out (double[3]).
fn icp_p2p(src_ptr: i64, n_src_: i64,
    tgt_ptr: i64, tgt_normals_ptr: i64, n_tgt_: i64,
    max_iters_: i64, tol_b: i64,
    R_out_ptr: i64, t_out_ptr: i64) -> i64
{
    return nuc_icp_p2p(src_ptr, n_src_, tgt_ptr, tgt_normals_ptr, n_tgt_,
        max_iters_, tol_b, R_out_ptr, t_out_ptr);
}
