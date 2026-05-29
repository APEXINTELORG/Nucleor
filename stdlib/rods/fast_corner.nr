// rods/fast_corner — FAST corner detector (Rosten & Drummond
// 2006). "Features from Accelerated Segment Test."
//
// For each pixel p, examines a 16-pixel Bresenham circle (radius
// 3 around p). p is a corner iff there exist 9 consecutive
// pixels on the circle ALL brighter than `I_p + threshold` or ALL
// darker than `I_p - threshold`.
//
// FAST is faster than Harris (no gradient computation, just pixel
// comparisons) but more sensitive to image noise. Standard
// front-end for ORB feature descriptors.
//
// Workflow:
//
//   import "stdlib/rods/fast_corner.nr"
//
//   let xy: [2 * MAX]double;
//   let score: [MAX]double;
//   let n = fast_corners(img_ptr, W, H,
//                         threshold_b, nms,
//                         MAX,
//                         f64_ptr(&xy[0]),
//                         f64_ptr(&score[0]));
//
// `nms = 1` enables 3×3 NMS on the score (sum of |circle - center|).
//
// Limitations (Bresenham radius is fixed at 3 / scale-space
// FAST land in v0.6 if needed):
// - Single-scale (caller pre-builds Gaussian pyramid via
//   `image_pyramid.nr` for multi-scale FAST).
// - Hard-coded N=9 segment length.
//
// See `stdlib/runtime/fast_corner_rt.c`.
#cfile "../runtime/fast_corner_rt.c"

extern fn nuc_fast_corners(img_ptr: i64, W_: i64, H_: i64,
    threshold_b: i64, nms_: i64,
    max_n_: i64, out_xy_ptr: i64, out_score_ptr: i64) -> i64;

// Detect FAST corners. Returns count written (≤ max_n).
fn fast_corners(img_ptr: i64, W_: i64, H_: i64,
    threshold_b: i64, nms_: i64,
    max_n_: i64, out_xy_ptr: i64, out_score_ptr: i64) -> i64
{
    return nuc_fast_corners(img_ptr, W_, H_, threshold_b, nms_,
        max_n_, out_xy_ptr, out_score_ptr);
}
