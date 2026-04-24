// bvh_rt.c — Bounding Volume Hierarchy for broad-phase collision.
//
// Stores N axis-aligned bounding boxes (AABBs) and builds a binary
// tree where each internal node's box contains the boxes of its
// children. Query operations:
//   - Overlap query: given an AABB, return all stored AABB indices
//     whose boxes overlap.
//   - Pair query: return all stored-AABB index pairs (i, j) i < j
//     whose boxes overlap.
//
// Build is top-down median split along the longest axis (object
// median). O(N log N) typical.
//
// Companion to `collision.nr`'s narrow-phase primitives — use BVH
// to cull non-overlapping object pairs cheaply, then apply the
// narrow-phase test to the surviving candidates.
//
// Compile: clang -c stdlib/runtime/bvh_rt.c -o target/bvh.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double minx, miny, minz;
    double maxx, maxy, maxz;
} Box;

typedef struct {
    Box box;
    int left, right;   // -1 if leaf; else child indices into nodes[]
    int leaf_index;    // index into the user's input array (only when leaf)
} Node;

typedef struct {
    Box *boxes;
    int *user_index;   // map: leaf -> user-provided id
    int n_boxes;
    int cap_boxes;
    Node *nodes;
    int n_nodes;
    int cap_nodes;
    int root;
    // Query result buffer (reused across calls).
    int *query_result;
    int query_count;
    int query_cap;
    // Pair query buffers (lo, hi).
    int *pair_lo;
    int *pair_hi;
    int pair_count;
    int pair_cap;
} BVH;

static int _box_overlap(const Box *a, const Box *b) {
    if (a->maxx < b->minx || a->minx > b->maxx) return 0;
    if (a->maxy < b->miny || a->miny > b->maxy) return 0;
    if (a->maxz < b->minz || a->minz > b->maxz) return 0;
    return 1;
}

static void _box_combine(const Box *a, const Box *b, Box *out) {
    out->minx = a->minx < b->minx ? a->minx : b->minx;
    out->miny = a->miny < b->miny ? a->miny : b->miny;
    out->minz = a->minz < b->minz ? a->minz : b->minz;
    out->maxx = a->maxx > b->maxx ? a->maxx : b->maxx;
    out->maxy = a->maxy > b->maxy ? a->maxy : b->maxy;
    out->maxz = a->maxz > b->maxz ? a->maxz : b->maxz;
}

long long nuc_bvh_new(void) {
    BVH *b = (BVH *)calloc(1, sizeof(BVH));
    return (long long)(size_t)b;
}

// Add an AABB. Returns the user index slot (auto-incrementing).
long long nuc_bvh_add(long long h,
    long long minx_b, long long miny_b, long long minz_b,
    long long maxx_b, long long maxy_b, long long maxz_b)
{
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b) return -1;
    if (b->n_boxes >= b->cap_boxes) {
        b->cap_boxes = b->cap_boxes == 0 ? 16 : b->cap_boxes * 2;
        b->boxes = (Box *)realloc(b->boxes, b->cap_boxes * sizeof(Box));
        b->user_index = (int *)realloc(b->user_index, b->cap_boxes * sizeof(int));
    }
    Box *box = &b->boxes[b->n_boxes];
    box->minx = _i2f(minx_b); box->miny = _i2f(miny_b); box->minz = _i2f(minz_b);
    box->maxx = _i2f(maxx_b); box->maxy = _i2f(maxy_b); box->maxz = _i2f(maxz_b);
    b->user_index[b->n_boxes] = b->n_boxes;
    return (long long)b->n_boxes++;
}

static int _build_recursive(BVH *b, int *indices, int start, int end) {
    if (b->n_nodes >= b->cap_nodes) {
        b->cap_nodes = b->cap_nodes == 0 ? 32 : b->cap_nodes * 2;
        b->nodes = (Node *)realloc(b->nodes, b->cap_nodes * sizeof(Node));
    }
    int node_idx = b->n_nodes++;
    Node *node = &b->nodes[node_idx];
    if (end - start == 1) {
        // Leaf.
        node->box = b->boxes[indices[start]];
        node->left = -1;
        node->right = -1;
        node->leaf_index = indices[start];
        return node_idx;
    }
    // Compute combined box + pick the longest axis.
    Box combined = b->boxes[indices[start]];
    for (int i = start + 1; i < end; i++) {
        Box tmp = combined;
        _box_combine(&tmp, &b->boxes[indices[i]], &combined);
    }
    double dx = combined.maxx - combined.minx;
    double dy = combined.maxy - combined.miny;
    double dz = combined.maxz - combined.minz;
    int axis = 0;
    if (dy > dx && dy > dz) axis = 1;
    else if (dz > dx && dz > dy) axis = 2;
    // Sort indices [start, end) along axis center.
    // Simple insertion sort — fine for typical scene sizes.
    for (int i = start + 1; i < end; i++) {
        int key = indices[i];
        Box *kb = &b->boxes[key];
        double k = (axis == 0) ? (kb->minx + kb->maxx)
                : (axis == 1) ? (kb->miny + kb->maxy)
                              : (kb->minz + kb->maxz);
        int j = i - 1;
        while (j >= start) {
            Box *jb = &b->boxes[indices[j]];
            double jk = (axis == 0) ? (jb->minx + jb->maxx)
                     : (axis == 1) ? (jb->miny + jb->maxy)
                                   : (jb->minz + jb->maxz);
            if (jk <= k) break;
            indices[j + 1] = indices[j];
            j--;
        }
        indices[j + 1] = key;
    }
    int mid = (start + end) / 2;
    int left = _build_recursive(b, indices, start, mid);
    int right = _build_recursive(b, indices, mid, end);
    // Re-fetch (realloc may have moved nodes[]).
    node = &b->nodes[node_idx];
    Box left_box = b->nodes[left].box;
    Box right_box = b->nodes[right].box;
    _box_combine(&left_box, &right_box, &node->box);
    node->left = left;
    node->right = right;
    node->leaf_index = -1;
    return node_idx;
}

