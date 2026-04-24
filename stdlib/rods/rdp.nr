// rods/rdp — Ramer-Douglas-Peucker polyline simplification.
//
// Given an N-point polyline in D-dimensional space, returns a
// simplified polyline (as a kept-point mask) such that no dropped
// point is farther than `ε` from the piecewise-linear approximation
// formed by the kept points.
//
// Classic recursive algorithm (iterative implementation to avoid
// deep C stack):
//   simplify(lo, hi, ε):
//     find the point in (lo, hi) with max perpendicular distance
//     to segment pts[lo] → pts[hi]
//     if max_dist ≤ ε: drop all interior points
//     else: keep argmax; recurse on left and right subsegments
//
// Endpoints are always kept.
//
// Workflow:
//
//   import "stdlib/rods/rdp.nr"
//
//   // pts: caller-allocated double[N*dim] (interleaved).
//   // keep_out: i64[N] — filled with 1 (kept) or 0 (dropped).
//   let count = rdp_simplify(pts_ptr, n, dim, epsilon_b, keep_out_ptr);
//
// Use cases:
//   - GPS / odometry trace compaction.
//   - Path simplification after RRT / A* (removes redundant collinear
//     waypoints for a cleaner executor-facing trajectory).
//   - 2D / 3D polyline rendering LOD.
//
// **Limitations** (Visvalingam-Whyatt / curvature-aware variants
// land in v0.6 if needed):
// - Euclidean perpendicular-to-segment distance only.
//
// See `stdlib/runtime/rdp_rt.c`.
#cfile "../runtime/rdp_rt.c"

extern fn nuc_rdp_simplify(pts_ptr: i64, n: i64, dim: i64,
    epsilon_b: i64, keep_out_ptr: i64) -> i64;

// Simplify a polyline. `keep_out_ptr` is `i64[n]`; filled with 1
// for kept points, 0 for dropped. Endpoints always kept. Returns
// the kept-point count.
fn rdp_simplify(pts_ptr: i64, n: i64, dim: i64,
    epsilon_b: i64, keep_out_ptr: i64) -> i64
{
    return nuc_rdp_simplify(pts_ptr, n, dim, epsilon_b, keep_out_ptr);
}
