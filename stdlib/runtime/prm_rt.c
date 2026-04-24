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
