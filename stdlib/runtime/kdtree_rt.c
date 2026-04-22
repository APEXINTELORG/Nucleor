// kdtree_rt.c — K-D Tree Spatial Index for Nucleor
// Build, k-nearest-neighbor search, range search.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/kdtree_rt.c -o target/kdtree_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _kd_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _kd_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } KDVec;

static void kdvec_push(KDVec *v, long long val) {
    if (v->len >= v->cap) { v->cap = v->cap * 2 + 8; v->data = (long long *)realloc(v->data, v->cap * sizeof(long long)); }
    v->data[v->len++] = val;
}

// ================================================================
//  K-D Tree Node
// ================================================================

typedef struct KDNode KDNode;
struct KDNode {
    double *point;   // dim-dimensional point
    int index;       // original index in input array
    int split_dim;
    KDNode *left, *right;
};

typedef struct {
    KDNode *root;
    int dim;
    int n_points;
} KDTree;

// ================================================================
//  Build
// ================================================================

static int kd_cmp_dim = 0;
static int kd_cmp(const void *a, const void *b) {
    double da = ((const double **)a)[0][kd_cmp_dim];
    double db = ((const double **)b)[0][kd_cmp_dim];
    return (da > db) - (da < db);
}

static KDNode *kd_build(double **points, int *indices, int n, int dim, int depth) {
    if (n <= 0) return NULL;
    int axis = depth % dim;

    // Sort by axis
    kd_cmp_dim = axis;
    // Simple selection of median
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (points[j][axis] < points[i][axis]) {
                double *tp = points[i]; points[i] = points[j]; points[j] = tp;
                int ti = indices[i]; indices[i] = indices[j]; indices[j] = ti;
            }

    int mid = n / 2;
    KDNode *node = (KDNode *)malloc(sizeof(KDNode));
    node->point = points[mid];
    node->index = indices[mid];
    node->split_dim = axis;
    node->left = kd_build(points, indices, mid, dim, depth + 1);
    node->right = kd_build(points + mid + 1, indices + mid + 1, n - mid - 1, dim, depth + 1);
    return node;
}

long long nuc_kd_build(long long points_h, long long n, long long dim) {
    KDVec *pts = (KDVec *)(void *)points_h;
    int N = (int)n, D = (int)dim;

    double **pp = (double **)malloc(N * sizeof(double *));
    int *indices = (int *)malloc(N * sizeof(int));
    for (int i = 0; i < N; i++) {
        pp[i] = (double *)malloc(D * sizeof(double));
        for (int j = 0; j < D; j++) pp[i][j] = _kd_i2f(pts->data[i * D + j]);
        indices[i] = i;
    }

    KDTree *tree = (KDTree *)malloc(sizeof(KDTree));
    tree->dim = D;
    tree->n_points = N;
    tree->root = kd_build(pp, indices, N, D, 0);
    free(pp); free(indices);
    return (long long)tree;
}

// ================================================================
//  K-Nearest-Neighbor Search
// ================================================================

typedef struct { int idx; double dist; } KNNEntry;

static void knn_search(KDNode *node, double *query, int dim, int k,
                        KNNEntry *best, int *best_count) {
    if (!node) return;

    double dist = 0;
    for (int i = 0; i < dim; i++) {
        double d = node->point[i] - query[i];
        dist += d * d;
    }
    dist = sqrt(dist);

    // Insert into best list
    if (*best_count < k || dist < best[*best_count - 1].dist) {
        int pos = *best_count < k ? (*best_count)++ : k - 1;
        best[pos].idx = node->index;
        best[pos].dist = dist;
        // Bubble sort to maintain order
        for (int i = pos; i > 0 && best[i].dist < best[i - 1].dist; i--) {
            KNNEntry t = best[i]; best[i] = best[i - 1]; best[i - 1] = t;
        }
    }

    int axis = node->split_dim;
    double diff = query[axis] - node->point[axis];
    KDNode *near = diff < 0 ? node->left : node->right;
    KDNode *far = diff < 0 ? node->right : node->left;

    knn_search(near, query, dim, k, best, best_count);

    double worst_dist = (*best_count < k) ? 1e30 : best[*best_count - 1].dist;
    if (fabs(diff) < worst_dist)
        knn_search(far, query, dim, k, best, best_count);
}

long long nuc_kd_nearest(long long tree_h, long long query_h, long long k) {
    KDTree *tree = (KDTree *)(void *)tree_h;
    KDVec *q = (KDVec *)(void *)query_h;
    int K = (int)k;
    double *query = (double *)malloc(tree->dim * sizeof(double));
    for (int i = 0; i < tree->dim && i < q->len; i++) query[i] = _kd_i2f(q->data[i]);

    KNNEntry *best = (KNNEntry *)malloc(K * sizeof(KNNEntry));
    int best_count = 0;
    knn_search(tree->root, query, tree->dim, K, best, &best_count);

    KDVec *result = (KDVec *)malloc(sizeof(KDVec));
    result->len = best_count; result->cap = best_count;
    result->data = (long long *)malloc(best_count * sizeof(long long));
    for (int i = 0; i < best_count; i++) result->data[i] = best[i].idx;

    free(query); free(best);
    return (long long)result;
}

// ================================================================
//  Range Search (all points within radius)
// ================================================================

static void range_search(KDNode *node, double *center, double radius, int dim, KDVec *results) {
    if (!node) return;

    double dist = 0;
    for (int i = 0; i < dim; i++) {
        double d = node->point[i] - center[i];
        dist += d * d;
    }
    dist = sqrt(dist);
    if (dist <= radius) kdvec_push(results, node->index);

    int axis = node->split_dim;
    double diff = center[axis] - node->point[axis];

    if (diff - radius <= 0) range_search(node->left, center, radius, dim, results);
    if (diff + radius >= 0) range_search(node->right, center, radius, dim, results);
}

long long nuc_kd_range_search(long long tree_h, long long center_h, long long radius_bits) {
    KDTree *tree = (KDTree *)(void *)tree_h;
    KDVec *c = (KDVec *)(void *)center_h;
    double radius = _kd_i2f(radius_bits);
    double *center = (double *)malloc(tree->dim * sizeof(double));
    for (int i = 0; i < tree->dim && i < c->len; i++) center[i] = _kd_i2f(c->data[i]);

    KDVec *results = (KDVec *)malloc(sizeof(KDVec));
    results->len = 0; results->cap = 64;
    results->data = (long long *)malloc(64 * sizeof(long long));

    range_search(tree->root, center, radius, tree->dim, results);
    free(center);
    return (long long)results;
}

static void kd_free_node(KDNode *node) {
    if (!node) return;
    kd_free_node(node->left);
    kd_free_node(node->right);
    // Don't free point — owned by caller
    free(node);
}

void nuc_kd_free(long long tree_h) {
    KDTree *tree = (KDTree *)(void *)tree_h;
    if (tree) { kd_free_node(tree->root); free(tree); }
}
