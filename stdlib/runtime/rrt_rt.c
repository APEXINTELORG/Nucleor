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

// RRT-Connect (Kuffner & LaValle 2000). Bidirectional variant of
// RRT that grows two trees — one from the start, one from the
// goal — and tries to connect them. Typically converges 5-10x
// faster than vanilla RRT on hard problems.
//
// Implementation: each iteration alternates which tree extends.
// The active tree picks a random sample, extends toward it, then
// the OTHER tree tries to "connect" all the way to the new node
// (taking as many steps as needed without sampling). On
// successful connection, walk back from the connection point in
// each tree to assemble the bidirectional path.
//
// Builds on the existing NRRT struct + helpers; uses TWO NRRT
// instances internally and stitches their paths.
//
// Returns 1 on success (connected), 0 on failure. Path is read
// back via the FIRST tree's path_indices (which has been
// rewritten to hold the full path).

static int _extend_toward(NRRT *r, double *target, double step,
                          coll_fn_t coll_free, double **out_new_cfg)
{
    int near = _nearest(r, target);
    double *near_cfg = r->configs + near * r->n_dim;
    double dist = 0;
    for (int k = 0; k < r->n_dim; k++) {
        double d = target[k] - near_cfg[k];
        dist += d * d;
    }
    dist = sqrt(dist);
    if (dist < 1e-9) { *out_new_cfg = NULL; return -1; }
    double scale = (dist <= step) ? 1.0 : (step / dist);
    double *new_cfg = (double *)malloc(r->n_dim * sizeof(double));
    for (int k = 0; k < r->n_dim; k++) {
        new_cfg[k] = near_cfg[k] + (target[k] - near_cfg[k]) * scale;
    }
    if (coll_free && coll_free((long long)(size_t)new_cfg) == 0) {
        free(new_cfg);
        *out_new_cfg = NULL;
        return -1;
    }
    _ensure_capacity(r);
    memcpy(r->configs + r->count * r->n_dim, new_cfg, r->n_dim * sizeof(double));
    r->parents[r->count] = near;
    int idx = r->count++;
    *out_new_cfg = new_cfg;
    return idx;
}

