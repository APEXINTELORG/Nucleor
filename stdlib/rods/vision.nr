// rods/vision — Camera-projection primitives for robotics vision.
//
// Standard pinhole model. Foundation for:
// - Hand-eye calibration (relate the camera frame to the robot
//   end-effector frame via observed feature poses).
// - Image-based visual servoing (v0.2.225).
// - Object pose estimation against a CAD-model point cloud +
//   observed pixel locations.
//
// Workflow:
//   // K is a 9-double row-major intrinsics buffer; fill it via
//   // cam_intrinsics_set or by hand.
//   cam_intrinsics_set(K_ptr, fx_b, fy_b, cx_b, cy_b);
//
//   // Project a single 3D world point (x, y, z) to pixel (u, v).
//   // R is double[9], t is double[3] — the world→camera transform.
//   cam_project(K_ptr, R_ptr, t_ptr, X_ptr, uv_out_ptr);
//
//   // Or batch-project N points.
//   cam_project_batch(K_ptr, R_ptr, t_ptr, X_ptr, N, uv_out_ptr);
//
//   // Image (interaction) Jacobian for a feature at normalized
//   // image coords (x, y) and depth Z — needed by IBVS.
//   cam_image_jacobian(x_b, y_b, Z_b, L_out_ptr);
//
// **Limitations**:
// - Pinhole only — assumes pre-undistorted pixel coordinates.
//   Real lens distortion (Brown-Conrady, fisheye) lands in v0.6
//   if needed; typical camera drivers undistort upstream.
// - No camera-pose estimation primitives (PnP, P3P) — those land
//   alongside hand-eye calibration in v0.6.
//
// See `stdlib/runtime/vision_rt.c`.
#cfile "../runtime/vision_rt.c"

extern fn nuc_cam_intrinsics_set(K_ptr: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64) -> i64;

extern fn nuc_cam_project(K_ptr: i64,
    R_ptr: i64, t_ptr: i64,
    X_ptr: i64, uv_out_ptr: i64) -> i64;

extern fn nuc_cam_project_batch(K_ptr: i64,
    R_ptr: i64, t_ptr: i64,
    X_ptr: i64, N: i64, uv_out_ptr: i64) -> i64;

extern fn nuc_cam_image_jacobian(
    x_b: i64, y_b: i64, Z_b: i64, L_out_ptr: i64) -> i64;

// Fill a `double[9]` intrinsics matrix (row-major) with the
// standard pinhole layout: K = [[fx, 0, cx], [0, fy, cy], [0, 0, 1]].
fn cam_intrinsics_set(K_ptr: i64,
    fx_b: i64, fy_b: i64, cx_b: i64, cy_b: i64) -> i64
{
    return nuc_cam_intrinsics_set(K_ptr, fx_b, fy_b, cx_b, cy_b);
}

// Project a single 3D world point to pixel coords. Returns 1 on
// success (point in front of camera), 0 if behind. R is a
// `double[9]` row-major rotation; t is `double[3]` translation;
// X is `double[3]` (the world point); uv_out is `double[2]`.
fn cam_project(K_ptr: i64, R_ptr: i64, t_ptr: i64,
    X_ptr: i64, uv_out_ptr: i64) -> i64
{
    return nuc_cam_project(K_ptr, R_ptr, t_ptr, X_ptr, uv_out_ptr);
}

// Batch project N 3D points. Writes (NaN, NaN) for points behind
// the camera. Returns the number of points successfully projected.
fn cam_project_batch(K_ptr: i64, R_ptr: i64, t_ptr: i64,
    X_ptr: i64, N: i64, uv_out_ptr: i64) -> i64
{
    return nuc_cam_project_batch(K_ptr, R_ptr, t_ptr, X_ptr, N, uv_out_ptr);
}

// Image (interaction) Jacobian L (2×6, row-major) for a single
// feature point at normalized image coords (x, y) and depth Z
// (camera frame). Used by image-based visual servoing:
//
//     [ẋ; ẏ] = L · v_cam   where v_cam = (vx, vy, vz, ωx, ωy, ωz)
//
// L = [-1/Z, 0, x/Z, xy, -(1+x²), y; 0, -1/Z, y/Z, 1+y², -xy, -x].
// (x, y) are NORMALIZED image coordinates (raw pixel after
// subtracting principal point and dividing by focal length).
fn cam_image_jacobian(x_b: i64, y_b: i64, Z_b: i64,
    L_out_ptr: i64) -> i64
{
    return nuc_cam_image_jacobian(x_b, y_b, Z_b, L_out_ptr);
}
