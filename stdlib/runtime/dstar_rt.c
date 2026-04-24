// dstar_rt.c — D* Lite incremental replanner on a 2-D 8-connected
// grid (Koenig & Likhachev 2002).
//
// Solves the same single-source shortest-path problem as A*, but is
// designed for repeated planning when only a small fraction of edge
// costs change between queries — typical in mobile-robot navigation
// where new obstacles appear / disappear and you don't want to
// rebuild the whole plan from scratch every time.
//
// Each cell stores:
//   c[x, y]    — base traversal cost (∞ for obstacles)
//   g[x, y]    — current best known cost-to-goal
//   rhs[x, y]  — one-step look-ahead estimate from neighbors
// A cell is *consistent* iff g == rhs. The algorithm maintains the
// invariant that any cell on the shortest path is consistent and
// makes inconsistent cells consistent in priority order.
//
// Lazy priority queue: pushes never decrease/remove — they only
// add. The pop side checks key validity and discards stale entries
// (any pop whose stored key disagrees with current key(u) is just
// skipped). This makes the implementation small without sacrificing
// correctness.
//
// 8-connectivity: each cell has 8 neighbors with edge cost
//   c_edge(s, s')  =  max(c[s], c[s'])  ·  (sqrt(2) for diagonal else 1)
//
// Workflow:
//   1. Build grid, set per-cell costs.
//   2. Set start, goal.
//   3. Plan once with `dstar_plan`.
//   4. Walk the path with `dstar_path_x` / `dstar_path_y`.
//   5. When the world changes, update affected cells with
//      `dstar_update_cost` (one or many) and call `dstar_replan`.
//      Cost of replan ∝ number of cells whose neighborhood was
//      perturbed — typically a small fraction of the grid.
//
// **Limitations** (any-angle planning / 3-D / continuous costs land
// in v0.6 if needed):
// - 8-connected grid only.
// - Per-cell traversal cost (uniform across all 8 incident edges
//   from that cell on the "into" side); use very large costs for
//   obstacles.
// - Octile heuristic — admissible AND consistent for 8-connected
//   uniform grids.
//
// Compile: clang -c stdlib/runtime/dstar_rt.c -o target/dstar.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define INF_COST 1e18

typedef struct { double k1, k2; int x, y; } _DSItem;

typedef struct {
    int W, H;
    double *c;        // base cost per cell
    double *g;        // cost-to-goal
    double *rhs;      // one-step look-ahead
    int sx, sy;       // start
    int gx, gy;       // goal
    double km;        // key modifier
    _DSItem *heap;
    int heap_size, heap_cap;
    int *path_x, *path_y;
    int path_len;
} NDSTAR;

// === Heap helpers (min-heap on (k1, k2) lexicographic) ===

static int _key_lt(const _DSItem *a, const _DSItem *b) {
    if (a->k1 < b->k1) return 1;
    if (a->k1 > b->k1) return 0;
    return a->k2 < b->k2;
}
static void _heap_push(NDSTAR *p, double k1, double k2, int x, int y) {
    if (p->heap_size + 1 >= p->heap_cap) {
        p->heap_cap = p->heap_cap * 2 + 16;
        p->heap = (_DSItem *)realloc(p->heap, p->heap_cap * sizeof(_DSItem));
    }
    int i = p->heap_size++;
    p->heap[i].k1 = k1; p->heap[i].k2 = k2; p->heap[i].x = x; p->heap[i].y = y;
    while (i > 0) {
        int parent = (i - 1) / 2;
        if (_key_lt(&p->heap[i], &p->heap[parent])) {
            _DSItem t = p->heap[parent]; p->heap[parent] = p->heap[i]; p->heap[i] = t;
            i = parent;
        } else break;
    }
}
static int _heap_pop(NDSTAR *p, _DSItem *out) {
    if (p->heap_size == 0) return 0;
    *out = p->heap[0];
    p->heap[0] = p->heap[--p->heap_size];
    int i = 0;
    for (;;) {
        int l = 2*i+1, r = 2*i+2, best = i;
        if (l < p->heap_size && _key_lt(&p->heap[l], &p->heap[best])) best = l;
        if (r < p->heap_size && _key_lt(&p->heap[r], &p->heap[best])) best = r;
        if (best != i) {
            _DSItem t = p->heap[best]; p->heap[best] = p->heap[i]; p->heap[i] = t;
            i = best;
        } else break;
    }
    return 1;
}
static int _heap_top(NDSTAR *p, _DSItem *out) {
    if (p->heap_size == 0) return 0;
    *out = p->heap[0];
    return 1;
}