// Plan with bidirectional RRT-Connect. Caller provides the goal
// configuration; we build TWO trees internally, both rooted at
// the existing tree's root. Connects them in joint space.
//
// Returns 1 on success, 0 on failure. The path is written back
// into r->path_indices as a sequence of node indices in the
// FIRST tree (start tree); the connection bridges to the goal
// tree but the user reads the configs flat from r->configs.
//
// This implementation builds the goal-tree separately and on
// success appends its path to the start-tree's path. For simplicity
// the goal-tree's nodes are concatenated into r->configs after
// the start tree finishes.
long long nuc_rrt_connect_plan(
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

    // Build a second tree rooted at the goal.
    NRRT g;
    memset(&g, 0, sizeof(NRRT));
    g.n_dim = r->n_dim;
    g.capacity = 64;
    g.configs = (double *)malloc(g.capacity * g.n_dim * sizeof(double));
    g.parents = (int *)malloc(g.capacity * sizeof(int));
    g.lower = (double *)malloc(g.n_dim * sizeof(double));
    g.upper = (double *)malloc(g.n_dim * sizeof(double));
    memcpy(g.lower, r->lower, g.n_dim * sizeof(double));
    memcpy(g.upper, r->upper, g.n_dim * sizeof(double));
    g.rng_state = r->rng_state ^ 0xDEADBEEF;
    if (g.rng_state == 0) g.rng_state = 0x1337C0DE;
    memcpy(g.configs, goal, g.n_dim * sizeof(double));
    g.parents[0] = -1;
    g.count = 1;

    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    NRRT *active = r;
    NRRT *other = &g;
    int success = 0;
    int active_idx = -1, other_idx = -1;

    for (long long it = 0; it < max_iters && !success; it++) {
        for (int k = 0; k < r->n_dim; k++) {
            sample[k] = active->lower[k] + _rng_unit(active) * (active->upper[k] - active->lower[k]);
        }
        double *new_cfg;
        int new_idx = _extend_toward(active, sample, step, coll_free, &new_cfg);
        if (new_idx < 0) {
            // Swap and continue.
            NRRT *tmp = active; active = other; other = tmp;
            continue;
        }
        // Try to connect `other` all the way to new_cfg.
        for (int connect_iter = 0; connect_iter < 64; connect_iter++) {
            double *connect_cfg;
            int oi = _extend_toward(other, new_cfg, step, coll_free, &connect_cfg);
            if (oi < 0) { free(new_cfg); break; }
            // Check: did we reach new_cfg?
            double *o_node = other->configs + oi * other->n_dim;
            double d = 0;
            for (int k = 0; k < other->n_dim; k++) {
                double dd = o_node[k] - new_cfg[k];
                d += dd * dd;
            }
            free(connect_cfg);
            if (d <= step * step) {
                success = 1;
                if (active == r) { active_idx = new_idx; other_idx = oi; }
                else             { active_idx = oi; other_idx = new_idx; }
                free(new_cfg);
                break;
            }
        }
        // Swap.
        NRRT *tmp = active; active = other; other = tmp;
    }
    free(sample);

    if (!success) {
        free(g.configs); free(g.parents); free(g.lower); free(g.upper);
        return 0;
    }

    // Reconstruct: walk parents in `r` from active_idx to root,
    // walk parents in `g` from other_idx to root, then stitch.
    int r_len = 0;
    for (int i = active_idx; i != -1; i = r->parents[i]) r_len++;
    int g_len = 0;
    for (int i = other_idx; i != -1; i = g.parents[i]) g_len++;

    // Append g's nodes to r's configs so the unified r->path_indices
    // can index them. Map g_idx -> r_idx via offset.
    int r_offset = r->count;
    while (r->count + g.count > r->capacity) {
        r->capacity *= 2;
        r->configs = (double *)realloc(r->configs, r->capacity * r->n_dim * sizeof(double));
        r->parents = (int *)realloc(r->parents, r->capacity * sizeof(int));
    }
    memcpy(r->configs + r_offset * r->n_dim, g.configs, g.count * g.n_dim * sizeof(double));
    // (parents copying not needed for path reconstruction since we walk g separately)
    for (int i = 0; i < g.count; i++) r->parents[r_offset + i] = -1;
    r->count += g.count;

    int total_len = r_len + g_len;
    if (r->path_indices) free(r->path_indices);
    r->path_indices = (int *)malloc(total_len * sizeof(int));
    r->path_len = total_len;

    int p = r_len - 1;
    for (int i = active_idx; i != -1; i = r->parents[i]) r->path_indices[p--] = i;
    p = r_len;
    for (int i = other_idx; i != -1; i = g.parents[i]) r->path_indices[p++] = i + r_offset;

    free(g.configs); free(g.parents); free(g.lower); free(g.upper);
    return 1;
}

// RRT* (Karaman & Frazzoli 2011). Asymptotically optimal variant
// of RRT: when a new node is added, neighbors within a search
// radius are checked, and (a) the new node is connected to the
// neighbor that gives the lowest cost-to-come, then (b) each
// neighbor checks whether routing through the new node would lower
// its own cost-to-come and rewires if so.
//
// Cost is path length in joint space. The rewire step gradually
// improves the tree's path quality as iterations accumulate. With
// enough samples the path converges to the optimum.
//
// Builds on the same NRRT struct as vanilla RRT; adds a per-node
// cost-to-come array allocated lazily.
//
// Returns the iteration count run (≤ max_iters). Path is reachable
// via the existing path_indices/len accessors after a goal-region
// check at the end.

static double *_rrt_cost = NULL;     // length = NRRT::capacity
static int _rrt_cost_for = -1;       // sentinel for "which NRRT this belongs to"

// Allocate / extend the cost-to-come array as the tree grows.
static void _ensure_cost_capacity(NRRT *r) {
    static int last_cap = 0;
    if (_rrt_cost_for != (int)(size_t)r || last_cap < r->capacity) {
        _rrt_cost = (double *)realloc(_rrt_cost, r->capacity * sizeof(double));
        last_cap = r->capacity;
        _rrt_cost_for = (int)(size_t)r;
    }
}

static double _node_dist_n(NRRT *r, int i, double *cfg) {
    double *ni = r->configs + i * r->n_dim;
    double s = 0;
    for (int k = 0; k < r->n_dim; k++) {
        double d = ni[k] - cfg[k];
        s += d * d;
    }
    return sqrt(s);
}

