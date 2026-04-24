// rods/hough — 2D Hough transform for line detection.
//
// Each input point votes for the family of lines passing through
// it, parameterized by `(ρ, θ)`:
//
//   ρ = x cos θ + y sin θ,   θ ∈ [0, π),  ρ ∈ [−ρ_max, ρ_max]
//
// The accumulator is an `n_rho × n_theta` vote grid; peaks
// correspond to lines with many supporting input points.
//
// `hough_lines_2d` is a one-call wrapper that builds the
// accumulator, applies non-maximum suppression in a 3×3 window,
// and returns the top `max_lines` peaks whose vote count meets
// `threshold`.
//
// Workflow:
//
//   import "stdlib/rods/hough.nr"
//
//   // pts: double[N * 2] (interleaved xy)
//   let out_rho:   double[MAX];
//   let out_theta: double[MAX];
//   let count = hough_lines_2d(pts_ptr, n_pts,
//                               n_rho, n_theta,
//                               rho_max_b, threshold,
//                               max_lines,
//                               out_rho_ptr, out_theta_ptr);
//
// Use cases:
//   - Laser-scan landmark extraction (walls, corridor segments).
//   - Structured-environment SLAM front-end.
//   - Dominant-line extraction from 2-D feature maps.
//
// **Limitations** (probabilistic / circle / 3D / weighted-voting
// Hough variants land in v0.6 if needed):
// - Each point contributes 1 vote per θ-bin.
// - Grid-quantized peak locations (no sub-bin refinement).
// - 2D lines only.
//
// See `stdlib/runtime/hough_rt.c`.
#cfile "../runtime/hough_rt.c"

extern fn nuc_hough_lines_2d(pts_ptr: i64, n_pts: i64,
    n_rho: i64, n_theta: i64,
    rho_max_b: i64, threshold: i64, max_lines: i64,
    out_rho_ptr: i64, out_theta_ptr: i64) -> i64;

// Detect lines in a 2-D point cloud via Hough transform.
// Returns count of lines found (≤ max_lines).
fn hough_lines_2d(pts_ptr: i64, n_pts: i64,
    n_rho: i64, n_theta: i64,
    rho_max_b: i64, threshold: i64, max_lines: i64,
    out_rho_ptr: i64, out_theta_ptr: i64) -> i64
{
    return nuc_hough_lines_2d(pts_ptr, n_pts, n_rho, n_theta,
        rho_max_b, threshold, max_lines,
        out_rho_ptr, out_theta_ptr);
}
