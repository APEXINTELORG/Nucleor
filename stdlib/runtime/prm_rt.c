// prm_rt.c — Probabilistic Roadmap motion planner (PRM).
//
// Build a graph in joint space by sampling random configurations
// (nodes) and connecting nearby pairs with collision-free edges
// (k-nearest neighbors). Then a query (start → goal) is a graph
// search: connect start and goal to their k nearest neighbors,
// then run Dijkstra over the roadmap.
//
// Multi-query advantage: roadmap is built once, every subsequent
// (start, goal) query reuses it. Suited to environments where the
// obstacle field is static but query points change frequently.
//
// Complement to RRT (single-query, builds a fresh tree per
// problem). Use PRM when the same robot is doing many planning
// queries in the same workspace; use RRT when the world changes
// between queries.
//
// Compile: clang -c stdlib/runtime/prm_rt.c -o target/prm.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct { int to; double cost; } PRMEdge;

typedef struct {
    int n_dim;
    int n_nodes;
    int cap_nodes;
    double *nodes;          // n_nodes × n_dim
    PRMEdge *edges;         // flat list, indexed by edge_offset[]
    int *edge_offset;       // n_nodes+1 entries: edges[edge_offset[i]..edge_offset[i+1])
    int n_edges;
    int cap_edges;
    double *lower;          // n_dim
    double *upper;
    unsigned int rng_state;
    // Path output buffer.
    int *path_indices;
    int path_len;
} NPRM;

typedef long long (*coll_fn_t)(long long);

static double _rng_unit(NPRM *r) {
    r->rng_state ^= r->rng_state << 13;
    r->rng_state ^= r->rng_state >> 17;
    r->rng_state ^= r->rng_state << 5;
    return (double)r->rng_state / 4294967296.0;
}

static double _node_dist2(NPRM *p, int a, int b) {
    double *pa = p->nodes + a * p->n_dim;
    double *pb = p->nodes + b * p->n_dim;
    double s = 0;
    for (int k = 0; k < p->n_dim; k++) {
        double d = pa[k] - pb[k];
        s += d * d;
    }
    return s;
}

static int _segment_collision_free(NPRM *p, int a, int b, double step,
                                   coll_fn_t cf)
{
    if (!cf) return 1;
    double *pa = p->nodes + a * p->n_dim;
    double *pb = p->nodes + b * p->n_dim;
    double *sample = (double *)malloc(p->n_dim * sizeof(double));
    long long sh = (long long)(size_t)sample;
    double dist = sqrt(_node_dist2(p, a, b));
    int n_steps = (int)(dist / step);
    if (n_steps < 1) n_steps = 1;
    int ok = 1;
    for (int s = 1; s < n_steps; s++) {
        double t = (double)s / (double)n_steps;
        for (int k = 0; k < p->n_dim; k++) {
            sample[k] = pa[k] + t * (pb[k] - pa[k]);
        }
        if (cf(sh) == 0) { ok = 0; break; }
    }
    free(sample);
    return ok;
}

long long nuc_prm_new(long long n_dim, long long seed) {
    NPRM *p = (NPRM *)calloc(1, sizeof(NPRM));
    p->n_dim = (int)n_dim;
    p->cap_nodes = 64;
    p->nodes = (double *)malloc(p->cap_nodes * p->n_dim * sizeof(double));
    p->lower = (double *)calloc(p->n_dim, sizeof(double));
    p->upper = (double *)calloc(p->n_dim, sizeof(double));
    for (int k = 0; k < p->n_dim; k++) { p->lower[k] = -3.14159265358979; p->upper[k] = 3.14159265358979; }
    p->rng_state = (unsigned int)seed;
    if (p->rng_state == 0) p->rng_state = 0x9E3779B9;
    return (long long)(size_t)p;
}

void nuc_prm_set_bounds(long long h, long long dim, long long lo_b, long long hi_b) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p || dim < 0 || dim >= p->n_dim) return;
    p->lower[dim] = _i2f(lo_b);
    p->upper[dim] = _i2f(hi_b);
}