static int _segment_collision_free_n(NRRT *r, double *a, double *b,
                                     double step, coll_fn_t cf)
{
    if (!cf) return 1;
    double dist = 0;
    for (int k = 0; k < r->n_dim; k++) {
        double d = a[k] - b[k];
        dist += d * d;
    }
    dist = sqrt(dist);
    int n_steps = (int)(dist / step);
    if (n_steps < 1) n_steps = 1;
    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    long long sh = (long long)(size_t)sample;
    int ok = 1;
    for (int s = 1; s < n_steps; s++) {
        double t = (double)s / (double)n_steps;
        for (int k = 0; k < r->n_dim; k++) {
            sample[k] = a[k] + t * (b[k] - a[k]);
        }
        if (cf(sh) == 0) { ok = 0; break; }
    }
    free(sample);
    return ok;
}

long long nuc_rrt_star_plan(
    long long h, long long goal_ptr,
    long long max_iters,
    long long step_bits,
    long long radius_bits,
    long long is_collision_free_fp)
{
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || r->count == 0) return 0;
    double *goal = (double *)(void *)(size_t)goal_ptr;
    double step = _i2f(step_bits);
    double radius = _i2f(radius_bits);
    coll_fn_t cf = (coll_fn_t)(void *)(size_t)is_collision_free_fp;

    _ensure_cost_capacity(r);
    _rrt_cost[0] = 0; // root has zero cost-to-come

    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    double *new_cfg = (double *)malloc(r->n_dim * sizeof(double));
    int best_goal = -1;
    double best_goal_cost = 1e30;
    long long it;
    for (it = 0; it < max_iters; it++) {
        for (int k = 0; k < r->n_dim; k++) {
            sample[k] = r->lower[k] + _rng_unit(r) * (r->upper[k] - r->lower[k]);
        }
        // Steer toward sample by `step`.
        int near = _nearest(r, sample);
        double *near_cfg = r->configs + near * r->n_dim;
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
        if (cf && cf((long long)(size_t)new_cfg) == 0) continue;

        // Find all neighbors within `radius` of new_cfg.
        // Compute their candidate costs as parents.
        int best_parent = near;
        double best_parent_cost = _rrt_cost[near] +
            _node_dist_n(r, near, new_cfg);
        // Track neighbors for rewire phase.
        int neighbor_buf[64]; int n_neigh = 0;
        for (int i = 0; i < r->count; i++) {
            double d = _node_dist_n(r, i, new_cfg);
            if (d > radius) continue;
            if (n_neigh < 64) neighbor_buf[n_neigh++] = i;
            double cand = _rrt_cost[i] + d;
            if (cand < best_parent_cost) {
                if (_segment_collision_free_n(r, r->configs + i * r->n_dim,
                                              new_cfg, step, cf)) {
                    best_parent_cost = cand;
                    best_parent = i;
                }
            }
        }
        // Add the new node.
        _ensure_capacity(r);
        _ensure_cost_capacity(r);
        memcpy(r->configs + r->count * r->n_dim, new_cfg, r->n_dim * sizeof(double));
        r->parents[r->count] = best_parent;
        _rrt_cost[r->count] = best_parent_cost;
        int new_idx = r->count;
        r->count++;
        // Rewire phase: for each neighbor, check whether routing
        // through new_idx improves its cost.
        for (int q = 0; q < n_neigh; q++) {
            int n_i = neighbor_buf[q];
            if (n_i == best_parent) continue;
            double d = _node_dist_n(r, n_i, new_cfg);
            double cand = _rrt_cost[new_idx] + d;
            if (cand < _rrt_cost[n_i]) {
                if (_segment_collision_free_n(r, new_cfg,
                                              r->configs + n_i * r->n_dim,
                                              step, cf)) {
                    r->parents[n_i] = new_idx;
                    _rrt_cost[n_i] = cand;
                }
            }
        }
        // Track best goal candidate.
        double goal_d = 0;
        for (int k = 0; k < r->n_dim; k++) {
            double dd = new_cfg[k] - goal[k];
            goal_d += dd * dd;
        }
        if (goal_d <= step * step) {
            double total = _rrt_cost[new_idx] + sqrt(goal_d);
            if (total < best_goal_cost) {
                best_goal = new_idx;
                best_goal_cost = total;
            }
        }
    }
    free(sample); free(new_cfg);
    if (best_goal < 0) return 0;
    // Reconstruct path through best goal node.
    int n_nodes = 0;
    for (int i = best_goal; i != -1; i = r->parents[i]) n_nodes++;
    if (r->path_indices) free(r->path_indices);
    r->path_indices = (int *)malloc(n_nodes * sizeof(int));
    r->path_len = n_nodes;
    int p = n_nodes - 1;
    for (int i = best_goal; i != -1; i = r->parents[i]) r->path_indices[p--] = i;
    return 1;
}

