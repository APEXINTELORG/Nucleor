// kdt_rt.c — 3D KD-tree for fast nearest-neighbor queries that
// adapt to non-uniform point distributions.
//
// Complementary to `sgrid.nr` and `kdtree.nr`:
// - `sgrid.nr` bins points into uniform cubic cells (ideal for
//   evenly-distributed clouds; cell size must be picked up front).
// - `kdtree.nr` is a general n-dimensional kd-tree with a separate
//   point-vector handle (suited to ML/clustering workflows).
// - `kdt.nr` (this rod) is a 3D-specific kd-tree with the same
//   insert/query workflow as `sgrid.nr`, but adapts to non-uniform
//   distributions via median-split instead of fixed binning.
//
// Performance: O(n log² n) build (qsort-based median-split) + O(log n)
// average-case nearest-neighbor query with bounding-box pruning.
// Heap-based k-NN with proper splitting-plane pruning.
//
// Workflow:
//   let h = kdt_new(n_pts_hint);
//   for each point: kdt_insert(h, x_b, y_b, z_b);
//   kdt_build(h);                              // one-time after inserts
//   let nn = kdt_nearest(h, qx_b, qy_b, qz_b);
//   let n  = kdt_knearest(h, qx_b, qy_b, qz_b, k,
//                         out_indices_ptr, out_dist2_ptr);
//
// Limitations (incremental rebuild / R*-tree / approximate-NN
// land in v0.6 if needed):
// - Static tree: must call `kdt_build` after all inserts; further
//   inserts invalidate the tree until rebuilt.
// - Median-split via full qsort (O(n log² n) build); for typical
//   N ≤ 100k that's comfortable.
// - 3D only.
//
// Compile: clang -c stdlib/runtime/kdt_rt.c -o target/kdt.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

typedef struct {
    int point_idx;       // index into pts of the median point at this node
    int axis;            // splitting axis (0, 1, 2)
    int left, right;     // child node indices into nodes[], or -1
} _KDTNode;

typedef struct {
    int n_pts;
    int cap_pts;
    double *pts;         // n_pts × 3 (x, y, z)
    int n_nodes;
    int cap_nodes;
    _KDTNode *nodes;
    int root;            // -1 if not built
    int *idx_buf;        // scratch for build
} NKDT;

// === axis-aware comparison for qsort ===
//
// Static state set before each qsort call. Safe because build is
// single-threaded and recursive calls run sequentially — the static
// remains stable across the duration of each individual qsort call.
static const double *_qs_pts;
static int _qs_axis;
static int _cmp_idx(const void *a, const void *b) {
    int ia = *(const int *)a;
    int ib = *(const int *)b;
    double va = _qs_pts[ia*3 + _qs_axis];
    double vb = _qs_pts[ib*3 + _qs_axis];
    if (va < vb) return -1;
    if (va > vb) return 1;
    return 0;
}

long long nuc_kdt_new(long long n_pts_hint) {
    int hint = (int)n_pts_hint;
    if (hint < 4) hint = 4;
    NKDT *t = (NKDT *)calloc(1, sizeof(NKDT));
    t->cap_pts = hint;
    t->pts = (double *)malloc(t->cap_pts * 3 * sizeof(double));
    t->cap_nodes = hint;
    t->nodes = (_KDTNode *)malloc(t->cap_nodes * sizeof(_KDTNode));
    t->root = -1;
    return (long long)(size_t)t;
}

long long nuc_kdt_insert(long long h, long long x_b, long long y_b, long long z_b) {
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t) return -1;
    if (t->n_pts >= t->cap_pts) {
        t->cap_pts *= 2;
        t->pts = (double *)realloc(t->pts, t->cap_pts * 3 * sizeof(double));
    }
    t->pts[t->n_pts*3 + 0] = _i2f(x_b);
    t->pts[t->n_pts*3 + 1] = _i2f(y_b);
    t->pts[t->n_pts*3 + 2] = _i2f(z_b);
    t->root = -1;       // any insert invalidates the existing tree
    return (long long)(t->n_pts++);
}

long long nuc_kdt_count(long long h) {
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t) return 0;
    return (long long)t->n_pts;
}

static int _build_recursive(NKDT *t, int lo, int hi, int depth) {
    if (lo > hi) return -1;
    int axis = depth % 3;
    _qs_pts = t->pts;
    _qs_axis = axis;
    qsort(t->idx_buf + lo, hi - lo + 1, sizeof(int), _cmp_idx);
    int mid = (lo + hi) / 2;
    int p_idx = t->idx_buf[mid];

    if (t->n_nodes >= t->cap_nodes) {
        t->cap_nodes *= 2;
        t->nodes = (_KDTNode *)realloc(t->nodes, t->cap_nodes * sizeof(_KDTNode));
    }
    int my_node = t->n_nodes++;
    t->nodes[my_node].point_idx = p_idx;
    t->nodes[my_node].axis = axis;
    t->nodes[my_node].left  = -1;
    t->nodes[my_node].right = -1;

    int left  = _build_recursive(t, lo,      mid - 1, depth + 1);
    int right = _build_recursive(t, mid + 1, hi,      depth + 1);
    t->nodes[my_node].left  = left;
    t->nodes[my_node].right = right;
    return my_node;
}

