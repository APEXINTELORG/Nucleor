// delaunay_rt.c — Bowyer-Watson Delaunay triangulation (2-D).
//
// Given N input points in 2-D, computes a Delaunay triangulation
// (the unique triangulation maximizing the minimum interior angle
// across all triangulations of the point set).
//
// The Delaunay triangulation is the dual of the Voronoi diagram —
// adjacent Delaunay triangles share a Voronoi edge whose endpoints
// are their circumcenters. So this rod is the foundation for
// Voronoi-based motion planning, mesh generation, scattered-data
// interpolation, and nearest-neighbor lookup in 2-D.
//
// Algorithm (Bowyer 1981 / Watson 1981, the incremental insertion):
//   1. Add a "super-triangle" big enough to contain all input
//      points to seed the triangulation.
//   2. For each input point P:
//      a. Find all triangles whose circumcircle contains P
//         ("bad triangles").
//      b. The boundary of the union of those triangles is a
//         polygon; take its edges that appear EXACTLY once
//         (i.e., not shared internally) — that's the cavity.
//      c. Remove the bad triangles; re-triangulate by connecting
//         P to every cavity edge.
//   3. Remove any triangle that uses a super-triangle vertex.
//
// Use:
//   - Voronoi diagrams (compute circumcenters of resulting
//     triangles; each Voronoi vertex IS a circumcenter; each
//     Voronoi edge connects circumcenters of triangles sharing
//     a Delaunay edge).
//   - Triangle-mesh generation for FEM.
//   - Natural-neighbor interpolation.
//
// Limitations (full sweep-line / 3-D Delaunay / robust
// predicates land in v0.6 if needed):
// - 2-D only.
// - Naive O(N²) incremental insertion (no spatial index for
//   "find containing triangle"). Fine up to ~1000 points; for
//   bigger sets use the v0.6 sweep-line variant.
// - Floating-point arithmetic — degenerate cases (4 cocircular
//   points) may give an arbitrary-but-valid choice between two
//   triangulations.
// - Output is array of triangle vertex INDICES (i, j, k) into
//   the input point array.
//
// Compile: clang -c stdlib/runtime/delaunay_rt.c -o target/delaunay.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

typedef struct { int a, b, c; } Tri;

// Strictly inside circumcircle test via determinant.
static int _in_circumcircle(double ax, double ay,
                              double bx, double by,
                              double cx, double cy,
                              double px, double py) {
    double ori = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    if (ori < 0) {
        double t;
        t = bx; bx = cx; cx = t;
        t = by; by = cy; cy = t;
    }
    double dx = ax - px, dy = ay - py;
    double ex = bx - px, ey = by - py;
    double fx = cx - px, fy = cy - py;
    double ap = dx*dx + dy*dy;
    double bp = ex*ex + ey*ey;
    double cp = fx*fx + fy*fy;
    double det = dx * (ey * cp - bp * fy)
                - dy * (ex * cp - bp * fx)
                + ap * (ex * fy - ey * fx);
    return (det > 0);
}

