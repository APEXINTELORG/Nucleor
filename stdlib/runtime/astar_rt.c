// astar_rt.c — A* shortest-path search on a generic weighted graph.
//
// Caller supplies the graph as:
//   - n_nodes: total node count
//   - neighbor function pointer: given a node id, fill an output
//     array with (neighbor_id, edge_cost) pairs
//   - heuristic function pointer: given (from, to), return an
//     admissible lower-bound on the remaining cost
//
// Returns 1 on success, 0 if no path exists. Path is read back via
// nuc_astar_path_len + nuc_astar_path_at.
//
// Foundation for the v0.5 PRM Dijkstra/A* query, RRT* rewiring,
// and any discrete graph search a user needs.
//
// Compile: clang -c stdlib/runtime/astar_rt.c -o target/astar.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Caller fills the (neighbor_id, cost) pairs into a scratch array
// owned by us. Returns the number of neighbors written. Up to
// `cap` entries; never write past.
//   neighbors_fp signature: long long (long long node, long long out_ids_ptr,
//                                       long long out_costs_ptr, long long cap)
typedef long long (*neighbor_fn_t)(long long node, long long out_ids, long long out_costs, long long cap);
typedef long long (*heuristic_fn_t)(long long from, long long to);

typedef struct {
    int n;
    double *g_score;       // best known cost from start to i
    double *f_score;       // g_score[i] + heuristic(i, goal)
    int *came_from;        // predecessor; -1 if none
    char *closed;          // 1 if expanded
    // Min-heap of (f_score, node) pairs.
    double *heap_f;
    int *heap_n;
    int heap_size;
    int heap_cap;
    int *path_indices;
    int path_len;
} NAStar;

static void _heap_push(NAStar *a, double f, int node) {
    if (a->heap_size >= a->heap_cap) {
        a->heap_cap = a->heap_cap == 0 ? 32 : a->heap_cap * 2;
        a->heap_f = (double *)realloc(a->heap_f, a->heap_cap * sizeof(double));
        a->heap_n = (int *)realloc(a->heap_n, a->heap_cap * sizeof(int));
    }
    int i = a->heap_size++;
    a->heap_f[i] = f;
    a->heap_n[i] = node;
    while (i > 0) {
        int p = (i - 1) / 2;
        if (a->heap_f[p] <= a->heap_f[i]) break;
        double tf = a->heap_f[p]; a->heap_f[p] = a->heap_f[i]; a->heap_f[i] = tf;
        int tn = a->heap_n[p]; a->heap_n[p] = a->heap_n[i]; a->heap_n[i] = tn;
        i = p;
    }
}

static int _heap_pop(NAStar *a, double *out_f) {
    if (a->heap_size == 0) return -1;
    int node = a->heap_n[0];
    *out_f = a->heap_f[0];
    a->heap_size--;
    if (a->heap_size > 0) {
        a->heap_f[0] = a->heap_f[a->heap_size];
        a->heap_n[0] = a->heap_n[a->heap_size];
        int i = 0;
        while (1) {
            int l = 2*i + 1, r = 2*i + 2, smallest = i;
            if (l < a->heap_size && a->heap_f[l] < a->heap_f[smallest]) smallest = l;
            if (r < a->heap_size && a->heap_f[r] < a->heap_f[smallest]) smallest = r;
            if (smallest == i) break;
            double tf = a->heap_f[i]; a->heap_f[i] = a->heap_f[smallest]; a->heap_f[smallest] = tf;
            int tn = a->heap_n[i]; a->heap_n[i] = a->heap_n[smallest]; a->heap_n[smallest] = tn;
            i = smallest;
        }
    }
    return node;
}

long long nuc_astar_new(long long n_nodes) {
    NAStar *a = (NAStar *)calloc(1, sizeof(NAStar));
    a->n = (int)n_nodes;
    a->g_score = (double *)malloc(a->n * sizeof(double));
    a->f_score = (double *)malloc(a->n * sizeof(double));
    a->came_from = (int *)malloc(a->n * sizeof(int));
    a->closed = (char *)malloc(a->n);
    return (long long)(size_t)a;
}