// Build the roadmap: sample n_samples random configs (rejecting
// any that collide), then connect each new node to its k nearest
// previously-added neighbors with collision-free segments.
long long nuc_prm_build(long long h, long long n_samples, long long k_neighbors,
                       long long step_b, long long is_collision_free_fp)
{
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p) return -1;
    coll_fn_t cf = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    double step = _i2f(step_b);
    int k = (int)k_neighbors;

    // Collect samples.
    double *cfg = (double *)malloc(p->n_dim * sizeof(double));
    long long ch = (long long)(size_t)cfg;
    int target_count = p->n_nodes + (int)n_samples;
    while (p->n_nodes < target_count) {
        for (int d = 0; d < p->n_dim; d++) {
            cfg[d] = p->lower[d] + _rng_unit(p) * (p->upper[d] - p->lower[d]);
        }
        if (cf && cf(ch) == 0) continue;
        if (p->n_nodes >= p->cap_nodes) {
            p->cap_nodes *= 2;
            p->nodes = (double *)realloc(p->nodes, p->cap_nodes * p->n_dim * sizeof(double));
        }
        memcpy(p->nodes + p->n_nodes * p->n_dim, cfg, p->n_dim * sizeof(double));
        p->n_nodes++;
    }
    free(cfg);

    // Build edges. Use simple O(N²) k-NN; fine for N ≤ a few thousand.
    int N = p->n_nodes;
    if (p->edge_offset) free(p->edge_offset);
    if (p->edges) free(p->edges);
    p->edge_offset = (int *)calloc(N + 1, sizeof(int));
    p->n_edges = 0;
    p->cap_edges = N * k * 2; // both directions
    if (p->cap_edges < 16) p->cap_edges = 16;
    p->edges = (PRMEdge *)malloc(p->cap_edges * sizeof(PRMEdge));

    // Two-pass: count edges per node, allocate, then fill.
    int *count = (int *)calloc(N, sizeof(int));
    int *neighbor = (int *)malloc(k * sizeof(int));
    double *neighbor_d2 = (double *)malloc(k * sizeof(double));

    // Pass 1: enumerate (i, j) i<j edges that are collision-free.
    typedef struct { int a; int b; double cost; } Cand;
    Cand *cands = (Cand *)malloc(N * k * sizeof(Cand));
    int n_cands = 0;
    for (int i = 0; i < N; i++) {
        // Pick k nearest j > -1 (any other node).
        int filled = 0;
        for (int j = 0; j < N; j++) {
            if (i == j) continue;
            double d2 = _node_dist2(p, i, j);
            if (filled < k) {
                neighbor[filled] = j;
                neighbor_d2[filled] = d2;
                filled++;
            } else {
                int worst = 0;
                for (int q = 1; q < k; q++) if (neighbor_d2[q] > neighbor_d2[worst]) worst = q;
                if (d2 < neighbor_d2[worst]) {
                    neighbor[worst] = j;
                    neighbor_d2[worst] = d2;
                }
            }
        }
        for (int q = 0; q < filled; q++) {
            int j = neighbor[q];
            if (j <= i) continue; // dedupe; j > i only
            if (!_segment_collision_free(p, i, j, step, cf)) continue;
            cands[n_cands].a = i;
            cands[n_cands].b = j;
            cands[n_cands].cost = sqrt(neighbor_d2[q]);
            n_cands++;
            count[i]++;
            count[j]++;
        }
    }
    // Build offsets + edges.
    p->edge_offset[0] = 0;
    for (int i = 0; i < N; i++) p->edge_offset[i + 1] = p->edge_offset[i] + count[i];
    int total = p->edge_offset[N];
    if (total > p->cap_edges) {
        p->cap_edges = total;
        p->edges = (PRMEdge *)realloc(p->edges, p->cap_edges * sizeof(PRMEdge));
    }
    int *cur = (int *)calloc(N, sizeof(int));
    for (int e = 0; e < n_cands; e++) {
        int i = cands[e].a, j = cands[e].b;
        double c = cands[e].cost;
        p->edges[p->edge_offset[i] + cur[i]++] = (PRMEdge){j, c};
        p->edges[p->edge_offset[j] + cur[j]++] = (PRMEdge){i, c};
    }
    p->n_edges = total;

    free(neighbor); free(neighbor_d2); free(cands); free(count); free(cur);
    return 0;
}

// Distance from an external configuration to roadmap node `j`.
static double _ext_dist2(NPRM *p, double *cfg, int j) {
    double *pj = p->nodes + j * p->n_dim;
    double s = 0;
    for (int k = 0; k < p->n_dim; k++) {
        double d = cfg[k] - pj[k];
        s += d * d;
    }
    return s;
}