// Compute Delaunay triangulation. Output: int32[3 * max_tris] —
// triangle indices (i, j, k). Returns count actually written.
long long nuc_delaunay_2d(long long pts_xy_ptr, long long n_pts_,
                            long long out_tris_ptr, long long max_tris_)
{
    int N = (int)n_pts_;
    int max_tris = (int)max_tris_;
    const double *pts = (const double *)(void *)(size_t)pts_xy_ptr;
    int *out = (int *)(void *)(size_t)out_tris_ptr;
    if (!pts || !out || N < 3 || max_tris < 1) return 0;

    double xmin = pts[0], xmax = pts[0];
    double ymin = pts[1], ymax = pts[1];
    for (int i = 1; i < N; i++) {
        double x = pts[i*2+0], y = pts[i*2+1];
        if (x < xmin) xmin = x;  if (x > xmax) xmax = x;
        if (y < ymin) ymin = y;  if (y > ymax) ymax = y;
    }
    double dx = xmax - xmin;
    double dy = ymax - ymin;
    double dmax = (dx > dy) ? dx : dy;
    double midx = (xmin + xmax) / 2;
    double midy = (ymin + ymax) / 2;
    if (dmax <= 0) dmax = 1.0;
    int N_total = N + 3;
    double *spts = (double *)malloc(sizeof(double) * 2 * N_total);
    if (!spts) return 0;
    memcpy(spts, pts, sizeof(double) * 2 * N);
    spts[N*2+0] = midx - 20 * dmax;     spts[N*2+1] = midy - dmax;
    spts[(N+1)*2+0] = midx;              spts[(N+1)*2+1] = midy + 20 * dmax;
    spts[(N+2)*2+0] = midx + 20 * dmax;  spts[(N+2)*2+1] = midy - dmax;

    int cap = 32;
    Tri *tris = (Tri *)malloc(sizeof(Tri) * cap);
    if (!tris) { free(spts); return 0; }
    int n_tris = 0;
    tris[n_tris++] = (Tri){N, N+1, N+2};

    int edge_cap = 64;
    int (*edges)[2] = (int (*)[2])malloc(sizeof(int) * 2 * edge_cap);
    int *edge_count = (int *)malloc(sizeof(int) * edge_cap);
    if (!edges || !edge_count) { free(edges); free(edge_count); free(tris); free(spts); return 0; }

    Tri *bad = (Tri *)malloc(sizeof(Tri) * cap);
    if (!bad) { free(edges); free(edge_count); free(tris); free(spts); return 0; }

    for (int p = 0; p < N; p++) {
        double px = pts[p*2+0], py = pts[p*2+1];
        int n_bad = 0;
        for (int i = n_tris - 1; i >= 0; i--) {
            Tri t = tris[i];
            double ax = spts[t.a*2+0], ay = spts[t.a*2+1];
            double bx = spts[t.b*2+0], by = spts[t.b*2+1];
            double cx = spts[t.c*2+0], cy = spts[t.c*2+1];
            if (_in_circumcircle(ax, ay, bx, by, cx, cy, px, py)) {
                if (n_bad >= cap) {
                    cap *= 2;
                    Tri *nb = (Tri *)realloc(bad, sizeof(Tri) * cap);
                    Tri *nt = (Tri *)realloc(tris, sizeof(Tri) * cap);
                    if (!nb || !nt) {
                        free(bad); free(tris); free(edges); free(edge_count); free(spts);
                        return 0;
                    }
                    bad = nb; tris = nt;
                }
                bad[n_bad++] = t;
                tris[i] = tris[n_tris - 1];
                n_tris--;
            }
        }
        int n_edges = 0;
        for (int i = 0; i < n_bad; i++) {
            Tri t = bad[i];
            int e[3][2] = {{t.a, t.b}, {t.b, t.c}, {t.c, t.a}};
            for (int k = 0; k < 3; k++) {
                int u = e[k][0], v = e[k][1];
                if (u > v) { int s = u; u = v; v = s; }
                int found = -1;
                for (int j = 0; j < n_edges; j++) {
                    if (edges[j][0] == u && edges[j][1] == v) { found = j; break; }
                }
                if (found >= 0) {
                    edge_count[found]++;
                } else {
                    if (n_edges >= edge_cap) {
                        edge_cap *= 2;
                        int (*ne)[2] = (int (*)[2])realloc(edges, sizeof(int) * 2 * edge_cap);
                        int *nec = (int *)realloc(edge_count, sizeof(int) * edge_cap);
                        if (!ne || !nec) {
                            free(bad); free(tris); free(edges); free(edge_count); free(spts);
                            return 0;
                        }
                        edges = ne; edge_count = nec;
                    }
                    edges[n_edges][0] = u; edges[n_edges][1] = v;
                    edge_count[n_edges] = 1;
                    n_edges++;
                }
            }
        }
        for (int i = 0; i < n_edges; i++) {
            if (edge_count[i] != 1) continue;
            if (n_tris >= cap) {
                cap *= 2;
                Tri *nt = (Tri *)realloc(tris, sizeof(Tri) * cap);
                if (!nt) { free(bad); free(tris); free(edges); free(edge_count); free(spts); return 0; }
                tris = nt;
            }
            tris[n_tris++] = (Tri){edges[i][0], edges[i][1], p};
        }
    }

    int n_out = 0;
    for (int i = 0; i < n_tris && n_out < max_tris; i++) {
        Tri t = tris[i];
        if (t.a >= N || t.b >= N || t.c >= N) continue;
        out[n_out*3+0] = t.a;
        out[n_out*3+1] = t.b;
        out[n_out*3+2] = t.c;
        n_out++;
    }

    free(bad); free(edges); free(edge_count); free(tris); free(spts);
    return (long long)n_out;
}

// Circumcenter helper.
long long nuc_circumcenter_2d(long long ax_b, long long ay_b,
                                long long bx_b, long long by_b,
                                long long cx_b, long long cy_b,
                                long long ccx_out_ptr, long long ccy_out_ptr)
{
    double *ccx = (double *)(void *)(size_t)ccx_out_ptr;
    double *ccy = (double *)(void *)(size_t)ccy_out_ptr;
    if (!ccx || !ccy) return 0;
    double ax = _i2f(ax_b), ay = _i2f(ay_b);
    double bx = _i2f(bx_b), by = _i2f(by_b);
    double cx = _i2f(cx_b), cy = _i2f(cy_b);
    double D = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    if (fabs(D) < 1e-18) return 0;
    double ax2 = ax*ax + ay*ay;
    double bx2 = bx*bx + by*by;
    double cx2 = cx*cx + cy*cy;
    *ccx = (ax2 * (by - cy) + bx2 * (cy - ay) + cx2 * (ay - by)) / D;
    *ccy = (ax2 * (cx - bx) + bx2 * (ax - cx) + cx2 * (bx - ax)) / D;
    return 1;
}