long long nuc_kdt_build(long long h) {
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t) return -1;
    if (t->n_pts == 0) { t->root = -1; t->n_nodes = 0; return 0; }
    if (t->idx_buf) free(t->idx_buf);
    t->idx_buf = (int *)malloc(t->n_pts * sizeof(int));
    for (int i = 0; i < t->n_pts; i++) t->idx_buf[i] = i;
    t->n_nodes = 0;
    if (t->cap_nodes < t->n_pts) {
        t->cap_nodes = t->n_pts;
        t->nodes = (_KDTNode *)realloc(t->nodes, t->cap_nodes * sizeof(_KDTNode));
    }
    t->root = _build_recursive(t, 0, t->n_pts - 1, 0);
    free(t->idx_buf); t->idx_buf = NULL;
    return (long long)t->n_pts;
}

// === Nearest-neighbor query ===

static double _dist2(const double *a, const double *b) {
    double dx = a[0]-b[0], dy = a[1]-b[1], dz = a[2]-b[2];
    return dx*dx + dy*dy + dz*dz;
}

static void _nn_recurse(NKDT *t, int node, const double *q,
                        int *best_idx, double *best_d2)
{
    if (node < 0) return;
    _KDTNode *n = &t->nodes[node];
    double *p = t->pts + n->point_idx * 3;
    double d2 = _dist2(p, q);
    if (d2 < *best_d2) { *best_d2 = d2; *best_idx = n->point_idx; }
    int axis = n->axis;
    double diff = q[axis] - p[axis];
    int near = (diff < 0) ? n->left  : n->right;
    int far  = (diff < 0) ? n->right : n->left;
    _nn_recurse(t, near, q, best_idx, best_d2);
    if (diff * diff < *best_d2) _nn_recurse(t, far, q, best_idx, best_d2);
}

long long nuc_kdt_nearest(long long h, long long x_b, long long y_b, long long z_b) {
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t || t->n_pts == 0 || t->root < 0) return -1;
    double q[3] = { _i2f(x_b), _i2f(y_b), _i2f(z_b) };
    int best_idx = -1;
    double best_d2 = INFINITY;
    _nn_recurse(t, t->root, q, &best_idx, &best_d2);
    return (long long)best_idx;
}

// === k-NN query: max-heap on squared distance ===

typedef struct { double d2; int idx; } _KNNItem;

static void _heap_push(_KNNItem *heap, int *size, int cap, int idx, double d2) {
    if (*size < cap) {
        int i = (*size)++;
        heap[i].idx = idx; heap[i].d2 = d2;
        while (i > 0) {
            int parent = (i - 1) / 2;
            if (heap[parent].d2 < heap[i].d2) {
                _KNNItem tmp = heap[parent];
                heap[parent] = heap[i]; heap[i] = tmp;
                i = parent;
            } else break;
        }
    } else if (d2 < heap[0].d2) {
        heap[0].idx = idx; heap[0].d2 = d2;
        int i = 0;
        for (;;) {
            int l = 2*i + 1, r = 2*i + 2, largest = i;
            if (l < cap && heap[l].d2 > heap[largest].d2) largest = l;
            if (r < cap && heap[r].d2 > heap[largest].d2) largest = r;
            if (largest != i) {
                _KNNItem tmp = heap[largest];
                heap[largest] = heap[i]; heap[i] = tmp;
                i = largest;
            } else break;
        }
    }
}

static void _knn_recurse(NKDT *t, int node, const double *q, int k,
                         _KNNItem *heap, int *heap_size)
{
    if (node < 0) return;
    _KDTNode *n = &t->nodes[node];
    double *p = t->pts + n->point_idx * 3;
    double d2 = _dist2(p, q);
    _heap_push(heap, heap_size, k, n->point_idx, d2);
    int axis = n->axis;
    double diff = q[axis] - p[axis];
    int near = (diff < 0) ? n->left  : n->right;
    int far  = (diff < 0) ? n->right : n->left;
    _knn_recurse(t, near, q, k, heap, heap_size);
    double worst = (*heap_size < k) ? INFINITY : heap[0].d2;
    if (diff * diff < worst) _knn_recurse(t, far, q, k, heap, heap_size);
}

static int _cmp_knn_asc(const void *a, const void *b) {
    double da = ((const _KNNItem *)a)->d2;
    double db = ((const _KNNItem *)b)->d2;
    if (da < db) return -1;
    if (da > db) return 1;
    return 0;
}

long long nuc_kdt_knearest(long long h, long long x_b, long long y_b, long long z_b,
    long long k_, long long out_indices_ptr, long long out_dist2_ptr)
{
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t || t->n_pts == 0 || t->root < 0) return 0;
    int k = (int)k_;
    if (k <= 0) return 0;
    if (k > t->n_pts) k = t->n_pts;
    double q[3] = { _i2f(x_b), _i2f(y_b), _i2f(z_b) };
    _KNNItem *heap = (_KNNItem *)malloc(k * sizeof(_KNNItem));
    int heap_size = 0;
    _knn_recurse(t, t->root, q, k, heap, &heap_size);
    qsort(heap, heap_size, sizeof(_KNNItem), _cmp_knn_asc);
    long long *oi = (long long *)(void *)(size_t)out_indices_ptr;
    double    *od = (double    *)(void *)(size_t)out_dist2_ptr;
    for (int i = 0; i < heap_size; i++) {
        if (oi) oi[i] = (long long)heap[i].idx;
        if (od) od[i] = heap[i].d2;
    }
    free(heap);
    return (long long)heap_size;
}

void nuc_kdt_free(long long h) {
    NKDT *t = (NKDT *)(void *)(size_t)h;
    if (!t) return;
    if (t->pts)     free(t->pts);
    if (t->nodes)   free(t->nodes);
    if (t->idx_buf) free(t->idx_buf);
    free(t);
}