// === D* helpers ===

static double _h(NDSTAR *p, int x, int y) {
    int dx = abs(x - p->sx), dy = abs(y - p->sy);
    int dmin = dx < dy ? dx : dy;
    int dmax = dx < dy ? dy : dx;
    return (dmax - dmin) + sqrt(2.0) * dmin;       // octile
}

static void _key(NDSTAR *p, int x, int y, double *k1, double *k2) {
    int idx = y * p->W + x;
    double m = (p->g[idx] < p->rhs[idx]) ? p->g[idx] : p->rhs[idx];
    *k1 = m + _h(p, x, y) + p->km;
    *k2 = m;
}

static const int DX8[8] = { 1, -1, 0, 0,  1, 1, -1, -1 };
static const int DY8[8] = { 0, 0, 1, -1,  1, -1, 1, -1 };

// Edge cost between two adjacent cells.
static double _edge(NDSTAR *p, int x1, int y1, int x2, int y2) {
    int idx1 = y1 * p->W + x1;
    int idx2 = y2 * p->W + x2;
    double c = (p->c[idx1] > p->c[idx2]) ? p->c[idx1] : p->c[idx2];
    if (c >= INF_COST) return INF_COST;
    int dx = x1 - x2, dy = y1 - y2;
    int diag = (dx != 0 && dy != 0);
    return c * (diag ? sqrt(2.0) : 1.0);
}

static void _update_vertex(NDSTAR *p, int x, int y) {
    int idx = y * p->W + x;
    if (!(x == p->gx && y == p->gy)) {
        // rhs(s) = min over s' in succ(s) of c(s, s') + g(s')
        double best = INF_COST;
        for (int k = 0; k < 8; k++) {
            int nx = x + DX8[k], ny = y + DY8[k];
            if (nx < 0 || nx >= p->W || ny < 0 || ny >= p->H) continue;
            double e = _edge(p, x, y, nx, ny);
            if (e >= INF_COST) continue;
            double cand = e + p->g[ny * p->W + nx];
            if (cand < best) best = cand;
        }
        p->rhs[idx] = best;
    }
    if (p->g[idx] != p->rhs[idx]) {
        double k1, k2;
        _key(p, x, y, &k1, &k2);
        _heap_push(p, k1, k2, x, y);
    }
}

static int _key_lt_pair(double a1, double a2, double b1, double b2) {
    if (a1 < b1) return 1;
    if (a1 > b1) return 0;
    return a2 < b2;
}

