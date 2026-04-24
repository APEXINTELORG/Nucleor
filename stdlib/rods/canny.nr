// rods/canny — Canny edge detector (Canny 1986).
//
// 4-stage pipeline:
//   1. Sobel gradients (Gx, Gy, magnitude).
//   2. Non-maximum suppression along the gradient direction.
//   3. Double threshold: strong (>= high), weak (in [low, high)),
//      below low → suppressed.
//   4. Hysteresis: weak pixels survive iff 8-connected to a
//      strong pixel transitively.
//
// Output is a binary edge map (0 / 255 in the input domain).
//
// Workflow:
//
//   import "stdlib/rods/canny.nr"
//
//   let _ = canny(img_ptr, W, H,
//                  low_thr_b, high_thr_b,
//                  edges_out_ptr);
//
// Image and output are `double[H*W]` row-major.
//
// Tuning:
//   - low_thr ~= 0.4 × high_thr is a common ratio.
//   - For 8-bit images (0..255), high_thr around 100-200 works.
//
// **Limitations** (sub-pixel edge localization / scale-space
// edges land in v0.6 if needed):
// - 4-direction NMS (0°, 45°, 90°, 135°).
// - Single-scale.
//
// See `stdlib/runtime/canny_rt.c`.
#cfile "../runtime/canny_rt.c"

extern fn nuc_canny(img_ptr: i64, W_: i64, H_: i64,
    low_b: i64, high_b: i64, edges_out_ptr: i64) -> i64;

// Run the full Canny pipeline. Writes a binary edge map (0 or 255)
// to `edges_out_ptr`. Returns 1 on success, 0 on bad input.
fn canny(img_ptr: i64, W_: i64, H_: i64,
    low_b: i64, high_b: i64, edges_out_ptr: i64) -> i64
{
    return nuc_canny(img_ptr, W_, H_, low_b, high_b, edges_out_ptr);
}
