// rods/image_pyramid — Gaussian image pyramid (reduce / expand).
//
// Burt & Adelson 1983 multi-resolution image representation with
// the canonical 5-tap separable Gaussian `[1 4 6 4 1] / 16`.
//
// `pyramid_reduce` halves each dimension (blur + subsample).
// `pyramid_expand` doubles each dimension (upsample + blur ×4).
//
// Use:
//   - Coarse-to-fine Lucas-Kanade tracking (pair with `klt.nr`).
//   - Multi-scale Harris / ORB detection.
//   - Scale-invariant template matching.
//
// Workflow:
//
//   import "stdlib/rods/image_pyramid.nr"
//
//   // Level 1 (half): outW = ceil(W/2), outH = ceil(H/2).
//   let ok = pyramid_reduce(in_ptr, W, H, out_ptr);
//
//   // Expand back (or up by 2 for Laplacian pyramids).
//   let ok2 = pyramid_expand(in_ptr, W_small, H_small,
//                             W_big, H_big, out_ptr);
//
// Input and output images are `double[H*W]` row-major in [0, 255].
//
// Limitations (SIFT scale-space DoG / orientation assignment /
// SIMD stride land in v0.6 if needed):
// - Double-precision internal representation.
// - Replicate-at-edge boundary handling.
// - Reduce target size is `ceil(W/2), ceil(H/2)`.
//
// See `stdlib/runtime/image_pyramid_rt.c`.
#cfile "../runtime/image_pyramid_rt.c"

extern fn nuc_pyramid_reduce(in_ptr: i64, W_: i64, H_: i64,
    out_ptr: i64) -> i64;
extern fn nuc_pyramid_expand(in_ptr: i64, W_: i64, H_: i64,
    outW_: i64, outH_: i64, out_ptr: i64) -> i64;

// Halve each dimension. Caller provides `out_ptr` sized
// `ceil(W/2) * ceil(H/2)` doubles.
fn pyramid_reduce(in_ptr: i64, W_: i64, H_: i64, out_ptr: i64) -> i64 {
    return nuc_pyramid_reduce(in_ptr, W_, H_, out_ptr);
}

// Upsample input of size `W × H` into a new image of size
// `outW × outH` using zero-insertion + Gaussian blur ×4.
fn pyramid_expand(in_ptr: i64, W_: i64, H_: i64,
    outW_: i64, outH_: i64, out_ptr: i64) -> i64
{
    return nuc_pyramid_expand(in_ptr, W_, H_, outW_, outH_, out_ptr);
}
