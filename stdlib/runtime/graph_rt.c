// graph_rt.c — Graph Algorithms for Nucleor
// Adjacency list, BFS, DFS, Dijkstra, Bellman-Ford, topological sort,
// connected components, Kruskal MST, PageRank.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/graph_rt.c -o target/graph_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _gr_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _gr_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } GRVec;

static GRVec *grvec_new(int n) {
    GRVec *v = (GRVec *)malloc(sizeof(GRVec));
    v->len = n; v->cap = n > 0 ? n : 16;
    v->data = (long long *)calloc(v->cap, sizeof(long long));
    return v;
}

static void grvec_push(GRVec *v, long long val) {
    if (v->len >= v->cap) { v->cap = v->cap * 2 + 8; v->data = (long long *)realloc(v->data, v->cap * sizeof(long long)); }
    v->data[v->len++] = val;
}

// ================================================================
//  Graph (adjacency list, directed, weighted)
// ================================================================

typedef struct { int to; double weight; } Edge;

typedef struct {
    int n_nodes;
    Edge **adj;
    int *adj_len;
    int *adj_cap;
    int n_edges;
} Graph;

long long nuc_graph_new(long long n_nodes) {
    int n = (int)n_nodes;
    Graph *g = (Graph *)malloc(sizeof(Graph));
    g->n_nodes = n; g->n_edges = 0;
    g->adj = (Edge **)calloc(n, sizeof(Edge *));
    g->adj_len = (int *)calloc(n, sizeof(int));
    g->adj_cap = (int *)calloc(n, sizeof(int));
    for (int i = 0; i < n; i++) {
        g->adj_cap[i] = 8;
        g->adj[i] = (Edge *)malloc(8 * sizeof(Edge));
    }
    return (long long)g;
}

void nuc_graph_add_edge(long long gh, long long u, long long v, long long w_bits) {
    Graph *g = (Graph *)(void *)gh;
    int ui = (int)u;
    if (g->adj_len[ui] >= g->adj_cap[ui]) {
        g->adj_cap[ui] *= 2;
        g->adj[ui] = (Edge *)realloc(g->adj[ui], g->adj_cap[ui] * sizeof(Edge));
    }
    g->adj[ui][g->adj_len[ui]].to = (int)v;
    g->adj[ui][g->adj_len[ui]].weight = _gr_i2f(w_bits);
    g->adj_len[ui]++;
    g->n_edges++;
}

void nuc_graph_add_edge_undirected(long long gh, long long u, long long v, long long w_bits) {
    nuc_graph_add_edge(gh, u, v, w_bits);
    nuc_graph_add_edge(gh, v, u, w_bits);
}

// ================================================================
//  BFS
// ================================================================

long long nuc_graph_bfs(long long gh, long long start) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes, s = (int)start;
    int *visited = (int *)calloc(n, sizeof(int));
    int *queue = (int *)malloc(n * sizeof(int));
    int qh = 0, qt = 0;
    GRVec *order = grvec_new(0);

    visited[s] = 1;
    queue[qt++] = s;
    while (qh < qt) {
        int u = queue[qh++];
        grvec_push(order, u);
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            if (!visited[v]) { visited[v] = 1; queue[qt++] = v; }
        }
    }
    free(visited); free(queue);
    return (long long)order;
}

// ================================================================
//  DFS
// ================================================================

static void dfs_visit(Graph *g, int u, int *visited, GRVec *order) {
    visited[u] = 1;
    grvec_push(order, u);
    for (int i = 0; i < g->adj_len[u]; i++) {
        int v = g->adj[u][i].to;
        if (!visited[v]) dfs_visit(g, v, visited, order);
    }
}

long long nuc_graph_dfs(long long gh, long long start) {
    Graph *g = (Graph *)(void *)gh;
    int *visited = (int *)calloc(g->n_nodes, sizeof(int));
    GRVec *order = grvec_new(0);
    dfs_visit(g, (int)start, visited, order);
    free(visited);
    return (long long)order;
}

// ================================================================
//  Dijkstra (returns distance Vec<f64>)
// ================================================================

