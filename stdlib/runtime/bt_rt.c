// bt_rt.c — Behavior tree for robot behavior coordination.
//
// THE standard pattern for modern robot behavior orchestration
// (Colledanchise & Ögren 2018). A tree of:
//
//   Composite nodes:
//     SEQUENCE   — tick children in order; FAIL on first failure,
//                  SUCCESS only when all succeed.
//     SELECTOR   — tick children in order; SUCCESS on first success,
//                  FAIL only when all fail.
//     PARALLEL   — tick all children; SUCCESS when k of them succeed,
//                  FAIL when n-k+1 fail.
//
//   Decorators:
//     INVERTER   — flips SUCCESS ↔ FAILURE of single child.
//
//   Leaves:
//     ACTION     — user callback returning SUCCESS / FAILURE / RUNNING.
//     CONDITION  — user callback returning SUCCESS / FAILURE.
//
// Behavior trees compose readably from these primitives, support
// reactive (re-tick from root every cycle), and gracefully handle
// long-running actions (RUNNING status).
//
// Foundation for: pick-and-place sequencing (sequence: detect →
// approach → grasp → lift → move → release), reactive obstacle
// avoidance (selector: avoid_if_close, else proceed), task
// scheduling, error recovery (selector: try main plan; if FAIL,
// fall back to recovery).
//
// Limitations (blackboard-style data sharing between nodes
// + dynamic tree restructuring land in v0.6 if needed):
// - No blackboard; user passes shared state via the callback
//   context pointer (one void* per tick).
// - Static tree — built once, ticked many times.
//
// Compile: clang -c stdlib/runtime/bt_rt.c -o target/bt.obj -O2

#include <stdlib.h>
#include <string.h>

static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }
static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

#define _BT_TYPE_SEQUENCE  0
#define _BT_TYPE_SELECTOR  1
#define _BT_TYPE_PARALLEL  2
#define _BT_TYPE_INVERTER  3
#define _BT_TYPE_ACTION    4
#define _BT_TYPE_CONDITION 5

#define _BT_STATUS_SUCCESS 0
#define _BT_STATUS_FAILURE 1
#define _BT_STATUS_RUNNING 2

typedef long long (*bt_callback_t)(long long ctx_ptr);

typedef struct {
    int type;
    int *children;       // child indices
    int n_children, cap_children;
    bt_callback_t callback;  // for ACTION / CONDITION
    int parallel_k;      // for PARALLEL: succeed when k of n succeed
} _BTNode;

typedef struct {
    int n_nodes, cap_nodes;
    _BTNode *nodes;
} NBT;

long long nuc_bt_new(void) {
    NBT *t = (NBT *)calloc(1, sizeof(NBT));
    t->cap_nodes = 16;
    t->nodes = (_BTNode *)calloc(t->cap_nodes, sizeof(_BTNode));
    return (long long)(size_t)t;
}

static int _alloc_node(NBT *t, int type) {
    if (t->n_nodes >= t->cap_nodes) {
        t->cap_nodes *= 2;
        t->nodes = (_BTNode *)realloc(t->nodes, t->cap_nodes * sizeof(_BTNode));
    }
    int idx = t->n_nodes++;
    _BTNode *n = &t->nodes[idx];
    memset(n, 0, sizeof(*n));
    n->type = type;
    n->cap_children = 4;
    n->children = (int *)calloc(n->cap_children, sizeof(int));
    return idx;
}

// Add a child to a composite node (sequence/selector/parallel) or
// inverter. Returns 0 on success.
static long long _add_child(NBT *t, int parent_idx, int child_idx) {
    if (parent_idx < 0 || parent_idx >= t->n_nodes) return -1;
    if (child_idx < 0  || child_idx  >= t->n_nodes) return -1;
    _BTNode *p = &t->nodes[parent_idx];
    if (p->n_children >= p->cap_children) {
        p->cap_children *= 2;
        p->children = (int *)realloc(p->children, p->cap_children * sizeof(int));
    }
    p->children[p->n_children++] = child_idx;
    return 0;
}

long long nuc_bt_add_sequence(long long h, long long parent) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_SEQUENCE);
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

long long nuc_bt_add_selector(long long h, long long parent) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_SELECTOR);
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

