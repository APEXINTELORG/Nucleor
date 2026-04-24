// rods/delaunay — 2-D Delaunay triangulation + circumcenter helper.
//
// Bowyer-Watson incremental insertion (Bowyer 1981 / Watson 1981).
// Foundation for:
//   - **Voronoi diagrams** (the dual): each Voronoi vertex IS a
//     Delaunay-triangle circumcenter; each Voronoi edge connects
//     circumcenters of adjacent triangles. Use the
//     `circumcenter_2d` helper to lift triangles into Voronoi
//     vertices.
//   - Triangle-mesh generation for FEM.
//   - Natural-neighbor interpolation.
//   - Voronoi-graph path planning.
//
// Workflow:
//
//   import "stdlib/rods/delaunay.nr"
//
//   // out_tris: int32[3 * max_tris], packed (i, j, k) per triangle.
//   let n_tris = delaunay_2d(pts_xy_ptr, n_pts,
//                              out_tris_ptr, max_tris);
//
//   // Lift one triangle into a Voronoi vertex.
//   let cx: double; let cy: double;
//   let ok = circumcenter_2d(ax_b, ay_b, bx_b, by_b, cx_b, cy_b,
//                             f64_ptr(&cx), f64_ptr(&cy));
//
// **Limitations** (sweep-line / 3-D Delaunay / robust predicates
// land in v0.6 if needed):
// - 2-D only.
// - Naive O(N²) incremental insertion. Fine up to ~1000 points.
// - Floating-point arithmetic — for cocircular degeneracies, an
//   arbitrary-but-valid choice between equivalent triangulations
//   is made.
//
// See `stdlib/runtime/delaunay_rt.c`.
#cfile "../runtime/delaunay_rt.c"

extern fn nuc_delaunay_2d(pts_xy_ptr: i64, n_pts_: i64,
    out_tris_ptr: i64, max_tris_: i64) -> i64;
extern fn nuc_circumcenter_2d(ax_b: i64, ay_b: i64,
    bx_b: i64, by_b: i64, cx_b: i64, cy_b: i64,
    ccx_out_ptr: i64, ccy_out_ptr: i64) -> i64;

// Compute Delaunay triangulation. Returns triangle count
// (≤ max_tris_); each triangle is 3 contiguous int32 indices
// into the input point array.
fn delaunay_2d(pts_xy_ptr: i64, n_pts_: i64,
    out_tris_ptr: i64, max_tris_: i64) -> i64
{
    return nuc_delaunay_2d(pts_xy_ptr, n_pts_, out_tris_ptr, max_tris_);
}

// Compute circumcenter of a 2-D triangle. Returns 1 on success,
// 0 if the triangle is degenerate (collinear).
fn circumcenter_2d(ax_b: i64, ay_b: i64,
    bx_b: i64, by_b: i64, cx_b: i64, cy_b: i64,
    ccx_out_ptr: i64, ccy_out_ptr: i64) -> i64
{
    return nuc_circumcenter_2d(ax_b, ay_b, bx_b, by_b, cx_b, cy_b,
        ccx_out_ptr, ccy_out_ptr);
}
