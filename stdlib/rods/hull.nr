// rods/hull — 2D convex hull (Andrew's monotone chain).
//
// Given a 2D point cloud, returns the indices (in CCW order) of
// the points that form the convex hull. O(N log N) via sort-then-
// scan.
//
// Foundation for:
// - Grasp wrench space construction (convex hull of contact-force
//   generators).
// - Object bounding-shape extraction from depth scans.
// - Collision broad-phase precomputation (replace mesh with hull).
//
// Workflow:
//   // pts is double[N * 2]; hull_out_indices is int[N] (worst case).
//   let n_hull = hull_2d(pts_ptr, n_pts, hull_out_indices_ptr);
//   let area = hull_2d_area(pts_ptr, n_pts, hull_out_indices_ptr, n_hull);
//
// See `stdlib/runtime/hull_rt.c`.
#cfile "../runtime/hull_rt.c"

extern fn nuc_hull_2d(pts_ptr: i64, n_pts: i64, hull_out_indices_ptr: i64) -> i64;
extern fn nuc_hull_2d_area(pts_ptr: i64, n_pts: i64,
    hull_indices_ptr: i64, n_hull: i64) -> i64;

// Compute the 2D convex hull. `pts_ptr` is `double[n_pts * 2]`,
// `hull_out_indices_ptr` is `int[n_pts]` (worst case, all points
// on the hull). Returns the number of hull points.
fn hull_2d(pts_ptr: i64, n_pts: i64, hull_out_indices_ptr: i64) -> i64 {
    return nuc_hull_2d(pts_ptr, n_pts, hull_out_indices_ptr);
}

// Compute the area enclosed by the convex hull (shoelace formula).
// Returned as bit-cast f64.
fn hull_2d_area(pts_ptr: i64, n_pts: i64,
    hull_indices_ptr: i64, n_hull: i64) -> i64
{
    return nuc_hull_2d_area(pts_ptr, n_pts, hull_indices_ptr, n_hull);
}