static void _compute_shortest_path(NDSTAR *p) {
    int s_idx = p->sy * p->W + p->sx;
    int max_loops = p->W * p->H * 50 + 1000;
    while (p->heap_size > 0 && max_loops-- > 0) {
        _DSItem top;
        if (!_heap_top(p, &top)) break;
        double k_top1 = top.k1, k_top2 = top.k2;
        double k_s1, k_s2;
        _key(p, p->sx, p->sy, &k_s1, &k_s2);
        if (!_key_lt_pair(k_top1, k_top2, k_s1, k_s2) &&
            p->rhs[s_idx] == p->g[s_idx]) break;

        _DSItem u; _heap_pop(p, &u);
        // Stale check: recompute key for u — if it disagrees, skip and re-push if needed.
        double cur_k1, cur_k2;
        _key(p, u.x, u.y, &cur_k1, &cur_k2);
        if (_key_lt_pair(u.k1, u.k2, cur_k1, cur_k2)) {
            // Stale entry — push fresh and continue.
            _heap_push(p, cur_k1, cur_k2, u.x, u.y);
            continue;
        }

        int u_idx = u.y * p->W + u.x;
        // Skip if u is already consistent — this is a stale heap
        // entry left over from a previous push (the lazy heap allows
        // duplicates). In strict D* Lite the queue is a set; here we
        // need this check to avoid wrongly under-consistent-zapping
        // a cell whose g and rhs match.
        if (p->g[u_idx] == p->rhs[u_idx]) continue;
        if (p->g[u_idx] > p->rhs[u_idx]) {
            // Over-consistent: g <- rhs.
            p->g[u_idx] = p->rhs[u_idx];
            // Update predecessors (= 8-neighbors for symmetric grid).
            for (int k = 0; k < 8; k++) {
                int nx = u.x + DX8[k], ny = u.y + DY8[k];
                if (nx < 0 || nx >= p->W || ny < 0 || ny >= p->H) continue;
                _update_vertex(p, nx, ny);
            }
        } else {
            // Under-consistent (g < rhs): g <- ∞, then update u
            // and predecessors. (Standard D* Lite paper line.)
            p->g[u_idx] = INF_COST;
            _update_vertex(p, u.x, u.y);
            for (int k = 0; k < 8; k++) {
                int nx = u.x + DX8[k], ny = u.y + DY8[k];
                if (nx < 0 || nx >= p->W || ny < 0 || ny >= p->H) continue;
                _update_vertex(p, nx, ny);
            }
        }
    }
}

static void _extract_path(NDSTAR *p) {
    if (p->path_x) { free(p->path_x); p->path_x = NULL; }
    if (p->path_y) { free(p->path_y); p->path_y = NULL; }
    p->path_len = 0;

    int s_idx = p->sy * p->W + p->sx;
    if (p->g[s_idx] >= INF_COST) return;       // no path

    // Greedy descent from start: at each step pick neighbor with
    // min (edge cost + g).
    int cap = p->W + p->H + 64;
    int *xs = (int *)malloc(cap * sizeof(int));
    int *ys = (int *)malloc(cap * sizeof(int));
    int n = 0;
    int cx = p->sx, cy = p->sy;
    xs[n] = cx; ys[n] = cy; n++;
    int max_steps = p->W * p->H + 16;
    while (!(cx == p->gx && cy == p->gy) && max_steps-- > 0) {
        double best = INF_COST;
        int bx = cx, by = cy;
        for (int k = 0; k < 8; k++) {
            int nx = cx + DX8[k], ny = cy + DY8[k];
            if (nx < 0 || nx >= p->W || ny < 0 || ny >= p->H) continue;
            double e = _edge(p, cx, cy, nx, ny);
            if (e >= INF_COST) continue;
            double cand = e + p->g[ny * p->W + nx];
            if (cand < best) { best = cand; bx = nx; by = ny; }
        }
        if (bx == cx && by == cy) break;          // stuck
        if (n + 1 >= cap) { cap *= 2; xs = (int *)realloc(xs, cap*sizeof(int)); ys = (int *)realloc(ys, cap*sizeof(int)); }
        cx = bx; cy = by;
        xs[n] = cx; ys[n] = cy; n++;
    }
    if (cx == p->gx && cy == p->gy) {
        p->path_x = xs; p->path_y = ys; p->path_len = n;
    } else {
        free(xs); free(ys);
    }
}

// === API ===