long long nuc_graph_dijkstra(long long gh, long long src) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes, s = (int)src;
    double *dist = (double *)malloc(n * sizeof(double));
    int *done = (int *)calloc(n, sizeof(int));
    for (int i = 0; i < n; i++) dist[i] = 1e30;
    dist[s] = 0;

    for (int iter = 0; iter < n; iter++) {
        int u = -1;
        double best = 1e30;
        for (int i = 0; i < n; i++) {
            if (!done[i] && dist[i] < best) { best = dist[i]; u = i; }
        }
        if (u < 0) break;
        done[u] = 1;
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            double w = g->adj[u][i].weight;
            if (dist[u] + w < dist[v]) dist[v] = dist[u] + w;
        }
    }

    GRVec *result = grvec_new(n);
    for (int i = 0; i < n; i++) result->data[i] = _gr_f2i(dist[i]);
    free(dist); free(done);
    return (long long)result;
}

// ================================================================
//  Bellman-Ford (handles negative weights)
// ================================================================

long long nuc_graph_bellman_ford(long long gh, long long src) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes, s = (int)src;
    double *dist = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) dist[i] = 1e30;
    dist[s] = 0;

    for (int iter = 0; iter < n - 1; iter++) {
        for (int u = 0; u < n; u++) {
            if (dist[u] >= 1e30) continue;
            for (int i = 0; i < g->adj_len[u]; i++) {
                int v = g->adj[u][i].to;
                double w = g->adj[u][i].weight;
                if (dist[u] + w < dist[v]) dist[v] = dist[u] + w;
            }
        }
    }

    GRVec *result = grvec_new(n);
    for (int i = 0; i < n; i++) result->data[i] = _gr_f2i(dist[i]);
    free(dist);
    return (long long)result;
}

// ================================================================
//  v0.7.80 — RFC-0061 Tier 1: negative-cycle detection.
//
//  After n-1 Bellman-Ford relaxations, any edge that can still
//  relax indicates a negative-weight cycle reachable from the
//  source. `nuc_graph_has_negative_cycle` returns 1/0; the path
//  variant walks the cycle from a witness node back to itself
//  via predecessor pointers and returns the node sequence.
// ================================================================

long long nuc_graph_has_negative_cycle(long long gh, long long src) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes, s = (int)src;
    if (n <= 0 || s < 0 || s >= n) return 0;
    double *dist = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) dist[i] = 1e30;
    dist[s] = 0;

    for (int iter = 0; iter < n - 1; iter++) {
        for (int u = 0; u < n; u++) {
            if (dist[u] >= 1e30) continue;
            for (int i = 0; i < g->adj_len[u]; i++) {
                int v = g->adj[u][i].to;
                double w = g->adj[u][i].weight;
                if (dist[u] + w < dist[v]) dist[v] = dist[u] + w;
            }
        }
    }
    /* nth pass: any improvement => negative cycle reachable. */
    int has = 0;
    for (int u = 0; u < n && !has; u++) {
        if (dist[u] >= 1e30) continue;
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            double w = g->adj[u][i].weight;
            if (dist[u] + w < dist[v]) { has = 1; break; }
        }
    }
    free(dist);
    return (long long)has;
}

// ================================================================
//  v0.7.81 — RFC-0061 Tier 1: adjacency-matrix view.
//
//  to_adjacency_matrix: returns a flat Vec<i64> of size n*n with
//    each cell = f64-bits weight (or _gr_i2f(1e30) / "no edge").
//  from_adjacency_matrix: builds a Graph from a Vec<i64> matrix.
//    Cells whose decoded weight equals or exceeds 1e30 are treated
//    as "no edge".
//  adjacency_density: returns f64-bits(edges / (n * (n - 1)))
//    in [0,1] for n >= 2 (directed, no self-loops in denominator).
//    Returns f64-bits(0) for n < 2.
// ================================================================
long long nuc_graph_to_adjacency_matrix(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;
    GRVec *m = grvec_new(n * n);
    long long no_edge_bits = _gr_f2i(1e30);
    for (int i = 0; i < n * n; i++) m->data[i] = no_edge_bits;
    for (int u = 0; u < n; u++) {
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            m->data[u * n + v] = _gr_f2i(g->adj[u][i].weight);
        }
    }
    return (long long)m;
}

