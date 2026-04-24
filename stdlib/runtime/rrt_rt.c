// rrt_rt.c — RRT (Rapidly-exploring Random Tree) motion planner.
//
// LaValle 1998. Build a tree rooted at the start configuration in
// joint space, repeatedly sampling random configurations and
// extending the nearest tree node toward the sample by a small
// step. When the goal is reachable from any tree node within one
// step, success.
//
// The collision check is supplied by the caller as a function
// pointer (i64 → i64 — given a joint-config offset into the
// scratch-vars array, return 1 if collision, 0 if free). This
// keeps RRT decoupled from the specific robot/world model.
//
// All configurations live in a single flat double[] (n_dim doubles
// per node). The tree edges are encoded by a parent-index array.
//
// Returns 1 on success (path found), 0 on failure. Path is read
// back via nuc_rrt_path_len + nuc_rrt_path_at.
//
// Compile: clang -c stdlib/runtime/rrt_rt.c -o target/rrt.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n_dim;
    int capacity;
    int count;
    double *configs;   // n_dim * capacity doubles
    int *parents;      // capacity ints; parents[i] = parent index, or -1 for root
    double *lower;     // n_dim — sampling lower bound per dimension
    double *upper;     // n_dim — sampling upper bound per dimension
    int *path_indices; // populated on success; root → goal traversal
    int path_len;
    unsigned int rng_state;
} NRRT;

static double _rng_unit(NRRT *r) {
    // xorshift32 → [0, 1).
    r->rng_state ^= r->rng_state << 13;
    r->rng_state ^= r->rng_state >> 17;
    r->rng_state ^= r->rng_state << 5;
    return (double)r->rng_state / 4294967296.0;
}

static void _ensure_capacity(NRRT *r) {
    if (r->count < r->capacity) return;
    int new_cap = r->capacity * 2;
    r->configs = (double *)realloc(r->configs, new_cap * r->n_dim * sizeof(double));
    r->parents = (int *)realloc(r->parents, new_cap * sizeof(int));
    r->capacity = new_cap;
}

static int _nearest(NRRT *r, double *target) {
    int best = 0;
    double best_d2 = INFINITY;
    for (int i = 0; i < r->count; i++) {
        double d2 = 0;
        double *c = r->configs + i * r->n_dim;
        for (int k = 0; k < r->n_dim; k++) {
            double d = c[k] - target[k];
            d2 += d * d;
        }
        if (d2 < best_d2) { best_d2 = d2; best = i; }
    }
    return best;
}

long long nuc_rrt_new(long long n_dim, long long seed) {
    NRRT *r = (NRRT *)calloc(1, sizeof(NRRT));
    r->n_dim = (int)n_dim;
    r->capacity = 64;
    r->configs = (double *)malloc(r->capacity * r->n_dim * sizeof(double));
    r->parents = (int *)malloc(r->capacity * sizeof(int));
    r->lower = (double *)calloc(r->n_dim, sizeof(double));
    r->upper = (double *)calloc(r->n_dim, sizeof(double));
    for (int k = 0; k < r->n_dim; k++) { r->lower[k] = -3.14159265358979; r->upper[k] = 3.14159265358979; }
    r->rng_state = (unsigned int)seed;
    if (r->rng_state == 0) r->rng_state = 0x9E3779B9;
    return (long long)(size_t)r;
}

void nuc_rrt_set_bounds(long long h, long long dim, long long lo_bits, long long hi_bits) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || dim < 0 || dim >= r->n_dim) return;
    r->lower[dim] = _i2f(lo_bits);
    r->upper[dim] = _i2f(hi_bits);
}

// Add the root configuration. Caller passes a pointer to a
// double[n_dim] holding the start joint values.
long long nuc_rrt_set_root(long long h, long long start_ptr) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r) return -1;
    double *start = (double *)(void *)(size_t)start_ptr;
    memcpy(r->configs, start, r->n_dim * sizeof(double));
    r->parents[0] = -1;
    r->count = 1;
    return 0;
}