// Collision-check the segment from external config `cfg` to roadmap
// node `j` by sampling at `step` granularity. Same scheme as the
// inter-node version above.
static int _ext_segment_free(NPRM *p, double *cfg, int j, double step,
                             coll_fn_t cf)
{
    if (!cf) return 1;
    double *pj = p->nodes + j * p->n_dim;
    double *sample = (double *)malloc(p->n_dim * sizeof(double));
    long long sh = (long long)(size_t)sample;
    double dist = sqrt(_ext_dist2(p, cfg, j));
    int n_steps = (int)(dist / step);
    if (n_steps < 1) n_steps = 1;
    int ok = 1;
    for (int s = 1; s < n_steps; s++) {
        double t = (double)s / (double)n_steps;
        for (int k = 0; k < p->n_dim; k++) {
            sample[k] = cfg[k] + t * (pj[k] - cfg[k]);
        }
        if (cf(sh) == 0) { ok = 0; break; }
    }
    free(sample);
    return ok;
}

// === Dijkstra query (v0.2.200) ==========================================
//
// Connects `start` and `goal` configurations to their k nearest
// roadmap neighbors via collision-free segments, then runs Dijkstra
// from start to goal across the (roadmap + start + goal) graph.
//
// Returns the number of nodes on the resulting path (≥ 2 on success;
// 0 if no path was found). The path itself is stored in
// `p->path_indices` (start..goal) — read back via nuc_prm_path_at.
//
// The roadmap remains unmodified — multiple queries can run against
// the same build without rebuilding.
//
// Implementation notes:
//   - Virtual nodes: start = N, goal = N+1. Edges from these to
//     real roadmap nodes are computed on demand (no graph mutation).
//   - O(V²) Dijkstra (no priority queue) — fine for N ≤ a few k.
//   - Returns 0 if start or goal can't reach any roadmap node.
long long nuc_prm_query(long long h,
                       long long start_ptr, long long goal_ptr,
                       long long k_neighbors,
                       long long step_b,
                       long long is_collision_free_fp)
{
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p || p->n_nodes == 0) return 0;
    coll_fn_t cf = (coll_fn_t)(void *)(size_t)is_collision_free_fp;
    double step = _i2f(step_b);
    int k = (int)k_neighbors;
    if (k < 1) k = 1;

    double *start = (double *)(void *)(size_t)start_ptr;
    double *goal  = (double *)(void *)(size_t)goal_ptr;
    int N = p->n_nodes;
    int V = N + 2;             // start = N, goal = N+1
    int START = N, GOAL = N + 1;

    // Find k nearest roadmap nodes to start and goal, keep
    // collision-free ones as virtual edges.
    typedef struct { int j; double cost; } VEdge;
    VEdge *start_edges = (VEdge *)malloc(k * sizeof(VEdge));
    VEdge *goal_edges  = (VEdge *)malloc(k * sizeof(VEdge));
    int n_start_e = 0, n_goal_e = 0;

    int *cand = (int *)malloc(k * sizeof(int));
    double *cand_d2 = (double *)malloc(k * sizeof(double));

    // Helper inlined twice: pick k nearest to `cfg`, then collision-test.
    for (int pass = 0; pass < 2; pass++) {
        double *cfg = (pass == 0) ? start : goal;
        int filled = 0;
        for (int j = 0; j < N; j++) {
            double d2 = _ext_dist2(p, cfg, j);
            if (filled < k) {
                cand[filled] = j;
                cand_d2[filled] = d2;
                filled++;
            } else {
                int worst = 0;
                for (int q = 1; q < k; q++) if (cand_d2[q] > cand_d2[worst]) worst = q;
                if (d2 < cand_d2[worst]) { cand[worst] = j; cand_d2[worst] = d2; }
            }
        }
        for (int q = 0; q < filled; q++) {
            int j = cand[q];
            if (!_ext_segment_free(p, cfg, j, step, cf)) continue;
            double cost = sqrt(cand_d2[q]);
            if (pass == 0) start_edges[n_start_e++] = (VEdge){j, cost};
            else            goal_edges [n_goal_e++ ] = (VEdge){j, cost};
        }
    }
    free(cand); free(cand_d2);

    if (n_start_e == 0 || n_goal_e == 0) {
        free(start_edges); free(goal_edges);
        if (p->path_indices) { free(p->path_indices); p->path_indices = NULL; }
        p->path_len = 0;
        return 0;
    }

    // Standard Dijkstra (O(V²), no heap).
    double *dist = (double *)malloc(V * sizeof(double));
    int    *prev = (int    *)malloc(V * sizeof(int));
    int    *done = (int    *)calloc(V, sizeof(int));
    for (int i = 0; i < V; i++) { dist[i] = 1e300; prev[i] = -1; }
    dist[START] = 0;

    for (int it = 0; it < V; it++) {
        // Pick min-dist unvisited.
        int u = -1;
        double best = 1e300;
        for (int i = 0; i < V; i++) {
            if (!done[i] && dist[i] < best) { best = dist[i]; u = i; }
        }
        if (u < 0 || best >= 1e299) break;
        done[u] = 1;
        if (u == GOAL) break;

        // Relax outgoing edges.
        if (u == START) {
            for (int q = 0; q < n_start_e; q++) {
                int v = start_edges[q].j;
                double nd = dist[u] + start_edges[q].cost;
                if (nd < dist[v]) { dist[v] = nd; prev[v] = u; }
            }
        } else if (u == GOAL) {
            // No outgoing edges from goal in this directed view.
        } else {
            // Real roadmap node: enumerate its CSR edges, plus check
            // if it's on goal_edges (incoming-from-real-to-virtual).
            int start_off = p->edge_offset[u];
            int end_off   = p->edge_offset[u + 1];
            for (int e = start_off; e < end_off; e++) {
                int v = p->edges[e].to;
                double nd = dist[u] + p->edges[e].cost;
                if (nd < dist[v]) { dist[v] = nd; prev[v] = u; }
            }
            for (int q = 0; q < n_goal_e; q++) {
                if (goal_edges[q].j != u) continue;
                double nd = dist[u] + goal_edges[q].cost;
                if (nd < dist[GOAL]) { dist[GOAL] = nd; prev[GOAL] = u; }
            }
        }
    }

    long long path_len = 0;
    if (dist[GOAL] < 1e299) {
        // Reconstruct path GOAL ← … ← START.
        int len = 0;
        for (int v = GOAL; v != -1; v = prev[v]) len++;
        if (p->path_indices) free(p->path_indices);
        p->path_indices = (int *)malloc(len * sizeof(int));
        int idx = len - 1;
        for (int v = GOAL; v != -1; v = prev[v]) p->path_indices[idx--] = v;
        p->path_len = len;
        path_len = (long long)len;
    } else {
        if (p->path_indices) { free(p->path_indices); p->path_indices = NULL; }
        p->path_len = 0;
    }

    free(dist); free(prev); free(done);
    free(start_edges); free(goal_edges);
    return path_len;
}

