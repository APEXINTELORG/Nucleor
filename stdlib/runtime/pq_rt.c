// pq_rt.c — Product Quantization for Vector Search (IVF-PQ) for Nucleor
// Codebook training, encoding, asymmetric distance computation.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/pq_rt.c -o target/pq_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _pq_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _pq_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } PQVec;

// ================================================================
//  Product Quantizer
// ================================================================

typedef struct {
    int dim;           // total vector dimension
    int n_subspaces;   // M (number of subquantizers)
    int sub_dim;       // dim / M
    int n_centroids;   // K (typically 256 for uint8 codes)
    double *codebooks; // [n_subspaces][n_centroids][sub_dim]
} ProductQuantizer;

// ================================================================
//  K-means for one subspace
// ================================================================

static void pq_kmeans(double *data, int n, int dim, int k, int max_iter, double *centroids) {
    // Random init (first k points)
    for (int i = 0; i < k && i < n; i++)
        memcpy(centroids + i * dim, data + i * dim, dim * sizeof(double));

    int *assign = (int *)malloc(n * sizeof(int));
    for (int iter = 0; iter < max_iter; iter++) {
        // Assign
        for (int i = 0; i < n; i++) {
            double best_d = 1e30; int best_c = 0;
            for (int c = 0; c < k; c++) {
                double d = 0;
                for (int j = 0; j < dim; j++) {
                    double diff = data[i * dim + j] - centroids[c * dim + j];
                    d += diff * diff;
                }
                if (d < best_d) { best_d = d; best_c = c; }
            }
            assign[i] = best_c;
        }
        // Update centroids
        double *sums = (double *)calloc(k * dim, sizeof(double));
        int *counts = (int *)calloc(k, sizeof(int));
        for (int i = 0; i < n; i++) {
            counts[assign[i]]++;
            for (int j = 0; j < dim; j++)
                sums[assign[i] * dim + j] += data[i * dim + j];
        }
        for (int c = 0; c < k; c++) {
            if (counts[c] > 0)
                for (int j = 0; j < dim; j++)
                    centroids[c * dim + j] = sums[c * dim + j] / counts[c];
        }
        free(sums); free(counts);
    }
    free(assign);
}

// ================================================================
//  Train PQ codebooks from data
// ================================================================

long long nuc_pq_train(long long data_h, long long n_vectors, long long dim,
                        long long n_subspaces, long long n_centroids) {
    PQVec *data = (PQVec *)(void *)data_h;
    int nv = (int)n_vectors, D = (int)dim, M = (int)n_subspaces, K = (int)n_centroids;
    int sd = D / M;

    ProductQuantizer *pq = (ProductQuantizer *)calloc(1, sizeof(ProductQuantizer));
    pq->dim = D; pq->n_subspaces = M; pq->sub_dim = sd; pq->n_centroids = K;
    pq->codebooks = (double *)malloc(M * K * sd * sizeof(double));

    // Train each subspace independently
    double *sub_data = (double *)malloc(nv * sd * sizeof(double));
    for (int m = 0; m < M; m++) {
        // Extract subvectors
        for (int i = 0; i < nv; i++)
            for (int j = 0; j < sd; j++)
                sub_data[i * sd + j] = _pq_i2f(data->data[i * D + m * sd + j]);
        // K-means
        pq_kmeans(sub_data, nv, sd, K, 20, pq->codebooks + m * K * sd);
    }
    free(sub_data);
    return (long long)pq;
}

// ================================================================
//  Encode vectors to PQ codes (uint8 per subspace)
// ================================================================

long long nuc_pq_encode(long long pq_h, long long vec_h) {
    ProductQuantizer *pq = (ProductQuantizer *)(void *)pq_h;
    PQVec *vec = (PQVec *)(void *)vec_h;
    int D = pq->dim, M = pq->n_subspaces, sd = pq->sub_dim, K = pq->n_centroids;

    PQVec *codes = (PQVec *)malloc(sizeof(PQVec));
    codes->len = M; codes->cap = M;
    codes->data = (long long *)malloc(M * sizeof(long long));

    for (int m = 0; m < M; m++) {
        double best_d = 1e30; int best_c = 0;
        for (int c = 0; c < K; c++) {
            double d = 0;
            for (int j = 0; j < sd; j++) {
                double diff = _pq_i2f(vec->data[m * sd + j]) - pq->codebooks[m * K * sd + c * sd + j];
                d += diff * diff;
            }
            if (d < best_d) { best_d = d; best_c = c; }
        }
        codes->data[m] = best_c;
    }
    return (long long)codes;
}