long long nuc_bvh_build(long long h) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || b->n_boxes == 0) return -1;
    if (b->nodes) { free(b->nodes); b->nodes = NULL; b->n_nodes = 0; b->cap_nodes = 0; }
    int *indices = (int *)malloc(b->n_boxes * sizeof(int));
    for (int i = 0; i < b->n_boxes; i++) indices[i] = i;
    b->root = _build_recursive(b, indices, 0, b->n_boxes);
    free(indices);
    return 0;
}

static void _q_push(BVH *b, int idx) {
    if (b->query_count >= b->query_cap) {
        b->query_cap = b->query_cap == 0 ? 16 : b->query_cap * 2;
        b->query_result = (int *)realloc(b->query_result, b->query_cap * sizeof(int));
    }
    b->query_result[b->query_count++] = idx;
}

static void _query_recursive(BVH *b, int node_idx, const Box *q) {
    Node *n = &b->nodes[node_idx];
    if (!_box_overlap(&n->box, q)) return;
    if (n->left == -1) { _q_push(b, n->leaf_index); return; }
    _query_recursive(b, n->left, q);
    _query_recursive(b, n->right, q);
}

// Run an overlap query against the BVH. Returns the number of
// hit indices; caller reads them via nuc_bvh_query_at.
long long nuc_bvh_query(long long h,
    long long minx_b, long long miny_b, long long minz_b,
    long long maxx_b, long long maxy_b, long long maxz_b)
{
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || !b->nodes) return 0;
    Box q = {
        _i2f(minx_b), _i2f(miny_b), _i2f(minz_b),
        _i2f(maxx_b), _i2f(maxy_b), _i2f(maxz_b)
    };
    b->query_count = 0;
    _query_recursive(b, b->root, &q);
    return (long long)b->query_count;
}

long long nuc_bvh_query_at(long long h, long long i) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || !b->query_result || i < 0 || i >= b->query_count) return -1;
    return (long long)b->query_result[i];
}

static void _p_push(BVH *b, int lo, int hi) {
    if (b->pair_count >= b->pair_cap) {
        b->pair_cap = b->pair_cap == 0 ? 16 : b->pair_cap * 2;
        b->pair_lo = (int *)realloc(b->pair_lo, b->pair_cap * sizeof(int));
        b->pair_hi = (int *)realloc(b->pair_hi, b->pair_cap * sizeof(int));
    }
    b->pair_lo[b->pair_count] = lo;
    b->pair_hi[b->pair_count] = hi;
    b->pair_count++;
}

static void _pair_recursive(BVH *b, int a_idx, int b_idx) {
    Node *na = &b->nodes[a_idx];
    Node *nb = &b->nodes[b_idx];
    if (!_box_overlap(&na->box, &nb->box)) return;
    int a_leaf = (na->left == -1);
    int b_leaf = (nb->left == -1);
    if (a_leaf && b_leaf) {
        if (na->leaf_index < nb->leaf_index) _p_push(b, na->leaf_index, nb->leaf_index);
        else _p_push(b, nb->leaf_index, na->leaf_index);
        return;
    }
    if (a_leaf) {
        _pair_recursive(b, a_idx, nb->left);
        _pair_recursive(b, a_idx, nb->right);
        return;
    }
    if (b_leaf) {
        _pair_recursive(b, na->left, b_idx);
        _pair_recursive(b, na->right, b_idx);
        return;
    }
    _pair_recursive(b, na->left, nb->left);
    _pair_recursive(b, na->left, nb->right);
    _pair_recursive(b, na->right, nb->left);
    _pair_recursive(b, na->right, nb->right);
}

static void _self_pair_recursive(BVH *b, int node_idx) {
    Node *n = &b->nodes[node_idx];
    if (n->left == -1) return;
    _self_pair_recursive(b, n->left);
    _self_pair_recursive(b, n->right);
    _pair_recursive(b, n->left, n->right);
}

// Self-pair query: return all (i, j) i < j where stored boxes
// overlap. Result is consumed via nuc_bvh_pair_count + lo/hi
// accessors.
long long nuc_bvh_self_pairs(long long h) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || !b->nodes) return 0;
    b->pair_count = 0;
    _self_pair_recursive(b, b->root);
    return (long long)b->pair_count;
}

long long nuc_bvh_pair_lo(long long h, long long i) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || !b->pair_lo || i < 0 || i >= b->pair_count) return -1;
    return (long long)b->pair_lo[i];
}

long long nuc_bvh_pair_hi(long long h, long long i) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b || !b->pair_hi || i < 0 || i >= b->pair_count) return -1;
    return (long long)b->pair_hi[i];
}

void nuc_bvh_free(long long h) {
    BVH *b = (BVH *)(void *)(size_t)h;
    if (!b) return;
    if (b->boxes) free(b->boxes);
    if (b->user_index) free(b->user_index);
    if (b->nodes) free(b->nodes);
    if (b->query_result) free(b->query_result);
    if (b->pair_lo) free(b->pair_lo);
    if (b->pair_hi) free(b->pair_hi);
    free(b);
}
