// vgraph_rt.c — 2D Visibility Graph planner.
//
// Builds a graph whose vertices are the start, the goal, and every
// vertex of every (convex) polygonal obstacle. Two vertices are
// connected by an edge of weight = Euclidean distance iff the
// straight segment between them
//   (a) does not properly intersect the boundary of any obstacle
//       (sharing endpoints is OK), AND
//   (b) does not lie inside any obstacle (midpoint test).
//
// Then runs Dijkstra from start to goal over this graph.
//
// Foundation for:
//   - 2D mobile-robot path planning with known polygonal world.
//   - Optimal-path baseline against sampling planners (RRT/PRM)
//     for benchmarks.
//   - Pre-processing step for hierarchical planners.
//
// **Limitations** (concave obstacles / inflation / 3D / dynamic
// obstacles land in v0.6 if needed):
// - Convex obstacles only (vertex order: counter-clockwise).
//   Concave obstacles need decomposition first.
// - Brute-force visibility check: O(V² · E_obs) where V is total
//   vertices and E_obs is total obstacle edges. Fine for ≤ ~100
//   vertices total. For larger scenes, sweep-line or BVH-accelerated
//   visibility would be needed (planned for v0.6).
// - No vertex inflation — caller is responsible for shrinking the
//   robot footprint into a point and inflating obstacles.
//
// Compile: clang -c stdlib/runtime/vgraph_rt.c -o target/vgraph.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n_vert;
    double *vert;       // n_vert * 2 (x, y)
} _VGObs;

typedef struct {
    int n_obs, cap_obs;
    _VGObs *obs;
    double sx, sy, gx, gy;
    int planned;
    // After plan:
    int n_path;
    double *path_x;
    double *path_y;
    double path_cost;
} NVG;

long long nuc_vgraph_new(void) {
    NVG *p = (NVG *)calloc(1, sizeof(NVG));
    p->cap_obs = 8;
    p->obs = (_VGObs *)calloc(p->cap_obs, sizeof(_VGObs));
    return (long long)(size_t)p;
}

// Add a convex polygonal obstacle. `vertices_ptr` is `double[n_vert * 2]`
// (x, y interleaved) in counter-clockwise order. Vertices are copied.
long long nuc_vgraph_add_obstacle(long long h, long long vertices_ptr, long long n_vert_) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p) return -1;
    int n = (int)n_vert_;
    if (n < 3) return -1;
    double *src = (double *)(void *)(size_t)vertices_ptr;
    if (!src) return -1;
    if (p->n_obs >= p->cap_obs) {
        p->cap_obs *= 2;
        p->obs = (_VGObs *)realloc(p->obs, p->cap_obs * sizeof(_VGObs));
    }
    _VGObs *o = &p->obs[p->n_obs];
    o->n_vert = n;
    o->vert = (double *)malloc(n * 2 * sizeof(double));
    memcpy(o->vert, src, n * 2 * sizeof(double));
    return (long long)(p->n_obs++);
}

void nuc_vgraph_set_start(long long h, long long x_b, long long y_b) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p) return;
    p->sx = _i2f(x_b);
    p->sy = _i2f(y_b);
}
void nuc_vgraph_set_goal(long long h, long long x_b, long long y_b) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p) return;
    p->gx = _i2f(x_b);
    p->gy = _i2f(y_b);
}

// Geometry helpers ===

static double _cross(double ax, double ay, double bx, double by) {
    return ax * by - ay * bx;
}

// Segment-segment proper intersection test. Returns 1 if segments
// AB and CD properly intersect (cross in their interiors). Endpoints
// touching = 0 (caller handles shared endpoints separately).
static int _seg_intersect(double ax, double ay, double bx, double by,
                          double cx, double cy, double dx, double dy) {
    double d1 = _cross(dx - cx, dy - cy, ax - cx, ay - cy);
    double d2 = _cross(dx - cx, dy - cy, bx - cx, by - cy);
    double d3 = _cross(bx - ax, by - ay, cx - ax, cy - ay);
    double d4 = _cross(bx - ax, by - ay, dx - ax, dy - ay);
    // Strictly opposite signs on both sides — proper crossing.
    if (((d1 > 1e-12 && d2 < -1e-12) || (d1 < -1e-12 && d2 > 1e-12)) &&
        ((d3 > 1e-12 && d4 < -1e-12) || (d3 < -1e-12 && d4 > 1e-12))) {
        return 1;
    }
    return 0;
}

