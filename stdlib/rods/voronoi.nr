// rods/voronoi — 2-D Voronoi diagram from a Delaunay triangulation.
//
// Lifts a Delaunay triangulation (`delaunay.nr`) into its dual
// Voronoi diagram:
//   - Voronoi vertex = circumcenter of one Delaunay triangle.
//   - Voronoi edge   = segment between circumcenters of two
//                      triangles sharing a Delaunay edge.
//
// Hull-boundary edges have one endpoint at infinity (returned as
// vertex index `-1`); caller can clip against a bounding box.
//
// Use:
//   - Voronoi-graph path planning — each cell boundary is a
//     traversable edge equidistant from the two nearest sites.
//     Following Voronoi edges maximizes obstacle clearance.
//   - Centroidal-Voronoi-tessellation iteration (mesh + sample
//     distribution).
//   - Spatial indexing / power-cell decomposition.
//
// Workflow:
//
//   import "stdlib/rods/delaunay.nr"
//   import "stdlib/rods/voronoi.nr"
//
//   let n_tris = delaunay_2d(pts_ptr, n_pts, tris_ptr, max_tris);
//
//   let n_verts: i32;
//   let n_edges = voronoi_2d(pts_ptr, n_pts,
//                              tris_ptr, n_tris,
//                              vert_xy_out_ptr, max_verts,
//                              edges_out_ptr,    max_edges,
//                              i32_ptr(&n_verts));
//
// Limitations (3-D Voronoi / weighted (power) Voronoi /
// centroidal CVT iteration land in v0.6 if needed):
// - 2-D only.
// - Naive O(T²) Delaunay-edge group; fine ≤ ~1000 sites.
// - Returns segments only; caller assembles full cell polygons.
//
// See `stdlib/runtime/voronoi_rt.c`.
#cfile "../runtime/voronoi_rt.c"

extern fn nuc_voronoi_2d(pts_xy_ptr: i64, n_pts_: i64,
    tris_ptr: i64, n_tris_: i64,
    vert_xy_out_ptr: i64, max_verts_: i64,
    edges_out_ptr: i64,    max_edges_: i64,
    n_verts_out_ptr: i64) -> i64;

// Compute the Voronoi vertex + edge lists from a precomputed
// Delaunay triangulation. Returns edge count (≤ max_edges_).
// Vertex count written to `n_verts_out_ptr` (int32*).
fn voronoi_2d(pts_xy_ptr: i64, n_pts_: i64,
    tris_ptr: i64, n_tris_: i64,
    vert_xy_out_ptr: i64, max_verts_: i64,
    edges_out_ptr: i64,    max_edges_: i64,
    n_verts_out_ptr: i64) -> i64
{
    return nuc_voronoi_2d(pts_xy_ptr, n_pts_, tris_ptr, n_tris_,
        vert_xy_out_ptr, max_verts_,
        edges_out_ptr, max_edges_, n_verts_out_ptr);
}
