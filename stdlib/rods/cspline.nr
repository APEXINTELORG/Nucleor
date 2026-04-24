// rods/cspline — Natural cubic spline interpolation through
// caller-supplied waypoints `(x_0, y_0), …, (x_N, y_N)`.
//
// Builds N segments, each a cubic polynomial in `(x − x_k)`, with
// continuous first and second derivatives at every internal
// waypoint. "Natural" boundary conditions: `y''(x_0) = y''(x_N) = 0`.
//
// Use cases:
//   - Smooth trajectory through joint waypoints (one spline per joint).
//   - Smooth trajectory through Cartesian waypoints (one per axis).
//   - Smoothing of measured time series for derivative estimation.
//
// Compare to:
//   - `qtraj.nr` — minimum-snap (4th-derivative-bounded), 7th-degree
//     per segment; for quadrotors and other differentially-flat
//     systems where snap matters.
//   - `bspline.nr` — general degree-k B-splines with explicit
//     control points and knot vectors.
//   - `cspline.nr` (this rod) — simplest "smooth fit through
//     waypoints" primitive, no extra control-point machinery.
//
// Workflow:
//
//   import "stdlib/rods/cspline.nr"
//
//   let s = cspline_new(n_waypoints);
//   for k in 0..n_waypoints {
//       cspline_set_waypoint(s, k, x_b, y_b);
//   }
//   cspline_solve(s);    // returns 0 if x is not strictly increasing
//
//   for tick {
//       let y_b   = cspline_eval(s, x_b);
//       let yp_b  = cspline_eval_derivative(s, x_b);
//       let ypp_b = cspline_eval_second_derivative(s, x_b);
//   }
//   cspline_free(s);
//
// **Limitations** (clamped / periodic / parametric C2 splines land
// in v0.6 if needed):
// - 1-D y over 1-D x only — call N times for N-dimensional trajectories.
// - Natural BC only (`y''(x_0) = y''(x_N) = 0`).
// - Caller must keep waypoints in strictly increasing x order.
//
// See `stdlib/runtime/cspline_rt.c`.
#cfile "../runtime/cspline_rt.c"

extern fn nuc_cspline_new(n_waypoints: i64) -> i64;
extern fn nuc_cspline_set_waypoint(h: i64, k: i64, x_b: i64, y_b: i64);
extern fn nuc_cspline_solve(h: i64) -> i64;
extern fn nuc_cspline_eval(h: i64, x_b: i64) -> i64;
extern fn nuc_cspline_eval_derivative(h: i64, x_b: i64) -> i64;
extern fn nuc_cspline_eval_second_derivative(h: i64, x_b: i64) -> i64;
extern fn nuc_cspline_free(h: i64);

fn cspline_new(n_waypoints: i64) -> i64 { return nuc_cspline_new(n_waypoints); }

fn cspline_set_waypoint(h: i64, k: i64, x_b: i64, y_b: i64) {
    nuc_cspline_set_waypoint(h, k, x_b, y_b);
}

// Solve the tridiagonal system for second derivatives. Returns 1
// on success, 0 if the x sequence isn't strictly increasing.
fn cspline_solve(h: i64) -> i64 { return nuc_cspline_solve(h); }

// Evaluate the spline at x. Out-of-range x is extrapolated using
// the boundary segment's cubic.
fn cspline_eval(h: i64, x_b: i64) -> i64 { return nuc_cspline_eval(h, x_b); }

fn cspline_eval_derivative(h: i64, x_b: i64) -> i64 {
    return nuc_cspline_eval_derivative(h, x_b);
}
fn cspline_eval_second_derivative(h: i64, x_b: i64) -> i64 {
    return nuc_cspline_eval_second_derivative(h, x_b);
}

fn cspline_free(h: i64) { nuc_cspline_free(h); }