long long nuc_dstar_new(long long W_, long long H_) {
    int W = (int)W_, H = (int)H_;
    if (W <= 0 || H <= 0) return 0;
    NDSTAR *p = (NDSTAR *)calloc(1, sizeof(NDSTAR));
    p->W = W; p->H = H;
    int n = W * H;
    p->c = (double *)malloc(n * sizeof(double));
    p->g = (double *)malloc(n * sizeof(double));
    p->rhs = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) { p->c[i] = 1.0; p->g[i] = INF_COST; p->rhs[i] = INF_COST; }
    p->sx = p->sy = p->gx = p->gy = 0;
    p->km = 0;
    p->heap_cap = 64;
    p->heap = (_DSItem *)malloc(p->heap_cap * sizeof(_DSItem));
    return (long long)(size_t)p;
}

void nuc_dstar_set_cost(long long h, long long x_, long long y_, long long c_b) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || x_ < 0 || x_ >= p->W || y_ < 0 || y_ >= p->H) return;
    double c = _i2f(c_b);
    if (c < 0) c = INF_COST;
    p->c[(int)y_ * p->W + (int)x_] = c;
}

void nuc_dstar_set_start(long long h, long long x_, long long y_) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || x_ < 0 || x_ >= p->W || y_ < 0 || y_ >= p->H) return;
    p->sx = (int)x_; p->sy = (int)y_;
}

void nuc_dstar_set_goal(long long h, long long x_, long long y_) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || x_ < 0 || x_ >= p->W || y_ < 0 || y_ >= p->H) return;
    p->gx = (int)x_; p->gy = (int)y_;
}

long long nuc_dstar_plan(long long h) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p) return 0;
    int n = p->W * p->H;
    for (int i = 0; i < n; i++) { p->g[i] = INF_COST; p->rhs[i] = INF_COST; }
    p->heap_size = 0;
    p->km = 0;
    int gi = p->gy * p->W + p->gx;
    p->rhs[gi] = 0;
    double k1, k2;
    _key(p, p->gx, p->gy, &k1, &k2);
    _heap_push(p, k1, k2, p->gx, p->gy);
    _compute_shortest_path(p);
    _extract_path(p);
    return (p->path_len > 0) ? 1 : 0;
}

// Update one cell's cost. Caller batches updates by calling this
// repeatedly, then calls `dstar_replan` once.
void nuc_dstar_update_cost(long long h, long long x_, long long y_, long long c_b) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || x_ < 0 || x_ >= p->W || y_ < 0 || y_ >= p->H) return;
    double c = _i2f(c_b);
    if (c < 0) c = INF_COST;
    int x = (int)x_, y = (int)y_;
    p->c[y * p->W + x] = c;
    // Mark this cell + 8-neighbors for re-evaluation.
    _update_vertex(p, x, y);
    for (int k = 0; k < 8; k++) {
        int nx = x + DX8[k], ny = y + DY8[k];
        if (nx < 0 || nx >= p->W || ny < 0 || ny >= p->H) continue;
        _update_vertex(p, nx, ny);
    }
}

long long nuc_dstar_replan(long long h) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p) return 0;
    _compute_shortest_path(p);
    _extract_path(p);
    return (p->path_len > 0) ? 1 : 0;
}

long long nuc_dstar_path_len(long long h) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    return p ? (long long)p->path_len : 0;
}
long long nuc_dstar_path_x(long long h, long long i_) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || i_ < 0 || i_ >= p->path_len) return -1;
    return (long long)p->path_x[i_];
}
long long nuc_dstar_path_y(long long h, long long i_) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || i_ < 0 || i_ >= p->path_len) return -1;
    return (long long)p->path_y[i_];
}
long long nuc_dstar_path_cost(long long h) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p || p->path_len == 0) return _f2i(0.0);
    int idx = p->sy * p->W + p->sx;
    return _f2i(p->g[idx]);
}

void nuc_dstar_free(long long h) {
    NDSTAR *p = (NDSTAR *)(void *)(size_t)h;
    if (!p) return;
    if (p->c) free(p->c);
    if (p->g) free(p->g);
    if (p->rhs) free(p->rhs);
    if (p->heap) free(p->heap);
    if (p->path_x) free(p->path_x);
    if (p->path_y) free(p->path_y);
    free(p);
}
