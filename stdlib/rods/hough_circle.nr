// rods/hough_circle — Hough transform for 2-D circle detection.
//
// Companion to `hough.nr` (lines). Each input edge point votes
// for every (cx, cy) on every candidate ring of radius R passing
// through it. Peaks in the 3-D `(cx × cy × R)` accumulator
// reveal circles.
//
// Use:
//   - Wheel / pillar detection in robotic perception.
//   - Coin / disc detection in CAD-like images.
//   - Pupil / iris detection in eye tracking.
//
// Workflow:
//
//   import "stdlib/rods/hough_circle.nr"
//
//   // out_circles: double[4*max_circles], packed (cx, cy, R, votes)
//   let n = hough_circles_2d(
//       pts_xy_ptr, n_pts,
//       cx_min_b, cx_max_b, n_cx,
//       cy_min_b, cy_max_b, n_cy,
//       R_min_b,  R_max_b,  n_R,
//       n_theta,
//       threshold,
//       max_circles,
//       out_circles_ptr);
//
// Limitations (gradient-direction voting / sub-pixel peak
// refinement / 21HT pre-screening land in v0.6 if needed):
// - Each (x, y) contributes uniformly along the ring per radius
//   (no edge-orientation pruning). For dense clouds this is
//   O(N · n_R · n_theta). Subsample edge points if needed.
// - Grid-quantized peak locations.
// - 2-D circles only.
//
// See `stdlib/runtime/hough_circle_rt.c`.
#cfile "../runtime/hough_circle_rt.c"

extern fn nuc_hough_circles_2d(pts_xy_ptr: i64, n_pts_: i64,
    cx_min_b: i64, cx_max_b: i64, n_cx_: i64,
    cy_min_b: i64, cy_max_b: i64, n_cy_: i64,
    R_min_b: i64,  R_max_b: i64,  n_R_: i64,
    n_theta_: i64,
    threshold_: i64,
    max_circles_: i64,
    out_circles_ptr: i64) -> i64;

// Detect circles. Returns count written (≤ max_circles_).
fn hough_circles_2d(pts_xy_ptr: i64, n_pts_: i64,
    cx_min_b: i64, cx_max_b: i64, n_cx_: i64,
    cy_min_b: i64, cy_max_b: i64, n_cy_: i64,
    R_min_b: i64,  R_max_b: i64,  n_R_: i64,
    n_theta_: i64,
    threshold_: i64,
    max_circles_: i64,
    out_circles_ptr: i64) -> i64
{
    return nuc_hough_circles_2d(pts_xy_ptr, n_pts_,
        cx_min_b, cx_max_b, n_cx_,
        cy_min_b, cy_max_b, n_cy_,
        R_min_b, R_max_b, n_R_,
        n_theta_, threshold_, max_circles_, out_circles_ptr);
}
