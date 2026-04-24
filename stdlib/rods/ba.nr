// rods/ba — Bundle adjustment (visual SLAM back-end).
//
// Jointly refines a set of camera SE(3) poses and a set of 3D
// world points to minimize the sum of squared 2-D reprojection
// errors over a list of (camera, point, pixel) observations.
//
// Camera model: pinhole with shared focal length f and principal
// point (cx, cy). Cameras are stored as (translation t ∈ ℝ³,
// rotation q ∈ SO(3) as a unit quaternion). Camera-frame point:
//
//   X_cam = R_iᵀ · (X_world − t_i)
//
// Pinhole projection:
//
//   u_pred = cx + f · X_cam[0] / X_cam[2]
//   v_pred = cy + f · X_cam[1] / X_cam[2]
//
// Workflow:
//
//   import "stdlib/rods/ba.nr"
//
//   let h = ba_new(n_cams, n_pts, focal_b, cx_b, cy_b);
//
//   // initial camera estimates (caller-allocated double[3] for t,
//   // double[4] for q)
//   for each camera i: ba_set_cam(h, i, t_ptr, q_ptr);
//
//   // initial 3D point estimates (caller-allocated double[3])
//   for each point j: ba_set_pt(h, j, p_ptr);
//
//   // image observations
//   for each (cam_i, pt_j, u_meas, v_meas, info):
//       ba_add_obs(h, cam_i, pt_j, u_b, v_b, info_b);
//
//   ba_optimize(h, max_iters, tol_b);
//
//   // read back refined cameras + points
//   ba_get_cam(h, i, t_out, q_out);
//   ba_get_pt(h, j, p_out);
//
// Camera 0 is gauge-fixed to break the global rigid-motion
// ambiguity. SE(3) updates are applied on the manifold:
//   t_i ← t_i + δ_t,   R_i ← R_i · exp(δ_θ).
//
// **Limitations** (sparse Schur complement, robust kernels,
// per-camera intrinsics, distortion models land in v0.6 if needed):
// - Dense linear solve (Gauss-Jordan): O(dof³) per iter where
//   dof = 6·(N_cam − 1) + 3·N_pts. Fine for N_cam ≤ ~30 and
//   N_pts ≤ ~100. Real visual SLAM uses sparse Schur (separates
//   camera and point blocks) for large maps.
// - Single shared focal length + principal point.
// - L₂ cost only — no robust kernels (Huber, Cauchy).
// - Numerical FD Jacobians.
//
// See `stdlib/runtime/ba_rt.c`.
#cfile "../runtime/ba_rt.c"

extern fn nuc_ba_new(n_cams: i64, n_pts: i64,
    focal_b: i64, cx_b: i64, cy_b: i64) -> i64;
extern fn nuc_ba_set_cam(h: i64, i: i64, t_ptr: i64, q_ptr: i64);
extern fn nuc_ba_get_cam(h: i64, i: i64, t_ptr: i64, q_ptr: i64);
extern fn nuc_ba_set_pt(h: i64, j: i64, p_ptr: i64);
extern fn nuc_ba_get_pt(h: i64, j: i64, p_ptr: i64);
extern fn nuc_ba_add_obs(h: i64, cam_i: i64, pt_j: i64,
    u_b: i64, v_b: i64, info_b: i64) -> i64;
extern fn nuc_ba_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64;
extern fn nuc_ba_total_cost(h: i64) -> i64;
extern fn nuc_ba_free(h: i64);

// Create an empty bundle adjustment problem with `n_cams` camera
// poses and `n_pts` 3D points, plus the shared pinhole intrinsics
// (focal length, principal point). All cameras start at identity
// pose and all points at the origin.
fn ba_new(n_cams: i64, n_pts: i64, focal_b: i64, cx_b: i64, cy_b: i64) -> i64 {
    return nuc_ba_new(n_cams, n_pts, focal_b, cx_b, cy_b);
}

// Set the initial pose for camera `i`. `t_ptr` is `double[3]`,
// `q_ptr` is `double[4]` (scalar-first quaternion w, x, y, z).
fn ba_set_cam(h: i64, i: i64, t_ptr: i64, q_ptr: i64) {
    nuc_ba_set_cam(h, i, t_ptr, q_ptr);
}

// Read back the refined pose for camera `i`.
fn ba_get_cam(h: i64, i: i64, t_ptr: i64, q_ptr: i64) {
    nuc_ba_get_cam(h, i, t_ptr, q_ptr);
}

// Set the initial 3D position for world point `j`. `p_ptr` is
// `double[3]`.
fn ba_set_pt(h: i64, j: i64, p_ptr: i64) {
    nuc_ba_set_pt(h, j, p_ptr);
}

// Read back the refined position for world point `j`.
fn ba_get_pt(h: i64, j: i64, p_ptr: i64) {
    nuc_ba_get_pt(h, j, p_ptr);
}

// Add a 2-D image observation: camera `cam_i` saw point `pt_j` at
// pixel (u, v). `info_b` is a scalar information weight (use 1.0
// if all observations have equal confidence; higher weights pull
// the solution more strongly toward those observations).
fn ba_add_obs(h: i64, cam_i: i64, pt_j: i64,
    u_b: i64, v_b: i64, info_b: i64) -> i64
{
    return nuc_ba_add_obs(h, cam_i, pt_j, u_b, v_b, info_b);
}

// Run Levenberg-Marquardt-damped Gauss-Newton iterations. Camera 0
// is gauge-fixed. Returns the number of iterations actually
// performed.
fn ba_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64 {
    return nuc_ba_optimize(h, max_iters, tol_b);
}

// Total reprojection cost (sum of squared pixel residuals weighted
// by per-observation info).
fn ba_total_cost(h: i64) -> i64 { return nuc_ba_total_cost(h); }

fn ba_free(h: i64) { nuc_ba_free(h); }