long long nuc_bt_add_parallel(long long h, long long parent, long long k) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_PARALLEL);
    t->nodes[idx].parallel_k = (int)k;
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

long long nuc_bt_add_inverter(long long h, long long parent) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_INVERTER);
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

long long nuc_bt_add_action(long long h, long long parent, long long callback_fp) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_ACTION);
    t->nodes[idx].callback = (bt_callback_t)(void *)(size_t)callback_fp;
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

long long nuc_bt_add_condition(long long h, long long parent, long long callback_fp) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return -1;
    int idx = _alloc_node(t, _BT_TYPE_CONDITION);
    t->nodes[idx].callback = (bt_callback_t)(void *)(size_t)callback_fp;
    if (parent >= 0) _add_child(t, (int)parent, idx);
    return (long long)idx;
}

// Recursively tick a node; returns SUCCESS / FAILURE / RUNNING.
static int _tick(NBT *t, int idx, long long ctx) {
    if (idx < 0 || idx >= t->n_nodes) return _BT_STATUS_FAILURE;
    _BTNode *n = &t->nodes[idx];
    switch (n->type) {
        case _BT_TYPE_ACTION:
        case _BT_TYPE_CONDITION: {
            if (!n->callback) return _BT_STATUS_FAILURE;
            return (int)n->callback(ctx);
        }
        case _BT_TYPE_SEQUENCE: {
            for (int i = 0; i < n->n_children; i++) {
                int s = _tick(t, n->children[i], ctx);
                if (s == _BT_STATUS_FAILURE) return _BT_STATUS_FAILURE;
                if (s == _BT_STATUS_RUNNING) return _BT_STATUS_RUNNING;
            }
            return _BT_STATUS_SUCCESS;
        }
        case _BT_TYPE_SELECTOR: {
            for (int i = 0; i < n->n_children; i++) {
                int s = _tick(t, n->children[i], ctx);
                if (s == _BT_STATUS_SUCCESS) return _BT_STATUS_SUCCESS;
                if (s == _BT_STATUS_RUNNING) return _BT_STATUS_RUNNING;
            }
            return _BT_STATUS_FAILURE;
        }
        case _BT_TYPE_PARALLEL: {
            int n_succ = 0, n_fail = 0;
            for (int i = 0; i < n->n_children; i++) {
                int s = _tick(t, n->children[i], ctx);
                if (s == _BT_STATUS_SUCCESS) n_succ++;
                else if (s == _BT_STATUS_FAILURE) n_fail++;
            }
            int k = n->parallel_k;
            if (n_succ >= k) return _BT_STATUS_SUCCESS;
            if (n_fail > n->n_children - k) return _BT_STATUS_FAILURE;
            return _BT_STATUS_RUNNING;
        }
        case _BT_TYPE_INVERTER: {
            if (n->n_children == 0) return _BT_STATUS_FAILURE;
            int s = _tick(t, n->children[0], ctx);
            if (s == _BT_STATUS_SUCCESS) return _BT_STATUS_FAILURE;
            if (s == _BT_STATUS_FAILURE) return _BT_STATUS_SUCCESS;
            return _BT_STATUS_RUNNING;
        }
    }
    return _BT_STATUS_FAILURE;
}

// Tick the tree from the given root node. Returns the resulting
// status: 0 = SUCCESS, 1 = FAILURE, 2 = RUNNING.
//
// `ctx` is an opaque pointer passed to every leaf callback —
// typically the user's shared state (robot pose, sensor readings,
// etc.).
long long nuc_bt_tick(long long h, long long root_idx, long long ctx) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return _BT_STATUS_FAILURE;
    return (long long)_tick(t, (int)root_idx, ctx);
}

long long nuc_bt_node_count(long long h) {
    NBT *t = (NBT *)(void *)(size_t)h;
    return t ? (long long)t->n_nodes : 0;
}

void nuc_bt_free(long long h) {
    NBT *t = (NBT *)(void *)(size_t)h;
    if (!t) return;
    for (int i = 0; i < t->n_nodes; i++) {
        if (t->nodes[i].children) free(t->nodes[i].children);
    }
    if (t->nodes) free(t->nodes);
    free(t);
}