// === Informed RRT* (v0.2.248) ==========================================
//
// Gammell, Srinivasa & Barfoot 2014. After the first solution
// is found (with cost c_best), restrict subsequent samples to
// the prolate hyperspheroid (ellipsoid) with foci at start and
// goal and major-axis length c_best. As c_best decreases via
// rewiring, the ellipsoid shrinks, focusing sampling on the
// region that could improve the solution. Significantly faster
// convergence to the optimum than vanilla RRT* on long-path
// problems.
//
// Sampling within the ellipsoid:
//   1. Sample u uniformly on the unit n-sphere.
//   2. Scale by U^(1/n) where U ~ Uniform(0, 1) → uniform in unit n-ball.
//   3. x = C · L · (point in unit ball) + center
//      where:
//        center = (start + goal) / 2
//        c_min  = ‖goal - start‖
//        L      = diag(c_best/2, sqrt(c_best² - c_min²)/2, ..., sqrt(c_best² - c_min²)/2)
//        C      = rotation aligning e_1 with (goal - start)/c_min
//
// **Limitations** (anytime variant + asymptotic-optimality
// theoretical guarantees land in v0.6 if needed):
// - Falls back to uniform-bounds sampling when no solution found
//   yet, same as vanilla RRT*.
// - C matrix built via simple Gram-Schmidt; degenerate when
//   start ↔ goal axis is perfectly aligned with a standard basis
//   in pathological dimensions ≥ 4 (rare in practice).

// Sample uniformly on the unit n-sphere via Gaussian normalization.
static void _sample_unit_sphere(NRRT *r, int n, double *out) {
    double s = 0;
    for (int i = 0; i < n; i++) {
        // Box-Muller: two uniforms → one standard normal.
        double u1 = _rng_unit(r), u2 = _rng_unit(r);
        if (u1 < 1e-12) u1 = 1e-12;
        out[i] = sqrt(-2.0 * log(u1)) * cos(2.0 * 3.14159265358979 * u2);
        s += out[i] * out[i];
    }
    s = sqrt(s);
    if (s > 1e-12) {
        for (int i = 0; i < n; i++) out[i] /= s;
    }
}

// Build the n×n rotation matrix C (row-major) such that C·e_1 = a1.
// Columns 1..n-1 completed via Gram-Schmidt starting from standard
// basis vectors.
static void _build_rotation_C(const double *a1, int n, double *C_out) {
    for (int i = 0; i < n; i++) C_out[i*n + 0] = a1[i];
    double *col = (double *)malloc(n * sizeof(double));
    for (int j = 1; j < n; j++) {
        // Start with the standard basis vector e_j.
        for (int i = 0; i < n; i++) col[i] = (i == j) ? 1.0 : 0.0;
        // Orthogonalize against all previous columns.
        for (int prev = 0; prev < j; prev++) {
            double dot = 0;
            for (int i = 0; i < n; i++) dot += col[i] * C_out[i*n + prev];
            for (int i = 0; i < n; i++) col[i] -= dot * C_out[i*n + prev];
        }
        double norm = 0;
        for (int i = 0; i < n; i++) norm += col[i] * col[i];
        norm = sqrt(norm);
        if (norm < 1e-9) {
            // Degenerate; pick next basis.
            for (int i = 0; i < n; i++) col[i] = (i == (j+1) % n) ? 1.0 : 0.0;
            for (int prev = 0; prev < j; prev++) {
                double dot = 0;
                for (int i = 0; i < n; i++) dot += col[i] * C_out[i*n + prev];
                for (int i = 0; i < n; i++) col[i] -= dot * C_out[i*n + prev];
            }
            norm = 0;
            for (int i = 0; i < n; i++) norm += col[i] * col[i];
            norm = sqrt(norm);
            if (norm < 1e-9) norm = 1.0;
        }
        for (int i = 0; i < n; i++) C_out[i*n + j] = col[i] / norm;
    }
    free(col);
}

