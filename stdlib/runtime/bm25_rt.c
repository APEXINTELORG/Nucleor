// bm25_rt.c — BM25 Text Search (Inverted Index) for Nucleor
// Build index, score queries, ranked retrieval for RAG.
//
// Compile: clang -c stdlib/runtime/bm25_rt.c -o target/bm25_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// ================================================================
//  Hash function for terms
// ================================================================

static unsigned int bm25_hash(const char *s) {
    unsigned int h = 2166136261u;
    for (; *s; s++) { h ^= (unsigned char)*s; h *= 16777619u; }
    return h;
}

// ================================================================
//  Posting List Entry
// ================================================================

typedef struct { int doc_id; int term_freq; } Posting;

typedef struct {
    unsigned int term_hash;
    Posting *postings;
    int n_postings;
    int cap_postings;
    int doc_freq; // number of documents containing this term
} PostingList;

// ================================================================
//  BM25 Index
// ================================================================

#define BM25_MAX_TERMS 65536

typedef struct {
    PostingList *terms;
    int n_terms;
    int *doc_lengths;   // number of tokens per document
    int n_docs;
    int cap_docs;
    double avg_dl;       // average document length
    double k1, b;        // BM25 parameters
} BM25Index;

static int bm25_find_term(BM25Index *idx, unsigned int hash) {
    for (int i = 0; i < idx->n_terms; i++)
        if (idx->terms[i].term_hash == hash) return i;
    return -1;
}

static int bm25_add_term(BM25Index *idx, unsigned int hash) {
    if (idx->n_terms >= BM25_MAX_TERMS) return -1;
    int i = idx->n_terms++;
    idx->terms[i].term_hash = hash;
    idx->terms[i].cap_postings = 16;
    idx->terms[i].postings = (Posting *)malloc(16 * sizeof(Posting));
    idx->terms[i].n_postings = 0;
    idx->terms[i].doc_freq = 0;
    return i;
}

// ================================================================
//  Create Index
// ================================================================

long long nuc_bm25_new(void) {
    BM25Index *idx = (BM25Index *)calloc(1, sizeof(BM25Index));
    idx->terms = (PostingList *)calloc(BM25_MAX_TERMS, sizeof(PostingList));
    idx->cap_docs = 1024;
    idx->doc_lengths = (int *)calloc(1024, sizeof(int));
    idx->k1 = 1.2; idx->b = 0.75;
    return (long long)idx;
}

// ================================================================
//  Add Document (tokenize by whitespace, lowercase)
// ================================================================

void nuc_bm25_add_doc(long long idx_h, long long doc_id, const char *text) {
    BM25Index *idx = (BM25Index *)(void *)idx_h;
    if (!text) return;
    int did = (int)doc_id;

    // Ensure doc_lengths capacity
    while (did >= idx->cap_docs) {
        idx->cap_docs *= 2;
        idx->doc_lengths = (int *)realloc(idx->doc_lengths, idx->cap_docs * sizeof(int));
    }
    if (did >= idx->n_docs) idx->n_docs = did + 1;

    // Tokenize and count
    char *buf = (char *)malloc(strlen(text) + 1);
    strcpy(buf, text);
    int doc_len = 0;

    // Simple whitespace tokenizer with lowercase
    char *tok = buf;
    while (*tok) {
        while (*tok && (*tok == ' ' || *tok == '\t' || *tok == '\n')) tok++;
        if (!*tok) break;
        char *start = tok;
        while (*tok && *tok != ' ' && *tok != '\t' && *tok != '\n') tok++;
        char saved = *tok; *tok = 0;

        // Lowercase
        for (char *p = start; *p; p++) if (*p >= 'A' && *p <= 'Z') *p += 32;

        unsigned int hash = bm25_hash(start);
        int ti = bm25_find_term(idx, hash);
        if (ti < 0) ti = bm25_add_term(idx, hash);
        if (ti < 0) { *tok = saved; if (saved) tok++; continue; }

        PostingList *pl = &idx->terms[ti];
        // Check if doc already in this term's postings
        int found = 0;
        for (int i = 0; i < pl->n_postings; i++) {
            if (pl->postings[i].doc_id == did) {
                pl->postings[i].term_freq++;
                found = 1;
                break;
            }
        }
        if (!found) {
            if (pl->n_postings >= pl->cap_postings) {
                pl->cap_postings *= 2;
                pl->postings = (Posting *)realloc(pl->postings, pl->cap_postings * sizeof(Posting));
            }
            pl->postings[pl->n_postings].doc_id = did;
            pl->postings[pl->n_postings].term_freq = 1;
            pl->n_postings++;
            pl->doc_freq++;
        }

        doc_len++;
        *tok = saved;
        if (saved) tok++;
    }

    idx->doc_lengths[did] = doc_len;

    // Update average document length
    double total = 0;
    for (int i = 0; i < idx->n_docs; i++) total += idx->doc_lengths[i];
    idx->avg_dl = total / idx->n_docs;

    free(buf);
}