long long nuc_graph_from_adjacency_matrix(long long matrix_p, long long n_nodes) {
    GRVec *m = (GRVec *)(void *)matrix_p;
    int n = (int)n_nodes;
    Graph *g = (Graph *)(void *)nuc_graph_new(n_nodes);
    if (m == NULL || m->len < n * n) return (long long)g;
    for (int u = 0; u < n; u++) {
        for (int v = 0; v < n; v++) {
            double w = _gr_i2f(m->data[u * n + v]);
            if (w < 1e30) {
                if (g->adj_len[u] >= g->adj_cap[u]) {
                    g->adj_cap[u] *= 2;
                    g->adj[u] = (Edge *)realloc(g->adj[u], g->adj_cap[u] * sizeof(Edge));
                }
                g->adj[u][g->adj_len[u]].to = v;
                g->adj[u][g->adj_len[u]].weight = w;
                g->adj_len[u]++;
                g->n_edges++;
            }
        }
    }
    return (long long)g;
}

long long nuc_graph_adjacency_density(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;
    if (n < 2) return _gr_f2i(0.0);
    long long total_slots = (long long)n * (long long)(n - 1);
    long long total_edges = 0;
    for (int u = 0; u < n; u++) total_edges += g->adj_len[u];
    return _gr_f2i((double)total_edges / (double)total_slots);
}

long long nuc_graph_negative_cycle_path(long long gh, long long src) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes, s = (int)src;
    GRVec *empty = grvec_new(0);
    if (n <= 0 || s < 0 || s >= n) return (long long)empty;

    double *dist = (double *)malloc(n * sizeof(double));
    int *pred = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) { dist[i] = 1e30; pred[i] = -1; }
    dist[s] = 0;

    for (int iter = 0; iter < n - 1; iter++) {
        for (int u = 0; u < n; u++) {
            if (dist[u] >= 1e30) continue;
            for (int i = 0; i < g->adj_len[u]; i++) {
                int v = g->adj[u][i].to;
                double w = g->adj[u][i].weight;
                if (dist[u] + w < dist[v]) { dist[v] = dist[u] + w; pred[v] = u; }
            }
        }
    }

    /* Find a witness node that still relaxes. */
    int witness = -1;
    for (int u = 0; u < n && witness == -1; u++) {
        if (dist[u] >= 1e30) continue;
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            double w = g->adj[u][i].weight;
            if (dist[u] + w < dist[v]) { witness = v; break; }
        }
    }
    if (witness == -1) {
        free(dist); free(pred);
        return (long long)empty;
    }

    /* Walk back n times to ensure we're inside the cycle. */
    int cur = witness;
    for (int i = 0; i < n; i++) {
        if (pred[cur] == -1) break;
        cur = pred[cur];
    }
    /* Trace the cycle by walking back from cur until we return to cur. */
    GRVec *cycle = grvec_new(0);
    grvec_push(cycle, cur);
    int x = pred[cur];
    int safety = 0;
    while (x != cur && x != -1 && safety < n + 1) {
        grvec_push(cycle, x);
        x = pred[x];
        safety++;
    }
    grvec_push(cycle, cur);
    free(dist); free(pred);
    /* cycle is currently witness-to-witness in reverse pred order;
     * reverse in-place so adopters see start-to-end. */
    for (int i = 0, j = cycle->len - 1; i < j; i++, j--) {
        long long t = cycle->data[i];
        cycle->data[i] = cycle->data[j];
        cycle->data[j] = t;
    }
    return (long long)cycle;
}

// ================================================================
//  Topological Sort (Kahn's algorithm)
// ================================================================

long long nuc_graph_topo_sort(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;
    int *indegree = (int *)calloc(n, sizeof(int));
    for (int u = 0; u < n; u++)
        for (int i = 0; i < g->adj_len[u]; i++)
            indegree[g->adj[u][i].to]++;

    int *queue = (int *)malloc(n * sizeof(int));
    int qh = 0, qt = 0;
    for (int i = 0; i < n; i++) if (indegree[i] == 0) queue[qt++] = i;

    GRVec *order = grvec_new(0);
    while (qh < qt) {
        int u = queue[qh++];
        grvec_push(order, u);
        for (int i = 0; i < g->adj_len[u]; i++) {
            int v = g->adj[u][i].to;
            if (--indegree[v] == 0) queue[qt++] = v;
        }
    }
    free(indegree); free(queue);
    return (long long)order;
}