long long nuc_rrt_star_plan_informed(
    long long h, long long start_ptr, long long goal_ptr,
    long long max_iters,
    long long step_bits,
    long long radius_bits,
    long long is_collision_free_fp)
{
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || r->count == 0) return 0;
    double *start = (double *)(void *)(size_t)start_ptr;
    double *goal  = (double *)(void *)(size_t)goal_ptr;
    double step = _i2f(step_bits);
    double radius = _i2f(radius_bits);
    coll_fn_t cf = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    int n = r->n_dim;

    _ensure_cost_capacity(r);
    _rrt_cost[0] = 0;

    // Precompute ellipsoid parameters.
    double c_min = 0;
    for (int i = 0; i < n; i++) {
        double d = goal[i] - start[i];
        c_min += d * d;
    }
    c_min = sqrt(c_min);
    double *a1 = (double *)malloc(n * sizeof(double));
    if (c_min > 1e-9) {
        for (int i = 0; i < n; i++) a1[i] = (goal[i] - start[i]) / c_min;
    } else {
        for (int i = 0; i < n; i++) a1[i] = (i == 0) ? 1.0 : 0.0;
    }
    double *center = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) center[i] = 0.5 * (start[i] + goal[i]);
    double *C = (double *)malloc(n * n * sizeof(double));
    _build_rotation_C(a1, n, C);

    double *sample = (double *)malloc(n * sizeof(double));
    double *new_cfg = (double *)malloc(n * sizeof(double));
    double *unit_ball = (double *)malloc(n * sizeof(double));
    int best_goal = -1;
    double best_goal_cost = 1e30;

    long long it;
    for (it = 0; it < max_iters; it++) {
        // === Sample ===
        if (best_goal >= 0 && best_goal_cost < 1e29) {
            // Informed sample within ellipsoid.
            _sample_unit_sphere(r, n, unit_ball);
            double scale = pow(_rng_unit(r), 1.0 / (double)n);
            for (int i = 0; i < n; i++) unit_ball[i] *= scale;
            // Apply L (diagonal): major axis c_best/2, others sqrt(c²-c_min²)/2.
            double r1 = best_goal_cost * 0.5;
            double r2sq = best_goal_cost*best_goal_cost - c_min*c_min;
            double r2 = (r2sq > 0) ? 0.5 * sqrt(r2sq) : 0;
            double *Lball = sample;  // reuse buffer
            Lball[0] = r1 * unit_ball[0];
            for (int i = 1; i < n; i++) Lball[i] = r2 * unit_ball[i];
            // Apply C: rotate Lball into ellipsoid frame.
            // sample = C · Lball + center.
            double *tmp = (double *)malloc(n * sizeof(double));
            for (int i = 0; i < n; i++) {
                double s = 0;
                for (int j = 0; j < n; j++) s += C[i*n + j] * Lball[j];
                tmp[i] = s + center[i];
            }
            for (int i = 0; i < n; i++) sample[i] = tmp[i];
            free(tmp);
            // Clip to bounds.
            for (int i = 0; i < n; i++) {
                if (sample[i] < r->lower[i]) sample[i] = r->lower[i];
                if (sample[i] > r->upper[i]) sample[i] = r->upper[i];
            }
        } else {
            // Uniform-bounds sample (no solution found yet).
            for (int k = 0; k < n; k++) {
                sample[k] = r->lower[k] + _rng_unit(r) * (r->upper[k] - r->lower[k]);
            }
        }

        // === Steer + RRT* logic (same as vanilla rrt_star_plan) ===
        int near = _nearest(r, sample);
        double *near_cfg = r->configs + near * r->n_dim;
        double dist = 0;
        for (int k = 0; k < n; k++) {
            double d = sample[k] - near_cfg[k];
            dist += d * d;
        }
        dist = sqrt(dist);
        if (dist < 1e-9) continue;
        double scale_step = (dist <= step) ? 1.0 : (step / dist);
        for (int k = 0; k < n; k++) {
            new_cfg[k] = near_cfg[k] + (sample[k] - near_cfg[k]) * scale_step;
        }
        if (cf && cf((long long)(size_t)new_cfg) == 0) continue;

        int best_parent = near;
        double best_parent_cost = _rrt_cost[near] + _node_dist_n(r, near, new_cfg);
        int neighbor_buf[64]; int n_neigh = 0;
        for (int i = 0; i < r->count; i++) {
            double d = _node_dist_n(r, i, new_cfg);
            if (d > radius) continue;
            if (n_neigh < 64) neighbor_buf[n_neigh++] = i;
            double cand = _rrt_cost[i] + d;
            if (cand < best_parent_cost) {
                if (_segment_collision_free_n(r, r->configs + i * r->n_dim, new_cfg, step, cf)) {
                    best_parent_cost = cand;
                    best_parent = i;
                }
            }
        }
        _ensure_capacity(r);
        _ensure_cost_capacity(r);
        memcpy(r->configs + r->count * r->n_dim, new_cfg, r->n_dim * sizeof(double));
        r->parents[r->count] = best_parent;
        _rrt_cost[r->count] = best_parent_cost;
        int new_idx = r->count;
        r->count++;
        for (int q = 0; q < n_neigh; q++) {
            int n_i = neighbor_buf[q];
            if (n_i == best_parent) continue;
            double d = _node_dist_n(r, n_i, new_cfg);
            double cand = _rrt_cost[new_idx] + d;
            if (cand < _rrt_cost[n_i]) {
                if (_segment_collision_free_n(r, new_cfg, r->configs + n_i * r->n_dim, step, cf)) {
                    r->parents[n_i] = new_idx;
                    _rrt_cost[n_i] = cand;
                }
            }
        }
        // Track best goal.
        double goal_d = 0;
        for (int k = 0; k < n; k++) {
            double dd = new_cfg[k] - goal[k];
            goal_d += dd * dd;
        }
        if (goal_d <= step * step) {
            double total = _rrt_cost[new_idx] + sqrt(goal_d);
            if (total < best_goal_cost) {
                best_goal = new_idx;
                best_goal_cost = total;
            }
        }
    }
    free(sample); free(new_cfg); free(unit_ball);
    free(a1); free(center); free(C);
    if (best_goal < 0) return 0;
    int n_nodes = 0;
    for (int i = best_goal; i != -1; i = r->parents[i]) n_nodes++;
    if (r->path_indices) free(r->path_indices);
    r->path_indices = (int *)malloc(n_nodes * sizeof(int));
    r->path_len = n_nodes;
    int p = n_nodes - 1;
    for (int i = best_goal; i != -1; i = r->parents[i]) r->path_indices[p--] = i;
    return 1;
}