// Point-in-convex-polygon test (CCW vertices).
static int _point_in_convex(const _VGObs *o, double px, double py) {
    int n = o->n_vert;
    for (int i = 0; i < n; i++) {
        double ax = o->vert[i*2 + 0], ay = o->vert[i*2 + 1];
        double bx = o->vert[((i + 1) % n)*2 + 0], by = o->vert[((i + 1) % n)*2 + 1];
        double c = _cross(bx - ax, by - ay, px - ax, py - ay);
        if (c < -1e-12) return 0;       // strictly to the right of an edge
    }
    return 1;
}

static int _segment_visible(NVG *p, double ax, double ay, double bx, double by) {
    // Check intersection with every obstacle edge.
    for (int o_i = 0; o_i < p->n_obs; o_i++) {
        _VGObs *o = &p->obs[o_i];
        int n = o->n_vert;
        for (int e = 0; e < n; e++) {
            double cx = o->vert[e*2 + 0], cy = o->vert[e*2 + 1];
            double dx = o->vert[((e + 1) % n)*2 + 0], dy = o->vert[((e + 1) % n)*2 + 1];
            // Skip edges that share a vertex with our segment.
            int shares = 0;
            if ((fabs(cx - ax) < 1e-9 && fabs(cy - ay) < 1e-9) ||
                (fabs(cx - bx) < 1e-9 && fabs(cy - by) < 1e-9) ||
                (fabs(dx - ax) < 1e-9 && fabs(dy - ay) < 1e-9) ||
                (fabs(dx - bx) < 1e-9 && fabs(dy - by) < 1e-9)) {
                shares = 1;
            }
            if (!shares && _seg_intersect(ax, ay, bx, by, cx, cy, dx, dy)) {
                return 0;
            }
        }
        // Midpoint inside obstacle = chord through interior (for convex).
        double mx = 0.5 * (ax + bx);
        double my = 0.5 * (ay + by);
        if (_point_in_convex(o, mx, my)) {
            // Allow if BOTH endpoints are vertices of THIS obstacle and
            // they're the same vertex or adjacent (boundary edge).
            int found_a = 0, found_b = 0;
            int ai = -1, bi = -1;
            for (int v = 0; v < o->n_vert; v++) {
                if (fabs(o->vert[v*2 + 0] - ax) < 1e-9 &&
                    fabs(o->vert[v*2 + 1] - ay) < 1e-9) { found_a = 1; ai = v; }
                if (fabs(o->vert[v*2 + 0] - bx) < 1e-9 &&
                    fabs(o->vert[v*2 + 1] - by) < 1e-9) { found_b = 1; bi = v; }
            }
            if (found_a && found_b) {
                int diff = abs(ai - bi);
                if (diff == 1 || diff == o->n_vert - 1) continue;   // adjacent boundary edge
            }
            return 0;
        }
    }
    return 1;
}

