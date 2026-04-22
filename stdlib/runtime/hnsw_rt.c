// hnsw_rt.c — Hierarchical Navigable Small World Graph for Nucleor
// HNSW vector index for approximate nearest neighbor search.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/hnsw_rt.c -o target/hnsw_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _hw_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _hw_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } HWVec;

// ================================================================
//  HNSW Data Structures
// ================================================================

#define HNSW_MAX_LEVEL 16
#define HNSW_MAX_NEIGHBORS 32

typedef struct {
    int id;
    int level;
    double *vector;
    int neighbors[HNSW_MAX_LEVEL][HNSW_MAX_NEIGHBORS];
    int n_neighbors[HNSW_MAX_LEVEL];
} HNSWNode;

typedef struct {
    HNSWNode **nodes;
    int n_nodes;
    int capacity;
    int dim;
    int M;           // max connections per layer
    int ef_construct; // construction beam width
    int max_level;
    int entry_point;
    double level_mult; // 1/ln(M)
    unsigned int rng;
} HNSW;

static double hnsw_l2dist(double *a, double *b, int dim) {
    double sum = 0;
    for (int i = 0; i < dim; i++) { double d = a[i] - b[i]; sum += d * d; }
    return sqrt(sum);
}

static int hnsw_random_level(HNSW *idx) {
    idx->rng = idx->rng * 1103515245 + 12345;
    double r = ((double)((idx->rng >> 16) & 0x7FFF)) / 32767.0;
    int level = (int)(-log(r + 1e-15) * idx->level_mult);
    if (level > HNSW_MAX_LEVEL - 1) level = HNSW_MAX_LEVEL - 1;
    return level;
}

// Min-heap for beam search
typedef struct { int id; double dist; } HNSWCand;

static void hnsw_heap_push(HNSWCand *heap, int *size, int id, double dist, int max_size) {
    if (*size < max_size) {
        heap[*size] = (HNSWCand){id, dist};
        (*size)++;
        // Sift up (max-heap by distance for eviction)
        int i = *size - 1;
        while (i > 0) {
            int p = (i - 1) / 2;
            if (heap[i].dist > heap[p].dist) {
                HNSWCand t = heap[i]; heap[i] = heap[p]; heap[p] = t; i = p;
            } else break;
        }
    } else if (dist < heap[0].dist) {
        heap[0] = (HNSWCand){id, dist};
        // Sift down
        int i = 0;
        while (1) {
            int l = 2*i+1, r = 2*i+2, largest = i;
            if (l < *size && heap[l].dist > heap[largest].dist) largest = l;
            if (r < *size && heap[r].dist > heap[largest].dist) largest = r;
            if (largest == i) break;
            HNSWCand t = heap[i]; heap[i] = heap[largest]; heap[largest] = t; i = largest;
        }
    }
}

// ================================================================
//  Create Index
// ================================================================

long long nuc_hnsw_new(long long dim, long long M, long long ef_construct) {
    HNSW *idx = (HNSW *)calloc(1, sizeof(HNSW));
    idx->dim = (int)dim;
    idx->M = (int)M; if (idx->M < 4) idx->M = 16;
    idx->ef_construct = (int)ef_construct; if (idx->ef_construct < 16) idx->ef_construct = 64;
    idx->capacity = 1024;
    idx->nodes = (HNSWNode **)calloc(idx->capacity, sizeof(HNSWNode *));
    idx->entry_point = -1;
    idx->level_mult = 1.0 / log(idx->M);
    idx->rng = 42;
    return (long long)idx;
}

// ================================================================
//  Insert
// ================================================================

void nuc_hnsw_insert(long long idx_h, long long vec_h, long long id) {
    HNSW *idx = (HNSW *)(void *)idx_h;
    HWVec *vec = (HWVec *)(void *)vec_h;

    if (idx->n_nodes >= idx->capacity) {
        idx->capacity *= 2;
        idx->nodes = (HNSWNode **)realloc(idx->nodes, idx->capacity * sizeof(HNSWNode *));
    }

    HNSWNode *node = (HNSWNode *)calloc(1, sizeof(HNSWNode));
    node->id = (int)id;
    node->level = hnsw_random_level(idx);
    node->vector = (double *)malloc(idx->dim * sizeof(double));
    for (int i = 0; i < idx->dim && i < vec->len; i++)
        node->vector[i] = _hw_i2f(vec->data[i]);

    int node_idx = idx->n_nodes;
    idx->nodes[node_idx] = node;
    idx->n_nodes++;

    if (idx->entry_point < 0) {
        idx->entry_point = node_idx;
        idx->max_level = node->level;
        return;
    }

    // Greedy search from top to node level
    int cur = idx->entry_point;
    for (int level = idx->max_level; level > node->level; level--) {
        // Greedy descent: find nearest at this level
        int changed = 1;
        while (changed) {
            changed = 0;
            HNSWNode *cn = idx->nodes[cur];
            double cur_dist = hnsw_l2dist(node->vector, cn->vector, idx->dim);
            for (int i = 0; i < cn->n_neighbors[level]; i++) {
                int nb = cn->neighbors[level][i];
                double d = hnsw_l2dist(node->vector, idx->nodes[nb]->vector, idx->dim);
                if (d < cur_dist) { cur = nb; cur_dist = d; changed = 1; }
            }
        }
    }

    // Insert at each level from node->level down to 0
    for (int level = (node->level < idx->max_level ? node->level : idx->max_level); level >= 0; level--) {
        // Connect to nearest M neighbors at this level
        // Simple: connect to cur and its neighbors
        if (node->n_neighbors[level] < HNSW_MAX_NEIGHBORS && node->n_neighbors[level] < idx->M) {
            node->neighbors[level][node->n_neighbors[level]++] = cur;
            HNSWNode *cn = idx->nodes[cur];
            if (cn->n_neighbors[level] < HNSW_MAX_NEIGHBORS && cn->n_neighbors[level] < idx->M)
                cn->neighbors[level][cn->n_neighbors[level]++] = node_idx;
        }

        // Also connect to cur's neighbors if closer
        HNSWNode *cn = idx->nodes[cur];
        for (int i = 0; i < cn->n_neighbors[level] && node->n_neighbors[level] < idx->M; i++) {
            int nb = cn->neighbors[level][i];
            if (nb == node_idx) continue;
            if (node->n_neighbors[level] < HNSW_MAX_NEIGHBORS) {
                node->neighbors[level][node->n_neighbors[level]++] = nb;
                HNSWNode *nbn = idx->nodes[nb];
                if (nbn->n_neighbors[level] < HNSW_MAX_NEIGHBORS && nbn->n_neighbors[level] < idx->M)
                    nbn->neighbors[level][nbn->n_neighbors[level]++] = node_idx;
            }
        }
    }

    if (node->level > idx->max_level) {
        idx->max_level = node->level;
        idx->entry_point = node_idx;
    }
}

