// rods/harris — Harris corner detector (Harris & Stephens 1988).
//
// For each pixel, computes the Harris response
//
//   R = det(M) − k · trace(M)²
//
// where M is the 3×3-windowed structure tensor of image
// gradients. Pixels above threshold AND 3×3 local maxima are
// reported as corners.
//
// Use:
//   - Visual-odometry feature seeds.
//   - Calibration target detection.
//   - Front-end for KLT (`klt.nr`).
//
// Workflow:
//
//   import "stdlib/rods/harris.nr"
//
//   let out_xy: [2 * MAX]double;
//   let out_resp: [MAX]double;
//   let n = harris_corners(img_ptr, W, H,
//                           k_b, threshold_b, MAX,
//                           f64_ptr(&out_xy[0]),
//                           f64_ptr(&out_resp[0]));
//
// Image is `double[H*W]` row-major in [0, 255]. Returned corners
// are sorted by response descending.
//
// **Limitations** (Shi-Tomasi response / sub-pixel refinement /
// scale-space (multi-scale Harris) land in v0.6 if needed):
// - Single-scale (caller pre-builds Gaussian pyramid via
//   `image_pyramid.nr` for multi-scale).
// - Fixed 3×3 box window (no Gaussian weighting).
// - Central-difference gradients.
//
// See `stdlib/runtime/harris_rt.c`.
#cfile "../runtime/harris_rt.c"

extern fn nuc_harris_corners(img_ptr: i64, W_: i64, H_: i64,
    k_b: i64, threshold_b: i64,
    max_n_: i64, out_xy_ptr: i64, out_resp_ptr: i64) -> i64;

// Detect Harris corners. Returns count written (≤ max_n).
// `k_b` is the Harris constant (typical 0.04).
// `out_xy` packs (x, y) interleaved as doubles; `out_resp` holds
// the per-corner response value.
fn harris_corners(img_ptr: i64, W_: i64, H_: i64,
    k_b: i64, threshold_b: i64,
    max_n_: i64, out_xy_ptr: i64, out_resp_ptr: i64) -> i64
{
    return nuc_harris_corners(img_ptr, W_, H_, k_b, threshold_b,
        max_n_, out_xy_ptr, out_resp_ptr);
}
