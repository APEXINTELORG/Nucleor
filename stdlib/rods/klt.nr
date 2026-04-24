// rods/klt — Lucas-Kanade single-feature tracker.
//
// Given two grayscale images `I1`, `I2` and a feature point in
// `I1`, find the displacement `(dx, dy)` such that the windowed
// neighborhood of the feature in `I1` matches the displaced
// neighborhood in `I2`.
//
// Standard Newton-Lucas-Kanade iteration:
//
//   H · Δ = −b
//   H = [[Σ Ix², Σ Ix·Iy], [Σ Ix·Iy, Σ Iy²]]   (over window in I1)
//   b = [Σ Ix·It, Σ Iy·It]                      (It = I2(warped) − I1)
//
// Sub-pixel image access uses bilinear interpolation. Boundary
// handling: replicate.
//
// Workflow:
//
//   import "stdlib/rods/klt.nr"
//
//   // I1, I2 are caller-allocated double[H * W] grayscale.
//   // dx_dy_out is double[2]; pass initial guess (e.g. 0, 0) on entry.
//   let dx_dy: double[2] = (0.0, 0.0);   // initial guess
//   let ok = klt_track(I1_ptr, I2_ptr, W, H,
//                       feature_x_b, feature_y_b,
//                       window_radius, max_iters, tol_b,
//                       dx_dy_out_ptr);
//
// For displacements > a few pixels, build an image pyramid via
// `imgproc_resize_bilinear` and call this iteratively coarse-to-
// fine.
//
// **Limitations** (multi-scale pyramid / multi-feature parallel
// tracking / orientation tracking land in v0.6 if needed):
// - Single feature per call.
// - Translation only — no scale / rotation / affine warp.
//
// See `stdlib/runtime/klt_rt.c`.
#cfile "../runtime/klt_rt.c"

extern fn nuc_klt_track(img1_ptr: i64, img2_ptr: i64,
    W: i64, H: i64,
    fx_b: i64, fy_b: i64,
    radius: i64, max_iters: i64,
    tol_b: i64,
    dx_dy_out_ptr: i64) -> i64;

// Track a single feature from `I1` to `I2`. Returns 1 on success
// (writes refined displacement to `dx_dy_out_ptr`), 0 if the
// Hessian became singular at any iteration (typically a flat /
// textureless region).
fn klt_track(img1_ptr: i64, img2_ptr: i64, W: i64, H: i64,
    fx_b: i64, fy_b: i64, radius: i64, max_iters: i64, tol_b: i64,
    dx_dy_out_ptr: i64) -> i64
{
    return nuc_klt_track(img1_ptr, img2_ptr, W, H, fx_b, fy_b,
        radius, max_iters, tol_b, dx_dy_out_ptr);
}