// Goal-region planning (v0.2.198). Instead of a single goal
// point, the user supplies a per-dimension [lo, hi] box that
// defines an acceptable goal region. The planner samples
// uniformly inside the region (10% goal-bias) and reports
// success when the new node is inside the region.
//
// Useful when the exact goal pose is approximate or there's
// a tolerance bubble around the desired end-effector position.

long long nuc_rrt_plan_region(
    long long h, long long region_lo_ptr, long long region_hi_ptr,
    long long max_iters,
    long long step_bits,
    long long is_collision_free_fp)
{
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || r->count == 0) return 0;
    double *lo = (double *)(void *)(size_t)region_lo_ptr;
    double *hi = (double *)(void *)(size_t)region_hi_ptr;
    double step = _i2f(step_bits);
    coll_fn_t coll_free = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    double *new_cfg = (double *)malloc(r->n_dim * sizeof(double));
    int success = 0;
    int goal_index = -1;
    for (long long it = 0; it < max_iters && !success; it++) {
        // 10% chance: sample inside the region (goal bias).
        if (_rng_unit(r) < 0.1) {
            for (int k = 0; k < r->n_dim; k++) {
                sample[k] = lo[k] + _rng_unit(r) * (hi[k] - lo[k]);
            }
        } else {
            for (int k = 0; k < r->n_dim; k++) {
                sample[k] = r->lower[k] + _rng_unit(r) * (r->upper[k] - r->lower[k]);
            }
        }
        int near = _nearest(r, sample);
        double *near_cfg = r->configs + near * r->n_dim;
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
        long long is_free = 1;
        if (coll_free) is_free = coll_free((long long)(size_t)new_cfg);
        if (!is_free) continue;
        _ensure_capacity(r);
        memcpy(r->configs + r->count * r->n_dim, new_cfg, r->n_dim * sizeof(double));
        r->parents[r->count] = near;
        int new_idx = r->count;
        r->count++;
        // Inside region?
        int inside = 1;
        for (int k = 0; k < r->n_dim; k++) {
            if (new_cfg[k] < lo[k] || new_cfg[k] > hi[k]) { inside = 0; break; }
        }
        if (inside) { success = 1; goal_index = new_idx; }
    }
    free(sample); free(new_cfg);
    if (!success) return 0;
    int n_nodes = 0;
    for (int i = goal_index; i != -1; i = r->parents[i]) n_nodes++;
    if (r->path_indices) free(r->path_indices);
    r->path_indices = (int *)malloc(n_nodes * sizeof(int));
    r->path_len = n_nodes;
    int p = n_nodes - 1;
    for (int i = goal_index; i != -1; i = r->parents[i]) r->path_indices[p--] = i;
    return 1;
}

