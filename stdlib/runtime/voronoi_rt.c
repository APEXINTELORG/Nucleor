// voronoi_rt.c — 2-D Voronoi diagram from a Delaunay triangulation.
//
// Given a set of input "site" points and their Delaunay
// triangulation, computes the dual Voronoi diagram:
//
//   Voronoi vertex = circumcenter of one Delaunay triangle.
//   Voronoi edge   = line segment between circumcenters of two
//                    Delaunay triangles sharing an edge (i.e.,
//                    the Voronoi edge bisects that shared edge).
//
// This rod assumes you've already computed the Delaunay
// triangulation with `delaunay.nr` — pass the triangle list in.
// Returns the Voronoi vertex list (one per triangle) and the
// Voronoi edge list (one per shared Delaunay edge).
//
// Use:
//   - Voronoi-graph path planning (each cell boundary = a
//     traversable edge equidistant from the two nearest sites;
//     follows it to maximize obstacle clearance).
//   - Centroidal-Voronoi-tessellation iteration for mesh
//     generation / sample-distribution optimization.
//   - Power-cell decomposition for spatial indexing.
//
// Edges to/from infinity (the convex-hull boundary cells in the
// site set) are flagged with site index `-1` and the corresponding
// vertex index `-1`. Caller can clip these against a bounding box.
//
// Limitations (3-D Voronoi / weighted (power) Voronoi /
// adaptive density-based remeshing land in v0.6 if needed):
// - 2-D only.
// - Naive O(T²) edge-pair search (where T = #triangles). Fine
//   ≤ ~1000 sites; for bigger sets use a half-edge data structure.
// - Returns segments only (no full cell polygons — caller assembles).
//
// Compile: clang -c stdlib/runtime/voronoi_rt.c -o target/voronoi.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static long long _f2i_hide(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Circumcenter inline (avoids the FFI tax of calling delaunay's helper).
static int _circumcenter(double ax, double ay,
                          double bx, double by,
                          double cx, double cy,
                          double *ccx, double *ccy)
{
    double D = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    if (fabs(D) < 1e-18) return 0;
    double ax2 = ax*ax + ay*ay;
    double bx2 = bx*bx + by*by;
    double cx2 = cx*cx + cy*cy;
    *ccx = (ax2 * (by - cy) + bx2 * (cy - ay) + cx2 * (ay - by)) / D;
    *ccy = (ax2 * (cx - bx) + bx2 * (ax - cx) + cx2 * (bx - ax)) / D;
    return 1;
}

// Compute Voronoi vertices (= circumcenters) and Voronoi edges
// (= adjacency between triangles sharing an edge).
//
// Inputs:
//   pts_xy_ptr    : double[2*n_pts]    — site points
//   tris_ptr      : int32[3*n_tris]    — Delaunay triangle indices
//   n_tris        : triangle count
//   max_verts     : capacity of vert_xy_out (in vertices)
//   max_edges     : capacity of edges_out (in edges)
//
// Outputs:
//   vert_xy_out_ptr   : double[2*max_verts] — packed (x, y).
//                        One entry per triangle (skipping degenerate).
//   edges_out_ptr     : int32[2*max_edges]  — packed (vi, vj).
//                        −1 for the "infinite" endpoint of a hull
//                        edge (one Voronoi endpoint that goes off
//                        to infinity).
//   n_verts_out_ptr   : int32* — written: number of vertices.
//
// Returns: number of edges written (≤ max_edges); 0 on bad input.
long long nuc_voronoi_2d(long long pts_xy_ptr, long long n_pts_,
                          long long tris_ptr,   long long n_tris_,
                          long long vert_xy_out_ptr, long long max_verts_,
                          long long edges_out_ptr,    long long max_edges_,
                          long long n_verts_out_ptr)
{
    int n_pts = (int)n_pts_;
    int n_tris = (int)n_tris_;
    int max_verts = (int)max_verts_;
    int max_edges = (int)max_edges_;
    const double *pts = (const double *)(void *)(size_t)pts_xy_ptr;
    const int *tris = (const int *)(void *)(size_t)tris_ptr;
    double *verts = (double *)(void *)(size_t)vert_xy_out_ptr;
    int *edges = (int *)(void *)(size_t)edges_out_ptr;
    int *n_verts_out = (int *)(void *)(size_t)n_verts_out_ptr;
    if (!pts || !tris || !verts || !edges || !n_verts_out ||
        n_pts < 1 || n_tris < 1 || max_verts < 1 || max_edges < 1) return 0;

    // Compute one circumcenter per triangle (skip degenerate).
    int *tri_to_vi = (int *)malloc(sizeof(int) * n_tris);
    if (!tri_to_vi) return 0;
    int n_v = 0;
    for (int t = 0; t < n_tris; t++) {
        int ia = tris[t*3+0], ib = tris[t*3+1], ic = tris[t*3+2];
        if (ia < 0 || ib < 0 || ic < 0 || ia >= n_pts || ib >= n_pts || ic >= n_pts) {
            tri_to_vi[t] = -1;
            continue;
        }
        double cx, cy;
        int ok = _circumcenter(pts[ia*2+0], pts[ia*2+1],
                                pts[ib*2+0], pts[ib*2+1],
                                pts[ic*2+0], pts[ic*2+1],
                                &cx, &cy);
        if (!ok || n_v >= max_verts) { tri_to_vi[t] = -1; continue; }
        verts[n_v*2+0] = cx;
        verts[n_v*2+1] = cy;
        tri_to_vi[t] = n_v;
        n_v++;
    }
    *n_verts_out = n_v;

    // For each Delaunay edge, find the (up to 2) triangles it
    // belongs to. If 2 triangles share it → Voronoi edge between
    // their two circumcenters. If 1 triangle → "hull" Voronoi edge
    // with one endpoint at infinity (encoded as -1).
    //
    // Build the edge list once: per triangle, emit 3 edges; group by
    // canonical (u,v) with u<v.
    int E_cap = 3 * n_tris;
    typedef struct { int u, v, t1, t2; } Edge;
    Edge *eb = (Edge *)malloc(sizeof(Edge) * E_cap);
    if (!eb) { free(tri_to_vi); return 0; }
    int n_eb = 0;
    for (int t = 0; t < n_tris; t++) {
        int ia = tris[t*3+0], ib = tris[t*3+1], ic = tris[t*3+2];
        int e[3][2] = {{ia, ib}, {ib, ic}, {ic, ia}};
        for (int k = 0; k < 3; k++) {
            int u = e[k][0], v = e[k][1];
            if (u > v) { int s = u; u = v; v = s; }
            int found = -1;
            for (int j = 0; j < n_eb; j++) {
                if (eb[j].u == u && eb[j].v == v) { found = j; break; }
            }
            if (found >= 0) {
                eb[found].t2 = t;
            } else {
                eb[n_eb].u = u; eb[n_eb].v = v;
                eb[n_eb].t1 = t; eb[n_eb].t2 = -1;
                n_eb++;
            }
        }
    }

    int n_out = 0;
    for (int i = 0; i < n_eb && n_out < max_edges; i++) {
        int t1 = eb[i].t1, t2 = eb[i].t2;
        int v1 = (t1 >= 0) ? tri_to_vi[t1] : -1;
        int v2 = (t2 >= 0) ? tri_to_vi[t2] : -1;
        if (v1 < 0 && v2 < 0) continue;
        edges[n_out*2+0] = v1;
        edges[n_out*2+1] = v2;
        n_out++;
    }

    free(eb);
    free(tri_to_vi);
    return (long long)n_out;
}
