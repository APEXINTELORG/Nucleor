// embedding_rt.c — Vector Embeddings and Similarity for Nucleor
// Embedding tables, cosine similarity, nearest neighbors, PCA reduction.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/embedding_rt.c -o target/embedding_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _em_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _em_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } EMVec;

// ================================================================
//  Embedding Table
// ================================================================

typedef struct {
    int vocab_size;
    int dim;
    double *data;  // [vocab_size, dim]
} EmbTable;

long long nuc_emb_new(long long vocab_size, long long dim) {
    int vs = (int)vocab_size, d = (int)dim;
    EmbTable *e = (EmbTable *)malloc(sizeof(EmbTable));
    e->vocab_size = vs; e->dim = d;
    e->data = (double *)malloc((size_t)vs * d * sizeof(double));
    // Xavier init
    double scale = sqrt(2.0 / d);
    unsigned int rng = 54321;
    for (int i = 0; i < vs * d; i++) {
        rng = rng * 1103515245 + 12345;
        double u = ((double)((rng >> 16) & 0x7FFF)) / 32767.0;
        e->data[i] = (u * 2.0 - 1.0) * scale;
    }
    return (long long)e;
}

// Lookup: returns Vec<f64> of dim
long long nuc_emb_lookup(long long eh, long long token_id) {
    EmbTable *e = (EmbTable *)(void *)eh;
    int id = (int)token_id;
    if (id < 0 || id >= e->vocab_size) id = 0;
    EMVec *v = (EMVec *)malloc(sizeof(EMVec));
    v->len = e->dim; v->cap = e->dim;
    v->data = (long long *)malloc(e->dim * sizeof(long long));
    for (int i = 0; i < e->dim; i++)
        v->data[i] = _em_f2i(e->data[id * e->dim + i]);
    return (long long)v;
}

// Set embedding vector for a token
void nuc_emb_set(long long eh, long long token_id, long long vec_h) {
    EmbTable *e = (EmbTable *)(void *)eh;
    EMVec *v = (EMVec *)(void *)vec_h;
    int id = (int)token_id;
    if (id < 0 || id >= e->vocab_size) return;
    for (int i = 0; i < e->dim && i < v->len; i++)
        e->data[id * e->dim + i] = _em_i2f(v->data[i]);
}

// ================================================================
//  Similarity Functions
// ================================================================

long long nuc_emb_cosine_sim(long long ah, long long bh) {
    EMVec *a = (EMVec *)(void *)ah, *b = (EMVec *)(void *)bh;
    int n = a->len < b->len ? a->len : b->len;
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < n; i++) {
        double ai = _em_i2f(a->data[i]), bi = _em_i2f(b->data[i]);
        dot += ai * bi;
        na += ai * ai;
        nb += bi * bi;
    }
    double denom = sqrt(na) * sqrt(nb);
    return _em_f2i((denom > 1e-15) ? dot / denom : 0.0);
}

long long nuc_emb_dot(long long ah, long long bh) {
    EMVec *a = (EMVec *)(void *)ah, *b = (EMVec *)(void *)bh;
    int n = a->len < b->len ? a->len : b->len;
    double dot = 0;
    for (int i = 0; i < n; i++)
        dot += _em_i2f(a->data[i]) * _em_i2f(b->data[i]);
    return _em_f2i(dot);
}

// ================================================================
//  Nearest Neighbors (brute force, returns Vec of token indices)
// ================================================================

long long nuc_emb_nearest(long long eh, long long query_h, long long k) {
    EmbTable *e = (EmbTable *)(void *)eh;
    EMVec *query = (EMVec *)(void *)query_h;
    int K = (int)k;
    if (K > e->vocab_size) K = e->vocab_size;

    // Compute cosine similarities
    double *sims = (double *)malloc(e->vocab_size * sizeof(double));
    int *indices = (int *)malloc(e->vocab_size * sizeof(int));
    double qnorm = 0;
    for (int i = 0; i < e->dim; i++) {
        double qi = _em_i2f(query->data[i]);
        qnorm += qi * qi;
    }
    qnorm = sqrt(qnorm);

    for (int v = 0; v < e->vocab_size; v++) {
        double dot = 0, vnorm = 0;
        for (int i = 0; i < e->dim; i++) {
            double vi = e->data[v * e->dim + i];
            dot += _em_i2f(query->data[i]) * vi;
            vnorm += vi * vi;
        }
        vnorm = sqrt(vnorm);
        sims[v] = (qnorm > 1e-15 && vnorm > 1e-15) ? dot / (qnorm * vnorm) : 0.0;
        indices[v] = v;
    }

    // Partial sort for top-K
    for (int i = 0; i < K; i++) {
        int best = i;
        for (int j = i + 1; j < e->vocab_size; j++)
            if (sims[j] > sims[best]) best = j;
        if (best != i) {
            double ts = sims[i]; sims[i] = sims[best]; sims[best] = ts;
            int ti = indices[i]; indices[i] = indices[best]; indices[best] = ti;
        }
    }

    EMVec *result = (EMVec *)malloc(sizeof(EMVec));
    result->len = K; result->cap = K;
    result->data = (long long *)malloc(K * sizeof(long long));
    for (int i = 0; i < K; i++) result->data[i] = indices[i];

    free(sims); free(indices);
    return (long long)result;
}

// ================================================================
//  L2 Normalization (in-place, returns new vec)
// ================================================================

long long nuc_emb_normalize(long long vh) {
    EMVec *v = (EMVec *)(void *)vh;
    int n = v->len;
    double norm = 0;
    for (int i = 0; i < n; i++) {
        double x = _em_i2f(v->data[i]);
        norm += x * x;
    }
    norm = sqrt(norm);
    EMVec *out = (EMVec *)malloc(sizeof(EMVec));
    out->len = n; out->cap = n;
    out->data = (long long *)malloc(n * sizeof(long long));
    if (norm > 1e-15) {
        for (int i = 0; i < n; i++)
            out->data[i] = _em_f2i(_em_i2f(v->data[i]) / norm);
    } else {
        memcpy(out->data, v->data, n * sizeof(long long));
    }
    return (long long)out;
}

void nuc_emb_free(long long eh) {
    EmbTable *e = (EmbTable *)(void *)eh;
    if (e) { free(e->data); free(e); }
}