// Path shortcutting (v0.2.182). Repeatedly pick two random
// indices i < j on the current path; if the straight-line
// segment from path[i] to path[j] is collision-free at every
// intermediate `step`-spaced sample, replace path[i+1..j-1]
// with that line. Standard post-process for RRT raw output.
//
// Modifies the cached path in place. Returns the new path
// length (number of waypoints). Does nothing if path_len < 3.
long long nuc_rrt_shortcut_path(
    long long h, long long iters,
    long long step_bits, long long is_collision_free_fp)
{
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r || !r->path_indices || r->path_len < 3) return r ? r->path_len : 0;
    coll_fn_t coll_free = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    double step = _i2f(step_bits);
    double *sample = (double *)malloc(r->n_dim * sizeof(double));
    long long sample_h = (long long)(size_t)sample;

    for (long long it = 0; it < iters; it++) {
        if (r->path_len < 3) break;
        // Random i < j on the current path.
        int span = r->path_len;
        int i = (int)(_rng_unit(r) * (span - 1));
        int j = i + 2 + (int)(_rng_unit(r) * (span - i - 2));
        if (j >= span) j = span - 1;
        if (j - i < 2) continue;

        double *cfg_i = r->configs + r->path_indices[i] * r->n_dim;
        double *cfg_j = r->configs + r->path_indices[j] * r->n_dim;

        // Walk the segment from i → j in `step` increments and
        // verify each intermediate is collision-free.
        double dist = 0;
        for (int k = 0; k < r->n_dim; k++) {
            double d = cfg_j[k] - cfg_i[k];
            dist += d * d;
        }
        dist = sqrt(dist);
        int n_steps = (int)(dist / step);
        if (n_steps < 1) n_steps = 1;
        int free_path = 1;
        for (int s = 1; s < n_steps; s++) {
            double t = (double)s / (double)n_steps;
            for (int k = 0; k < r->n_dim; k++) {
                sample[k] = cfg_i[k] + t * (cfg_j[k] - cfg_i[k]);
            }
            if (coll_free && coll_free(sample_h) == 0) { free_path = 0; break; }
        }
        if (!free_path) continue;

        // Collapse path[i+1..j-1] — keep i and j, drop everything
        // between. Shift later indices down.
        int drop = (j - i) - 1;
        if (drop <= 0) continue;
        for (int k = j; k < r->path_len; k++) {
            r->path_indices[k - drop] = r->path_indices[k];
        }
        r->path_len -= drop;
    }

    free(sample);
    return (long long)r->path_len;
}

void nuc_rrt_free(long long h) {
    NRRT *r = (NRRT *)(void *)(size_t)h;
    if (!r) return;
    free(r->configs); free(r->parents);
    free(r->lower); free(r->upper);
    if (r->path_indices) free(r->path_indices);
    free(r);
}