// ================================================================
//  Asymmetric Distance Computation (ADC)
//  Precompute distance table for query, then scan codes
// ================================================================

long long nuc_pq_distance_table(long long pq_h, long long query_h) {
    ProductQuantizer *pq = (ProductQuantizer *)(void *)pq_h;
    PQVec *query = (PQVec *)(void *)query_h;
    int M = pq->n_subspaces, sd = pq->sub_dim, K = pq->n_centroids;

    // Table: [M][K] distances
    PQVec *table = (PQVec *)malloc(sizeof(PQVec));
    table->len = M * K; table->cap = table->len;
    table->data = (long long *)malloc(table->len * sizeof(long long));

    for (int m = 0; m < M; m++) {
        for (int c = 0; c < K; c++) {
            double d = 0;
            for (int j = 0; j < sd; j++) {
                double diff = _pq_i2f(query->data[m * sd + j]) - pq->codebooks[m * K * sd + c * sd + j];
                d += diff * diff;
            }
            table->data[m * K + c] = _pq_f2i(d);
        }
    }
    return (long long)table;
}

// Compute distance from precomputed table + codes
long long nuc_pq_adc(long long table_h, long long codes_h, long long n_subspaces) {
    PQVec *table = (PQVec *)(void *)table_h;
    PQVec *codes = (PQVec *)(void *)codes_h;
    int M = (int)n_subspaces;
    int K = table->len / M;
    double dist = 0;
    for (int m = 0; m < M; m++) {
        int c = (int)codes->data[m];
        dist += _pq_i2f(table->data[m * K + c]);
    }
    return _pq_f2i(dist);
}

// ================================================================
//  Batch search: find k nearest from encoded database
// ================================================================

long long nuc_pq_search(long long pq_h, long long query_h, long long db_codes_h,
                          long long n_vectors, long long k) {
    ProductQuantizer *pq = (ProductQuantizer *)(void *)pq_h;
    PQVec *db = (PQVec *)(void *)db_codes_h; // [n_vectors * M] flat codes
    int nv = (int)n_vectors, K_out = (int)k, M = pq->n_subspaces;
    int K = pq->n_centroids;

    // Build distance table
    long long table_h = nuc_pq_distance_table(pq_h, query_h);
    PQVec *table = (PQVec *)(void *)table_h;

    // Scan all vectors using ADC
    typedef struct { int idx; double dist; } PQCand;
    PQCand *best = (PQCand *)malloc(K_out * sizeof(PQCand));
    int n_best = 0;

    for (int i = 0; i < nv; i++) {
        double dist = 0;
        for (int m = 0; m < M; m++) {
            int c = (int)db->data[i * M + m];
            dist += _pq_i2f(table->data[m * K + c]);
        }
        if (n_best < K_out) {
            best[n_best++] = (PQCand){i, dist};
            // Bubble sort
            for (int j = n_best - 1; j > 0 && best[j].dist < best[j-1].dist; j--) {
                PQCand t = best[j]; best[j] = best[j-1]; best[j-1] = t;
            }
        } else if (dist < best[K_out - 1].dist) {
            best[K_out - 1] = (PQCand){i, dist};
            for (int j = K_out - 1; j > 0 && best[j].dist < best[j-1].dist; j--) {
                PQCand t = best[j]; best[j] = best[j-1]; best[j-1] = t;
            }
        }
    }

    PQVec *result = (PQVec *)malloc(sizeof(PQVec));
    result->len = n_best; result->cap = n_best;
    result->data = (long long *)malloc(n_best * sizeof(long long));
    for (int i = 0; i < n_best; i++) result->data[i] = best[i].idx;

    free(best);
    return (long long)result;
}

void nuc_pq_free(long long pq_h) {
    ProductQuantizer *pq = (ProductQuantizer *)(void *)pq_h;
    if (pq) { free(pq->codebooks); free(pq); }
}
