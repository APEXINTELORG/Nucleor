// wavefront_rt.c — 2D BFS / Dijkstra-lite distance transform from
// one or more start cells over a traversability grid.
//
// Given a `W × H` traversability grid (`1` = traversable, `0` =
// obstacle) and one or more start cells, compute the shortest
// per-cell distance to any start, propagated along allowed cells.
//
// Two connectivity modes:
//   - 4-connected: unit step cost per move.
//   - 8-connected: unit cost for cardinal moves, √2 for diagonal.
//
// Unreachable cells (blocked by obstacles) receive `+∞`.
//
// Foundation for:
//   - Navigation cost field for mobile robots (nearest-obstacle
//     distance, nearest-goal distance).
//   - Frontier utility scoring (distance from robot to each
//     frontier cell).
//   - Connected-component analysis over occupancy grids.
//   - Path shape smoothing via gradient descent on the field.
//
// **Limitations** (fast-sweeping Eikonal / anisotropic costs land
// in v0.6 if needed):
// - Unit-ish cost per step only (with the diagonal √2 bonus for
//   8-connectivity). For arbitrary per-edge costs use Dijkstra
//   via the existing `dstar.nr` or a proper graph rod.
// - Output is cell-count distance (multiply by cell size to get
//   meters).
// - Single distance field per call — re-run per goal.
//
// Compile: clang -c stdlib/runtime/wavefront_rt.c -o target/wavefront.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Simple min-heap of (dist, cell-index) pairs.
typedef struct { double d; int idx; } _WFItem;

static void _heap_push(_WFItem *h, int *sz, double d, int idx) {
    int i = (*sz)++;
    h[i].d = d; h[i].idx = idx;
    while (i > 0) {
        int parent = (i - 1) / 2;
        if (h[parent].d > h[i].d) {
            _WFItem t = h[parent]; h[parent] = h[i]; h[i] = t;
            i = parent;
        } else break;
    }
}
static int _heap_pop(_WFItem *h, int *sz, double *d_out) {
    if (*sz == 0) return -1;
    int top = h[0].idx;
    if (d_out) *d_out = h[0].d;
    h[0] = h[--(*sz)];
    int i = 0;
    for (;;) {
        int l = 2*i+1, r = 2*i+2, best = i;
        if (l < *sz && h[l].d < h[best].d) best = l;
        if (r < *sz && h[r].d < h[best].d) best = r;
        if (best != i) {
            _WFItem t = h[best]; h[best] = h[i]; h[i] = t;
            i = best;
        } else break;
    }
    return top;
}

// Compute the wavefront distance field.
//
//   trav_ptr:    long long[W*H], 1=traversable, 0=obstacle
//   starts_ptr:  long long[n_starts*2], interleaved (ix, iy) cell indices
//   dist_out_ptr: double[W*H]  — output field (∞ for unreachable)
//   connectivity: 4 or 8
//
// Returns the number of cells reachable from any start (0 on bad input).
long long nuc_wavefront_compute(long long W_, long long H_,
                                 long long trav_ptr,
                                 long long n_starts_, long long starts_ptr,
                                 long long dist_out_ptr,
                                 long long connectivity)
{
    int W = (int)W_, H = (int)H_;
    int n_starts = (int)n_starts_;
    int conn = (int)connectivity;
    if (W <= 0 || H <= 0 || n_starts <= 0) return 0;
    if (conn != 4 && conn != 8) conn = 8;
    const long long *trav = (const long long *)(void *)(size_t)trav_ptr;
    const long long *starts = (const long long *)(void *)(size_t)starts_ptr;
    double *dist = (double *)(void *)(size_t)dist_out_ptr;
    if (!trav || !starts || !dist) return 0;

    int N = W * H;
    for (int i = 0; i < N; i++) dist[i] = INFINITY;

    int n_neigh = conn;
    int DX[8] = { 1, -1,  0,  0,  1,  1, -1, -1 };
    int DY[8] = { 0,  0,  1, -1,  1, -1,  1, -1 };
    double STEP[8] = { 1, 1, 1, 1, 1.4142135623730951, 1.4142135623730951,
                       1.4142135623730951, 1.4142135623730951 };

    // Heap capacity: start with N, grow if needed.
    int heap_cap = N + 16;
    _WFItem *heap = (_WFItem *)malloc(heap_cap * sizeof(_WFItem));
    int heap_size = 0;

    for (int s = 0; s < n_starts; s++) {
        int ix = (int)starts[s * 2 + 0];
        int iy = (int)starts[s * 2 + 1];
        if (ix < 0 || ix >= W || iy < 0 || iy >= H) continue;
        int idx = iy * W + ix;
        if (!trav[idx]) continue;    // start cell must be traversable
        if (dist[idx] > 0) {
            dist[idx] = 0;
            _heap_push(heap, &heap_size, 0, idx);
        }
    }

    long long reached = 0;
    while (heap_size > 0) {
        double d;
        int u = _heap_pop(heap, &heap_size, &d);
        if (d > dist[u]) continue;   // stale entry
        reached++;
        int ux = u % W, uy = u / W;
        for (int k = 0; k < n_neigh; k++) {
            int nx = ux + DX[k], ny = uy + DY[k];
            if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
            int nidx = ny * W + nx;
            if (!trav[nidx]) continue;
            double nd = d + STEP[k];
            if (nd < dist[nidx]) {
                dist[nidx] = nd;
                if (heap_size + 1 >= heap_cap) {
                    heap_cap *= 2;
                    heap = (_WFItem *)realloc(heap, heap_cap * sizeof(_WFItem));
                }
                _heap_push(heap, &heap_size, nd, nidx);
            }
        }
    }

    free(heap);
    return reached;
}