// Plan: extend toward random samples for at most max_iters,
// stopping when the tree has any node within step_size of the goal.
// `is_collision_free_fp` is a function pointer — given a malloc'd
// double[n_dim] pointer (as i64), returns 1 if the configuration
// is collision-free, 0 if in collision.
//
// Returns 1 on success, 0 on failure.
typedef long long (*coll_fn_t)(long long);

long long nuc_rrt_plan(
    long long h, long long goal_ptr,
    long long max_iters,
    long long step_bits,
    long long is_collision_free_fp)
{
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || r->count == 0) return 0;
    double *goal = (double *)(void *)(size_t)goal_ptr;
    double step = _i2f(step_bits);
    coll_fn_t coll_free = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    double *new_cfg = (double *)malloc(r->n_dim * sizeof(double));
    int success = 0;
    int goal_index = -1;
    for (long long it = 0; it < max_iters && !success; it++) {
        // Goal-biased sampling (10% pull toward goal).
        if (_rng_unit(r) < 0.1) {
            memcpy(sample, goal, r->n_dim * sizeof(double));
        } else {
            for (int k = 0; k < r->n_dim; k++) {
                sample[k] = r->lower[k] + _rng_unit(r) * (r->upper[k] - r->lower[k]);
            }
        }
        int near = _nearest(r, sample);
        double *near_cfg = r->configs + near * r->n_dim;
        // Step from near_cfg toward sample by `step` distance.
        double dist = 0;
        for (int k = 0; k < r->n_dim; k++) {
            double d = sample[k] - near_cfg[k];
            dist += d * d;
        }
        dist = sqrt(dist);
        if (dist < 1e-9) continue;
        double scale = (dist <= step) ? 1.0 : (step / dist);
        for (int k = 0; k < r->n_dim; k++) {
            new_cfg[k] = near_cfg[k] + (sample[k] - near_cfg[k]) * scale;
        }
        // Collision check.
        long long is_free = 1;
        if (coll_free) is_free = coll_free((long long)(size_t)new_cfg);
        if (!is_free) continue;
        // Add to tree.
        _ensure_capacity(r);
        memcpy(r->configs + r->count * r->n_dim, new_cfg, r->n_dim * sizeof(double));
        r->parents[r->count] = near;
        int new_idx = r->count;
        r->count++;
        // Goal check.
        double goal_d2 = 0;
        for (int k = 0; k < r->n_dim; k++) {
            double d = new_cfg[k] - goal[k];
            goal_d2 += d * d;
        }
        if (goal_d2 <= step * step) {
            success = 1;
            goal_index = new_idx;
        }
    }
    free(sample); free(new_cfg);
    if (!success) return 0;
    // Reconstruct path: walk parents from goal_index back to root.
    int n_nodes = 0;
    for (int i = goal_index; i != -1; i = r->parents[i]) n_nodes++;
    if (r->path_indices) free(r->path_indices);
    r->path_indices = (int *)malloc(n_nodes * sizeof(int));
    r->path_len = n_nodes;
    int p = n_nodes - 1;
    for (int i = goal_index; i != -1; i = r->parents[i]) r->path_indices[p--] = i;
    return 1;
}

long long nuc_rrt_path_len(long long h) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    return (r && r->path_indices) ? (long long)r->path_len : 0;
}

// Get the value at (path_index, dim) — useful for reading the
// solved path one node at a time.
long long nuc_rrt_path_at(long long h, long long path_idx, long long dim) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || !r->path_indices) return 0;
    if (path_idx < 0 || path_idx >= r->path_len) return 0;
    if (dim < 0 || dim >= r->n_dim) return 0;
    int node = r->path_indices[path_idx];
    return _f2i(r->configs[node * r->n_dim + dim]);
}

long long nuc_rrt_node_count(long long h) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    return r ? (long long)r->count : 0;
}

void nuc_rrt_free(long long h) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r) return;
    free(r->configs); free(r->parents);
    free(r->lower); free(r->upper);
    if (r->path_indices) free(r->path_indices);
    free(r);
}