// ================================================================
//  BM25 Score Query
//  Returns Vec of [doc_id, score] pairs sorted by score (descending)
// ================================================================

long long nuc_bm25_search(long long idx_h, const char *query, long long top_k) {
    BM25Index *idx = (BM25Index *)(void *)idx_h;
    if (!query) return 0;
    int K = (int)top_k;

    // Tokenize query
    char *buf = (char *)malloc(strlen(query) + 1);
    strcpy(buf, query);
    unsigned int *query_terms = (unsigned int *)malloc(256 * sizeof(unsigned int));
    int n_qt = 0;

    char *tok = buf;
    while (*tok && n_qt < 256) {
        while (*tok && (*tok == ' ' || *tok == '\t')) tok++;
        if (!*tok) break;
        char *start = tok;
        while (*tok && *tok != ' ' && *tok != '\t') tok++;
        char saved = *tok; *tok = 0;
        for (char *p = start; *p; p++) if (*p >= 'A' && *p <= 'Z') *p += 32;
        query_terms[n_qt++] = bm25_hash(start);
        *tok = saved;
        if (saved) tok++;
    }
    free(buf);

    // Score all documents
    double *scores = (double *)calloc(idx->n_docs, sizeof(double));
    int N = idx->n_docs;

    for (int qi = 0; qi < n_qt; qi++) {
        int ti = bm25_find_term(idx, query_terms[qi]);
        if (ti < 0) continue;
        PostingList *pl = &idx->terms[ti];
        double idf = log((N - pl->doc_freq + 0.5) / (pl->doc_freq + 0.5) + 1.0);

        for (int i = 0; i < pl->n_postings; i++) {
            int did = pl->postings[i].doc_id;
            double tf = pl->postings[i].term_freq;
            double dl = idx->doc_lengths[did];
            double bm25 = idf * (tf * (idx->k1 + 1)) /
                          (tf + idx->k1 * (1 - idx->b + idx->b * dl / idx->avg_dl));
            scores[did] += bm25;
        }
    }
    free(query_terms);

    // Top-K by score
    typedef struct { long long *data; int len; int cap; } NVec;
    if (K > N) K = N;
    NVec *result = (NVec *)malloc(sizeof(NVec));
    result->len = K * 2; result->cap = result->len;
    result->data = (long long *)malloc(result->len * sizeof(long long));

    int *top = (int *)malloc(K * sizeof(int));
    double *top_scores = (double *)malloc(K * sizeof(double));
    for (int i = 0; i < K; i++) { top[i] = -1; top_scores[i] = -1; }

    for (int d = 0; d < N; d++) {
        if (scores[d] <= 0) continue;
        // Insert into sorted top-K
        for (int i = 0; i < K; i++) {
            if (scores[d] > top_scores[i]) {
                for (int j = K - 1; j > i; j--) { top[j] = top[j-1]; top_scores[j] = top_scores[j-1]; }
                top[i] = d; top_scores[i] = scores[d];
                break;
            }
        }
    }

    int count = 0;
    for (int i = 0; i < K; i++) {
        if (top[i] >= 0) {
            long long s; double sv = top_scores[i]; memcpy(&s, &sv, 8);
            result->data[count * 2] = top[i];
            result->data[count * 2 + 1] = s;
            count++;
        }
    }
    result->len = count * 2;

    free(scores); free(top); free(top_scores);
    return (long long)result;
}

long long nuc_bm25_n_docs(long long idx_h) { return ((BM25Index *)(void *)idx_h)->n_docs; }
long long nuc_bm25_n_terms(long long idx_h) { return ((BM25Index *)(void *)idx_h)->n_terms; }

void nuc_bm25_free(long long idx_h) {
    BM25Index *idx = (BM25Index *)(void *)idx_h;
    if (!idx) return;
    for (int i = 0; i < idx->n_terms; i++) free(idx->terms[i].postings);
    free(idx->terms); free(idx->doc_lengths); free(idx);
}