// Search from start to goal. Caller supplies neighbor and heuristic
// fn pointers. neighbor_cap is the max neighbors per node (caller
// must guarantee they don't write more).
long long nuc_astar_search(long long h, long long start, long long goal,
                           long long neighbor_fp, long long heuristic_fp,
                           long long neighbor_cap)
{
    NAStar *a = (NAStar *)(void *)(size_t)h;
    if (!a) return 0;
    int s = (int)start, g = (int)goal;
    if (s < 0 || s >= a->n || g < 0 || g >= a->n) return 0;
    neighbor_fn_t nfn = (neighbor_fn_t)(void *)(size_t)neighbor_fp;
    heuristic_fn_t hfn = (heuristic_fn_t)(void *)(size_t)heuristic_fp;
    int cap = (int)neighbor_cap;
    if (cap < 1) cap = 1;

    for (int i = 0; i < a->n; i++) {
        a->g_score[i] = INFINITY;
        a->f_score[i] = INFINITY;
        a->came_from[i] = -1;
        a->closed[i] = 0;
    }
    a->heap_size = 0;
    a->g_score[s] = 0;
    double h_start = hfn ? _i2f(hfn(s, g)) : 0;
    a->f_score[s] = h_start;
    _heap_push(a, h_start, s);

    long long *out_ids = (long long *)malloc(cap * sizeof(long long));
    long long *out_costs = (long long *)malloc(cap * sizeof(long long));

    int found = 0;
    while (a->heap_size > 0) {
        double f;
        int cur = _heap_pop(a, &f);
        if (cur == g) { found = 1; break; }
        if (a->closed[cur]) continue;
        a->closed[cur] = 1;
        long long n_neigh = nfn ? nfn(cur, (long long)(size_t)out_ids,
                                       (long long)(size_t)out_costs, cap) : 0;
        for (long long q = 0; q < n_neigh; q++) {
            int nb = (int)out_ids[q];
            if (nb < 0 || nb >= a->n || a->closed[nb]) continue;
            double cost = _i2f(out_costs[q]);
            double tentative = a->g_score[cur] + cost;
            if (tentative < a->g_score[nb]) {
                a->came_from[nb] = cur;
                a->g_score[nb] = tentative;
                double hh = hfn ? _i2f(hfn(nb, g)) : 0;
                a->f_score[nb] = tentative + hh;
                _heap_push(a, a->f_score[nb], nb);
            }
        }
    }
    free(out_ids); free(out_costs);
    if (!found) return 0;
    // Reconstruct path.
    int len = 0;
    for (int cur = g; cur != -1; cur = a->came_from[cur]) len++;
    if (a->path_indices) free(a->path_indices);
    a->path_indices = (int *)malloc(len * sizeof(int));
    a->path_len = len;
    int p = len - 1;
    for (int cur = g; cur != -1; cur = a->came_from[cur]) a->path_indices[p--] = cur;
    return 1;
}

long long nuc_astar_path_len(long long h) {
    NAStar *a = (NAStar *)(void *)(size_t)h;
    return (a && a->path_indices) ? (long long)a->path_len : 0;
}

long long nuc_astar_path_at(long long h, long long i) {
    NAStar *a = (NAStar *)(void *)(size_t)h;
    if (!a || !a->path_indices) return -1;
    if (i < 0 || i >= a->path_len) return -1;
    return (long long)a->path_indices[i];
}

long long nuc_astar_g_score(long long h, long long node) {
    NAStar *a = (NAStar *)(void *)(size_t)h;
    if (!a || node < 0 || node >= a->n) return _f2i(INFINITY);
    return _f2i(a->g_score[node]);
}

void nuc_astar_free(long long h) {
    NAStar *a = (NAStar *)(void *)(size_t)h;
    if (!a) return;
    if (a->g_score) free(a->g_score);
    if (a->f_score) free(a->f_score);
    if (a->came_from) free(a->came_from);
    if (a->closed) free(a->closed);
    if (a->heap_f) free(a->heap_f);
    if (a->heap_n) free(a->heap_n);
    if (a->path_indices) free(a->path_indices);
    free(a);
}
