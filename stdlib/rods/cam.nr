// rods/cam — Pinhole camera with Brown-Conrady (radial-tangential)
// distortion. Project world points → pixels and unproject pixels +
// depth → world points.
//
// Camera intrinsics:
//   K = [[fx,  0, cx],
//        [ 0, fy, cy],
//        [ 0,  0,  1]]
//
// Brown-Conrady distortion (5 params, k₁ k₂ k₃ p₁ p₂):
//   x_d = x_n · (1 + k₁ r² + k₂ r⁴ + k₃ r⁶)
//        + 2 p₁ x_n y_n + p₂ (r² + 2 x_n²)
//   y_d = y_n · (1 + k₁ r² + k₂ r⁴ + k₃ r⁶)
//        + p₁ (r² + 2 y_n²) + 2 p₂ x_n y_n
//
// Pose `(t, q)` is the camera frame in the world (so a world point
// `P` maps to camera frame as `X_cam = qᵀ · (P − t)`). Same
// convention as `ba.nr`'s bundle-adjustment camera.
//
// Workflow:
//
//   import "stdlib/rods/cam.nr"
//
//   let h = cam_new(fx_b, fy_b, cx_b, cy_b);
//   cam_set_distortion(h, k1_b, k2_b, k3_b, p1_b, p2_b);
//   cam_set_pose(h, t_ptr, q_ptr);   // double[3], double[4]
//
//   // Project world point P_w (double[3]) to pixel (double[2]):
//   let ok = cam_project(h, P_w_ptr, uv_out_ptr);
//
//   // Unproject undistorted pixel + depth to world point:
//   cam_unproject(h, u_b, v_b, depth_b, P_out_ptr);
//
//   // Distortion test on a normalized point:
//   cam_distort(h, xn_b, yn_b, distorted_out_ptr);
//
//   // 3×3 K matrix:
//   cam_intrinsic_matrix(h, K_out_ptr);   // double[9], row-major
//
//   cam_free(h);
//
// **Limitations** (fish-eye / equidistant / equirectangular
// projections / iterative inverse-distortion land in v0.6 if needed):
// - Single rectilinear pinhole + Brown-Conrady distortion.
// - `unproject` does NOT undistort — caller must feed already-
//   rectified pixels. Inverse distortion needs an iterative
//   root-find (planned for v0.6).
//
// See `stdlib/runtime/cam_rt.c`.
#cfile "../runtime/cam_rt.c"

extern fn nuc_cam_new(fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64) -> i64;
extern fn nuc_cam_set_distortion(h: i64, k1_b: i64, k2_b: i64, k3_b: i64,
    p1_b: i64, p2_b: i64);
extern fn nuc_cam_set_pose(h: i64, t_ptr: i64, q_ptr: i64);
extern fn nuc_cam_intrinsic_matrix(h: i64, K_out_ptr: i64);
extern fn nuc_cam_project(h: i64, P_w_ptr: i64, uv_out_ptr: i64) -> i64;
extern fn nuc_cam_unproject(h: i64, u_b: i64, v_b: i64, depth_b: i64, P_out_ptr: i64);
extern fn nuc_cam_distort(h: i64, xn_b: i64, yn_b: i64, out_ptr: i64);
extern fn nuc_cam_free(h: i64);

fn cam_new(fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64) -> i64 {
    return nuc_cam_new(fx_b, fy_b, cx_b, cy_b);
}

fn cam_set_distortion(h: i64, k1_b: i64, k2_b: i64, k3_b: i64, p1_b: i64, p2_b: i64) {
    nuc_cam_set_distortion(h, k1_b, k2_b, k3_b, p1_b, p2_b);
}

fn cam_set_pose(h: i64, t_ptr: i64, q_ptr: i64) {
    nuc_cam_set_pose(h, t_ptr, q_ptr);
}

// Write the 3×3 K matrix (row-major) to a caller-allocated double[9].
fn cam_intrinsic_matrix(h: i64, K_out_ptr: i64) {
    nuc_cam_intrinsic_matrix(h, K_out_ptr);
}

// Project a 3-D world point. Writes (u, v) to uv_out_ptr (double[2]).
// Returns 1 on success, 0 if the point is behind the camera.
fn cam_project(h: i64, P_w_ptr: i64, uv_out_ptr: i64) -> i64 {
    return nuc_cam_project(h, P_w_ptr, uv_out_ptr);
}

// Unproject a pixel + depth to a world point (double[3] out).
// Caller must feed UNDISTORTED pixels.
fn cam_unproject(h: i64, u_b: i64, v_b: i64, depth_b: i64, P_out_ptr: i64) {
    nuc_cam_unproject(h, u_b, v_b, depth_b, P_out_ptr);
}

// Apply the distortion model to a normalized point (xn, yn). Writes
// (xd, yd) to out_ptr (double[2]).
fn cam_distort(h: i64, xn_b: i64, yn_b: i64, out_ptr: i64) {
    nuc_cam_distort(h, xn_b, yn_b, out_ptr);
}

fn cam_free(h: i64) { nuc_cam_free(h); }
