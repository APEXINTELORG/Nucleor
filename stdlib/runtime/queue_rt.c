// queue_rt.c — Priority Queue / Heap for Nucleor
// Binary min-heap and max-heap, push, pop, peek, decrease-key.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/queue_rt.c -o target/queue_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static double _pq_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _pq_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  Priority Queue (binary heap)
// ================================================================

typedef struct {
    double *keys;
    long long *values;
    int size;
    int capacity;
    int is_min; // 1 = min-heap, 0 = max-heap
} PQueue;

static int pq_compare(PQueue *pq, int a, int b) {
    if (pq->is_min) return pq->keys[a] < pq->keys[b];
    return pq->keys[a] > pq->keys[b];
}

static void pq_swap(PQueue *pq, int a, int b) {
    double tk = pq->keys[a]; pq->keys[a] = pq->keys[b]; pq->keys[b] = tk;
    long long tv = pq->values[a]; pq->values[a] = pq->values[b]; pq->values[b] = tv;
}

static void pq_sift_up(PQueue *pq, int i) {
    while (i > 0) {
        int parent = (i - 1) / 2;
        if (pq_compare(pq, i, parent)) { pq_swap(pq, i, parent); i = parent; }
        else break;
    }
}

static void pq_sift_down(PQueue *pq, int i) {
    while (1) {
        int best = i;
        int left = 2 * i + 1, right = 2 * i + 2;
        if (left < pq->size && pq_compare(pq, left, best)) best = left;
        if (right < pq->size && pq_compare(pq, right, best)) best = right;
        if (best == i) break;
        pq_swap(pq, i, best);
        i = best;
    }
}

// type: 0 = min-heap, 1 = max-heap
long long nuc_pq_new(long long type) {
    PQueue *pq = (PQueue *)malloc(sizeof(PQueue));
    pq->capacity = 256;
    pq->size = 0;
    pq->is_min = (type == 0) ? 1 : 0;
    pq->keys = (double *)malloc(pq->capacity * sizeof(double));
    pq->values = (long long *)malloc(pq->capacity * sizeof(long long));
    return (long long)pq;
}

void nuc_pq_push(long long h, long long key_bits, long long value) {
    PQueue *pq = (PQueue *)(void *)h;
    if (pq->size >= pq->capacity) {
        pq->capacity *= 2;
        pq->keys = (double *)realloc(pq->keys, pq->capacity * sizeof(double));
        pq->values = (long long *)realloc(pq->values, pq->capacity * sizeof(long long));
    }
    pq->keys[pq->size] = _pq_i2f(key_bits);
    pq->values[pq->size] = value;
    pq_sift_up(pq, pq->size);
    pq->size++;
}

// Pop: returns value, removes top element
long long nuc_pq_pop(long long h) {
    PQueue *pq = (PQueue *)(void *)h;
    if (pq->size == 0) return -1;
    long long val = pq->values[0];
    pq->size--;
    if (pq->size > 0) {
        pq->keys[0] = pq->keys[pq->size];
        pq->values[0] = pq->values[pq->size];
        pq_sift_down(pq, 0);
    }
    return val;
}

// Pop key (f64 bitcast)
long long nuc_pq_pop_key(long long h) {
    PQueue *pq = (PQueue *)(void *)h;
    if (pq->size == 0) return _pq_f2i(0);
    double key = pq->keys[0];
    nuc_pq_pop(h); // actually pops
    // Note: this double-pops; use peek_key + pop instead
    return _pq_f2i(key);
}

long long nuc_pq_peek(long long h) {
    PQueue *pq = (PQueue *)(void *)h;
    return (pq->size > 0) ? pq->values[0] : -1;
}

long long nuc_pq_peek_key(long long h) {
    PQueue *pq = (PQueue *)(void *)h;
    return (pq->size > 0) ? _pq_f2i(pq->keys[0]) : _pq_f2i(0);
}

long long nuc_pq_size(long long h) {
    return (long long)((PQueue *)(void *)h)->size;
}

long long nuc_pq_empty(long long h) {
    return ((PQueue *)(void *)h)->size == 0 ? 1 : 0;
}

// Decrease key for a value (linear scan — use for small heaps)
void nuc_pq_decrease_key(long long h, long long value, long long new_key_bits) {
    PQueue *pq = (PQueue *)(void *)h;
    double new_key = _pq_i2f(new_key_bits);
    for (int i = 0; i < pq->size; i++) {
        if (pq->values[i] == value) {
            if ((pq->is_min && new_key < pq->keys[i]) ||
                (!pq->is_min && new_key > pq->keys[i])) {
                pq->keys[i] = new_key;
                pq_sift_up(pq, i);
            }
            break;
        }
    }
}

void nuc_pq_free(long long h) {
    PQueue *pq = (PQueue *)(void *)h;
    if (pq) { free(pq->keys); free(pq->values); free(pq); }
}
