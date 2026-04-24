// rods/sobel — Sobel edge gradient (3×3 kernels for x, y, and
// magnitude).
//
// Per-pixel x-gradient, y-gradient, and gradient magnitude
// `G = sqrt(Gx² + Gy²)` using the standard Sobel 3×3 stencils.
//
// Use:
//   - Edge-strength image for Canny / Hough downstream.
//   - Texture analysis.
//   - Visual-attention salience maps.
//
// Workflow:
//
//   import "stdlib/rods/sobel.nr"
//
//   // Pass 0 for any output you want to skip.
//   let _ = sobel(img_ptr, W, H,
//                  gx_out_ptr, gy_out_ptr, mag_out_ptr);
//
// Image and outputs are all `double[H*W]` row-major.
//
// **Limitations** (Scharr 3×3 / 5×5 Sobel / sub-pixel gradient
// direction land in v0.6 if needed):
// - Standard Sobel only (no Scharr).
// - Replicate boundary handling.
//
// See `stdlib/runtime/sobel_rt.c`.
#cfile "../runtime/sobel_rt.c"

extern fn nuc_sobel(img_ptr: i64, W_: i64, H_: i64,
    gx_out_ptr: i64, gy_out_ptr: i64, mag_out_ptr: i64) -> i64;

// Compute Sobel gradients. Pass 0 for any output to skip writing
// it. Returns 1 on success, 0 on bad input.
fn sobel(img_ptr: i64, W_: i64, H_: i64,
    gx_out_ptr: i64, gy_out_ptr: i64, mag_out_ptr: i64) -> i64
{
    return nuc_sobel(img_ptr, W_, H_, gx_out_ptr, gy_out_ptr, mag_out_ptr);
}