long long nuc_vgraph_plan(long long h) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p) return 0;

    // Build vertex list: start, goal, then all obstacle vertices.
    int total_verts = 2;
    for (int i = 0; i < p->n_obs; i++) total_verts += p->obs[i].n_vert;
    double *vx = (double *)malloc(total_verts * sizeof(double));
    double *vy = (double *)malloc(total_verts * sizeof(double));
    vx[0] = p->sx; vy[0] = p->sy;
    vx[1] = p->gx; vy[1] = p->gy;
    int idx = 2;
    for (int i = 0; i < p->n_obs; i++) {
        for (int v = 0; v < p->obs[i].n_vert; v++) {
            vx[idx] = p->obs[i].vert[v*2 + 0];
            vy[idx] = p->obs[i].vert[v*2 + 1];
            idx++;
        }
    }

    // Build adjacency matrix (cost = Euclidean if visible, else INF).
    double *adj = (double *)malloc(total_verts * total_verts * sizeof(double));
    for (int i = 0; i < total_verts * total_verts; i++) adj[i] = INFINITY;
    for (int i = 0; i < total_verts; i++) {
        adj[i*total_verts + i] = 0;
        for (int j = i + 1; j < total_verts; j++) {
            if (_segment_visible(p, vx[i], vy[i], vx[j], vy[j])) {
                double dx = vx[i] - vx[j], dy = vy[i] - vy[j];
                double d = sqrt(dx*dx + dy*dy);
                adj[i*total_verts + j] = d;
                adj[j*total_verts + i] = d;
            }
        }
    }

    // Dijkstra from vertex 0 (start) to vertex 1 (goal).
    double *dist = (double *)malloc(total_verts * sizeof(double));
    int    *prev = (int *)malloc(total_verts * sizeof(int));
    int    *done = (int *)calloc(total_verts, sizeof(int));
    for (int i = 0; i < total_verts; i++) { dist[i] = INFINITY; prev[i] = -1; }
    dist[0] = 0;
    for (int it = 0; it < total_verts; it++) {
        int u = -1; double best = INFINITY;
        for (int i = 0; i < total_verts; i++) {
            if (!done[i] && dist[i] < best) { best = dist[i]; u = i; }
        }
        if (u < 0) break;
        done[u] = 1;
        if (u == 1) break;       // reached goal
        for (int v = 0; v < total_verts; v++) {
            if (done[v]) continue;
            double w = adj[u*total_verts + v];
            if (w >= INFINITY) continue;
            double nd = dist[u] + w;
            if (nd < dist[v]) { dist[v] = nd; prev[v] = u; }
        }
    }

    // Reconstruct path from goal (1) back to start (0).
    if (p->path_x) { free(p->path_x); p->path_x = NULL; }
    if (p->path_y) { free(p->path_y); p->path_y = NULL; }
    p->n_path = 0;
    p->path_cost = 0;

    if (dist[1] < INFINITY) {
        int cnt = 0;
        for (int v = 1; v != -1; v = prev[v]) cnt++;
        p->path_x = (double *)malloc(cnt * sizeof(double));
        p->path_y = (double *)malloc(cnt * sizeof(double));
        int j = cnt - 1;
        for (int v = 1; v != -1; v = prev[v]) {
            p->path_x[j] = vx[v];
            p->path_y[j] = vy[v];
            j--;
        }
        p->n_path = cnt;
        p->path_cost = dist[1];
    }

    free(vx); free(vy); free(adj); free(dist); free(prev); free(done);
    p->planned = 1;
    return p->n_path > 0 ? (long long)p->n_path : 0;
}

long long nuc_vgraph_path_len(long long h) {
    NVG *p = (NVG *)(void *)(size_t)h;
    return p ? (long long)p->n_path : 0;
}
long long nuc_vgraph_path_x(long long h, long long i_) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p || i_ < 0 || i_ >= p->n_path) return _f2i(0.0);
    return _f2i(p->path_x[i_]);
}
long long nuc_vgraph_path_y(long long h, long long i_) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p || i_ < 0 || i_ >= p->n_path) return _f2i(0.0);
    return _f2i(p->path_y[i_]);
}
long long nuc_vgraph_path_cost(long long h) {
    NVG *p = (NVG *)(void *)(size_t)h;
    return p ? _f2i(p->path_cost) : _f2i(0.0);
}

void nuc_vgraph_free(long long h) {
    NVG *p = (NVG *)(void *)(size_t)h;
    if (!p) return;
    if (p->obs) {
        for (int i = 0; i < p->n_obs; i++) if (p->obs[i].vert) free(p->obs[i].vert);
        free(p->obs);
    }
    if (p->path_x) free(p->path_x);
    if (p->path_y) free(p->path_y);
    free(p);
}
