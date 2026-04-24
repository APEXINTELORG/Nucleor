// rods/reeds_shepp — Reeds-Shepp shortest paths (Reeds & Shepp
// 1990). Car-like robot with minimum turning radius that can also
// MOVE IN REVERSE. Companion to `dubins.nr` (which is forward-only).
//
// Given `(x0, y0, θ0)`, `(x1, y1, θ1)`, and minimum turning
// radius `R`, returns the length of the shortest path.
//
// Algorithm walks 9 base word families (CSC, CCC, CCCC, CCSC,
// CCSCC variants) × 4 symmetry transforms (timeflip, reflect,
// both, identity) = 36 candidate paths (some degenerate), and
// picks the minimum. This matches OMPL's classical structure.
//
// Workflow:
//
//   import "stdlib/rods/reeds_shepp.nr"
//
//   let len: double;
//   let ok = reeds_shepp_length(x0_b, y0_b, th0_b,
//                                x1_b, y1_b, th1_b,
//                                R_b,
//                                f64_ptr(&len));
//
// **Limitations** (path sampling / smoothing / lateral-acceleration
// constraints land in v0.6 if needed):
// - Returns length only (no sampled poses along the path).
// - Constant curvature on turns; caller smooths cusps if needed.
//
// See `stdlib/runtime/reeds_shepp_rt.c`.
#cfile "../runtime/reeds_shepp_rt.c"

extern fn nuc_reeds_shepp_length(
    x0_b: i64, y0_b: i64, th0_b: i64,
    x1_b: i64, y1_b: i64, th1_b: i64,
    R_b: i64, length_out_ptr: i64) -> i64;

// Compute the Reeds-Shepp shortest path length between start and
// goal poses for a car-like robot with minimum turning radius R
// that can move in both forward and reverse. Returns 1 on success,
// 0 on bad input. Length written to `length_out_ptr`.
fn reeds_shepp_length(
    x0_b: i64, y0_b: i64, th0_b: i64,
    x1_b: i64, y1_b: i64, th1_b: i64,
    R_b: i64, length_out_ptr: i64) -> i64
{
    return nuc_reeds_shepp_length(x0_b, y0_b, th0_b,
        x1_b, y1_b, th1_b, R_b, length_out_ptr);
}