// ================================================================
//  Search (k-NN)
// ================================================================

long long nuc_hnsw_search(long long idx_h, long long query_h, long long ef, long long k) {
    HNSW *idx = (HNSW *)(void *)idx_h;
    HWVec *query = (HWVec *)(void *)query_h;
    int K = (int)k, EF = (int)ef;
    if (EF < K) EF = K;

    double *q = (double *)malloc(idx->dim * sizeof(double));
    for (int i = 0; i < idx->dim && i < query->len; i++) q[i] = _hw_i2f(query->data[i]);

    if (idx->n_nodes == 0 || idx->entry_point < 0) { free(q); return 0; }

    // Greedy descent from top level
    int cur = idx->entry_point;
    for (int level = idx->max_level; level > 0; level--) {
        int changed = 1;
        while (changed) {
            changed = 0;
            HNSWNode *cn = idx->nodes[cur];
            double cd = hnsw_l2dist(q, cn->vector, idx->dim);
            for (int i = 0; i < cn->n_neighbors[level]; i++) {
                int nb = cn->neighbors[level][i];
                double d = hnsw_l2dist(q, idx->nodes[nb]->vector, idx->dim);
                if (d < cd) { cur = nb; cd = d; changed = 1; }
            }
        }
    }

    // Beam search at level 0
    HNSWCand *result_heap = (HNSWCand *)malloc(EF * sizeof(HNSWCand));
    int result_size = 0;
    int *visited = (int *)calloc(idx->n_nodes, sizeof(int));
    int *queue = (int *)malloc(idx->n_nodes * sizeof(int));
    int qh = 0, qt = 0;

    visited[cur] = 1;
    queue[qt++] = cur;
    double d = hnsw_l2dist(q, idx->nodes[cur]->vector, idx->dim);
    hnsw_heap_push(result_heap, &result_size, idx->nodes[cur]->id, d, EF);

    while (qh < qt) {
        int node = queue[qh++];
        HNSWNode *cn = idx->nodes[node];
        for (int i = 0; i < cn->n_neighbors[0]; i++) {
            int nb = cn->neighbors[0][i];
            if (nb < 0 || nb >= idx->n_nodes || visited[nb]) continue;
            visited[nb] = 1;
            double dist = hnsw_l2dist(q, idx->nodes[nb]->vector, idx->dim);
            if (result_size < EF || dist < result_heap[0].dist) {
                hnsw_heap_push(result_heap, &result_size, idx->nodes[nb]->id, dist, EF);
                queue[qt++] = nb;
            }
        }
    }

    // Extract top-K
    // Sort by distance
    for (int i = 0; i < result_size - 1; i++)
        for (int j = i + 1; j < result_size; j++)
            if (result_heap[j].dist < result_heap[i].dist) {
                HNSWCand t = result_heap[i]; result_heap[i] = result_heap[j]; result_heap[j] = t;
            }

    int out_k = result_size < K ? result_size : K;
    HWVec *result = (HWVec *)malloc(sizeof(HWVec));
    result->len = out_k; result->cap = out_k;
    result->data = (long long *)malloc(out_k * sizeof(long long));
    for (int i = 0; i < out_k; i++) result->data[i] = result_heap[i].id;

    free(q); free(result_heap); free(visited); free(queue);
    return (long long)result;
}

long long nuc_hnsw_size(long long idx_h) { return ((HNSW *)(void *)idx_h)->n_nodes; }

void nuc_hnsw_free(long long idx_h) {
    HNSW *idx = (HNSW *)(void *)idx_h;
    if (!idx) return;
    for (int i = 0; i < idx->n_nodes; i++) {
        if (idx->nodes[i]) { free(idx->nodes[i]->vector); free(idx->nodes[i]); }
    }
    free(idx->nodes); free(idx);
}