// Read coordinate `dim` of path entry `idx`, returned as i64-bit-cast f64.
// Path includes both virtual endpoints (start at idx=0, goal at idx=path_len-1).
// For virtual endpoints, returns the start_ptr / goal_ptr coordinates the user
// passed in — but those pointers are external; we need a stash. To keep the
// API minimal, virtual endpoints return a sentinel (0.0) — callers know their
// own start/goal coords, so this is just the *path through the roadmap*.
// Real-node entries (path[1..len-2]) are read from p->nodes.
long long nuc_prm_path_len(long long h) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    return p ? (long long)p->path_len : 0;
}

long long nuc_prm_path_node(long long h, long long idx) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p || idx < 0 || idx >= (long long)p->path_len) return -1;
    int node = p->path_indices[idx];
    // Real roadmap nodes are 0..n_nodes-1; virtual START = n_nodes, GOAL = n_nodes+1.
    return (long long)node;
}

long long nuc_prm_path_at(long long h, long long idx, long long dim) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p || idx < 0 || idx >= (long long)p->path_len) return _f2i(0.0);
    if (dim < 0 || dim >= (long long)p->n_dim) return _f2i(0.0);
    int node = p->path_indices[idx];
    if (node < 0 || node >= p->n_nodes) return _f2i(0.0); // virtual endpoint
    return _f2i(p->nodes[node * p->n_dim + (int)dim]);
}

long long nuc_prm_node_count(long long h) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    return p ? (long long)p->n_nodes : 0;
}

long long nuc_prm_edge_count(long long h) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    return p ? (long long)p->n_edges : 0;
}

void nuc_prm_free(long long h) {
    NPRM *p = (NPRM *)(void *)(size_t)h;
    if (!p) return;
    if (p->nodes) free(p->nodes);
    if (p->edges) free(p->edges);
    if (p->edge_offset) free(p->edge_offset);
    if (p->lower) free(p->lower);
    if (p->upper) free(p->upper);
    if (p->path_indices) free(p->path_indices);
    free(p);
}
