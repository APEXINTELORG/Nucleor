// rods/imgproc — Basic image processing primitives on grayscale
// images (caller-allocated `double[H * W]`, row-major).
//
// All functions take input pointer, output pointer, width, height
// and per-function parameters. Output buffer is the same size as
// input (except `imgproc_resize_bilinear`). Boundary handling:
// edge-pixel replication.
//
// Provides:
//   - Sobel X / Y gradient
//   - Gradient magnitude `sqrt(Gx² + Gy²)`
//   - Box filter (mean of `(2r+1)²` window)
//   - Separable Gaussian blur
//   - Bilinear resize
//
// Foundation for vision pipelines: edge detection, feature pre-
// processing, image pyramids for KLT / Lucas-Kanade tracking
// (which lands in v0.6 alongside the actual feature tracker).
//
// Pixels are doubles in arbitrary range — caller decides `[0, 1]`,
// `[0, 255]`, or anything else.
//
// Workflow:
//
//   import "stdlib/rods/imgproc.nr"
//
//   // sobel x:
//   imgproc_sobel_x(in_ptr, out_ptr, W, H);
//
//   // gradient magnitude:
//   imgproc_gradient_magnitude(in_ptr, out_ptr, W, H);
//
//   // gaussian blur:
//   imgproc_blur_gaussian(in_ptr, out_ptr, W, H, sigma_b, radius);
//
//   // resize:
//   imgproc_resize_bilinear(in_ptr, in_W, in_H, out_ptr, out_W, out_H);
//
// **Limitations** (color / multi-channel / FFT-based filters /
// pyramids land in v0.6 if needed):
// - Grayscale only (call once per channel for color).
// - Sobel is fixed 3×3 (no Scharr / larger kernels).
// - Gaussian uses caller-supplied radius (use `radius ≈ 3·σ`).
//
// See `stdlib/runtime/imgproc_rt.c`.
#cfile "../runtime/imgproc_rt.c"

extern fn nuc_img_sobel_x(in_ptr: i64, out_ptr: i64, W: i64, H: i64);
extern fn nuc_img_sobel_y(in_ptr: i64, out_ptr: i64, W: i64, H: i64);
extern fn nuc_img_gradient_magnitude(in_ptr: i64, out_ptr: i64, W: i64, H: i64);
extern fn nuc_img_box_filter(in_ptr: i64, out_ptr: i64, W: i64, H: i64, radius: i64);
extern fn nuc_img_blur_gaussian(in_ptr: i64, out_ptr: i64, W: i64, H: i64,
    sigma_b: i64, radius: i64);
extern fn nuc_img_resize_bilinear(in_ptr: i64, in_W: i64, in_H: i64,
    out_ptr: i64, out_W: i64, out_H: i64);

// 3×3 Sobel x-gradient. Output buffer must be `double[H*W]`,
// pre-allocated by caller.
fn imgproc_sobel_x(in_ptr: i64, out_ptr: i64, W: i64, H: i64) {
    nuc_img_sobel_x(in_ptr, out_ptr, W, H);
}
fn imgproc_sobel_y(in_ptr: i64, out_ptr: i64, W: i64, H: i64) {
    nuc_img_sobel_y(in_ptr, out_ptr, W, H);
}

// `sqrt(Gx² + Gy²)` per pixel (uses two internal temp buffers).
fn imgproc_gradient_magnitude(in_ptr: i64, out_ptr: i64, W: i64, H: i64) {
    nuc_img_gradient_magnitude(in_ptr, out_ptr, W, H);
}

// Box (mean) filter with `(2*radius+1)²` window.
fn imgproc_box_filter(in_ptr: i64, out_ptr: i64, W: i64, H: i64, radius: i64) {
    nuc_img_box_filter(in_ptr, out_ptr, W, H, radius);
}

// Separable Gaussian blur. `sigma_b` is the Gaussian std-dev;
// `radius` is the half-window size (use `~3·σ` for accurate results).
fn imgproc_blur_gaussian(in_ptr: i64, out_ptr: i64, W: i64, H: i64,
    sigma_b: i64, radius: i64)
{
    nuc_img_blur_gaussian(in_ptr, out_ptr, W, H, sigma_b, radius);
}

// Bilinear-interpolated resize. Output buffer is `double[out_H*out_W]`.
fn imgproc_resize_bilinear(in_ptr: i64, in_W: i64, in_H: i64,
    out_ptr: i64, out_W: i64, out_H: i64)
{
    nuc_img_resize_bilinear(in_ptr, in_W, in_H, out_ptr, out_W, out_H);
}