// ================================================================
//  Connected Components (undirected, union-find)
// ================================================================

long long nuc_graph_connected_components(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;
    int *comp = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) comp[i] = -1;
    int c = 0;

    int *stack = (int *)malloc(n * sizeof(int));
    for (int s = 0; s < n; s++) {
        if (comp[s] >= 0) continue;
        int sp = 0;
        stack[sp++] = s;
        while (sp > 0) {
            int u = stack[--sp];
            if (comp[u] >= 0) continue;
            comp[u] = c;
            for (int i = 0; i < g->adj_len[u]; i++) {
                int v = g->adj[u][i].to;
                if (comp[v] < 0) stack[sp++] = v;
            }
        }
        c++;
    }
    free(stack);

    GRVec *result = grvec_new(n);
    for (int i = 0; i < n; i++) result->data[i] = comp[i];
    free(comp);
    return (long long)result;
}

// ================================================================
//  Kruskal MST (returns total weight)
// ================================================================

static int uf_find(int *parent, int x) {
    while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
    return x;
}

long long nuc_graph_mst_kruskal(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;

    // Collect all edges
    typedef struct { int u, v; double w; } KEdge;
    int ne = 0;
    KEdge *edges = (KEdge *)malloc(g->n_edges * sizeof(KEdge));
    for (int u = 0; u < n; u++)
        for (int i = 0; i < g->adj_len[u]; i++) {
            edges[ne].u = u;
            edges[ne].v = g->adj[u][i].to;
            edges[ne].w = g->adj[u][i].weight;
            ne++;
        }

    // Sort by weight
    for (int i = 0; i < ne - 1; i++)
        for (int j = i + 1; j < ne; j++)
            if (edges[j].w < edges[i].w) { KEdge t = edges[i]; edges[i] = edges[j]; edges[j] = t; }

    int *parent = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) parent[i] = i;

    double total = 0;
    for (int i = 0; i < ne; i++) {
        int pu = uf_find(parent, edges[i].u);
        int pv = uf_find(parent, edges[i].v);
        if (pu != pv) { parent[pu] = pv; total += edges[i].w; }
    }

    free(edges); free(parent);
    return _gr_f2i(total);
}

// ================================================================
//  PageRank
// ================================================================

long long nuc_graph_pagerank(long long gh, long long damping_bits, long long iters) {
    Graph *g = (Graph *)(void *)gh;
    int n = g->n_nodes;
    double d = _gr_i2f(damping_bits);
    int niter = (int)iters;

    double *rank = (double *)malloc(n * sizeof(double));
    double *new_rank = (double *)malloc(n * sizeof(double));
    double inv_n = 1.0 / n;
    for (int i = 0; i < n; i++) rank[i] = inv_n;

    for (int iter = 0; iter < niter; iter++) {
        for (int i = 0; i < n; i++) new_rank[i] = (1 - d) / n;
        for (int u = 0; u < n; u++) {
            int out = g->adj_len[u];
            if (out == 0) {
                for (int i = 0; i < n; i++) new_rank[i] += d * rank[u] / n;
            } else {
                double share = d * rank[u] / out;
                for (int i = 0; i < out; i++) new_rank[g->adj[u][i].to] += share;
            }
        }
        double *tmp = rank; rank = new_rank; new_rank = tmp;
    }

    GRVec *result = grvec_new(n);
    for (int i = 0; i < n; i++) result->data[i] = _gr_f2i(rank[i]);
    free(rank); free(new_rank);
    return (long long)result;
}

void nuc_graph_free(long long gh) {
    Graph *g = (Graph *)(void *)gh;
    if (!g) return;
    for (int i = 0; i < g->n_nodes; i++) free(g->adj[i]);
    free(g->adj); free(g->adj_len); free(g->adj_cap); free(g);
}
