// rods/cubicspline — Natural cubic spline interpolation through
// N waypoints. C² piecewise-cubic curve fitting.
//
// Two-call API:
//   1. `cubicspline_fit(xs, ys, n, y2_out)` — pre-computes the
//      second-derivative table.
//   2. `cubicspline_sample(xs, ys, y2, n, x, out)` — sample y(x).
//
// Use:
//   - Path smoothing through waypoints (xs = arc-length, ys =
//     pose component).
//   - Sensor calibration table interpolation.
//   - Visualization curve fitting.
//
// Workflow:
//
//   import "stdlib/rods/cubicspline.nr"
//
//   // xs, ys are double[N] inputs. y2 is double[N] output buffer.
//   let _ = cubicspline_fit(xs_ptr, ys_ptr, N, y2_ptr);
//
//   let y: double;
//   let _ = cubicspline_sample(xs_ptr, ys_ptr, y2_ptr, N,
//                                x_b, f64_ptr(&y));
//
// **Limitations** (clamped / not-a-knot / monotone Hermite
// boundary conditions land in v0.6 if needed):
// - "Natural" boundary only (y'' = 0 at both endpoints → tangent
//   line at edges).
// - O(log N) sample via binary search; ok for ≤ 10K knots.
// - Requires strictly increasing xs (returns 0 otherwise).
//
// See `stdlib/runtime/cubicspline_rt.c`.
#cfile "../runtime/cubicspline_rt.c"

extern fn nuc_cubicspline_fit(xs_ptr: i64, ys_ptr: i64, n_: i64,
    y2_out_ptr: i64) -> i64;
extern fn nuc_cubicspline_sample(xs_ptr: i64, ys_ptr: i64,
    y2_ptr: i64, n_: i64, x_b: i64, out_ptr: i64) -> i64;

// Pre-compute the second-derivative table. Returns 1 on success,
// 0 if N<2 or xs not strictly increasing.
fn cubicspline_fit(xs_ptr: i64, ys_ptr: i64, n_: i64,
    y2_out_ptr: i64) -> i64
{
    return nuc_cubicspline_fit(xs_ptr, ys_ptr, n_, y2_out_ptr);
}

// Sample y at x. Returns 1 on success, writes f64 to out_ptr.
fn cubicspline_sample(xs_ptr: i64, ys_ptr: i64,
    y2_ptr: i64, n_: i64, x_b: i64, out_ptr: i64) -> i64
{
    return nuc_cubicspline_sample(xs_ptr, ys_ptr, y2_ptr, n_,
        x_b, out_ptr);
}
