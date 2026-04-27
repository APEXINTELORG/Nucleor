// tensor3d_rt.c — 3D+ Tensor Operations for Nucleor
// N-dimensional tensors, reshape, slice, einsum-style contractions, broadcast.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/tensor3d_rt.c -o target/tensor3d_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _t3_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _t3_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  N-D Tensor
// ================================================================

#define T3_MAX_DIMS 8

typedef struct {
    int ndim;
    int shape[T3_MAX_DIMS];
    int strides[T3_MAX_DIMS]; // in element counts
    double *data;
    int total;
} Tensor3D;

static void t3_compute_strides(Tensor3D *t) {
    t->strides[t->ndim - 1] = 1;
    for (int i = t->ndim - 2; i >= 0; i--)
        t->strides[i] = t->strides[i + 1] * t->shape[i + 1];
    t->total = t->strides[0] * t->shape[0];
}

// v0.3.225: same overflow PANIC class as v0.3.223's tensor_zeros.
// (int) cast truncated >= 2^31 to negative, t->total signed-int
// product overflowed, calloc with negative -> garbage. Now: validate
// each dim non-negative + i32-fits, and check d1*d2*d3 fits in
// signed int total.
static void _check_t3_dims(long long d1, long long d2, long long d3) {
    if (d1 < 0 || d2 < 0 || d3 < 0) {
        fprintf(stderr, "PANIC: nuc_t3_new: negative dim (%lld, %lld, %lld)\n", d1, d2, d3);
        fflush(stderr); exit(1);
    }
    if (d1 > 2147483647LL || d2 > 2147483647LL || d3 > 2147483647LL) {
        fprintf(stderr, "PANIC: nuc_t3_new: dim exceeds i32 (%lld, %lld, %lld)\n", d1, d2, d3);
        fflush(stderr); exit(1);
    }
    /* Total fits in signed int? */
    if (d1 > 0 && d2 > 0 && d3 > (long long)(2147483647LL / (d1 * d2))) {
        fprintf(stderr, "PANIC: nuc_t3_new: total elements %lld * %lld * %lld exceeds i32\n", d1, d2, d3);
        fflush(stderr); exit(1);
    }
}

// Create 3D tensor
long long nuc_t3_new(long long d1, long long d2, long long d3) {
    _check_t3_dims(d1, d2, d3);
    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = 3;
    t->shape[0] = (int)d1; t->shape[1] = (int)d2; t->shape[2] = (int)d3;
    t3_compute_strides(t);
    t->data = (double *)calloc((size_t)t->total, sizeof(double));
    return (long long)t;
}

// Create N-D tensor from shape Vec
long long nuc_t3_new_nd(long long shape_h) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *sh = (NVec *)(void *)shape_h;
    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = sh->len;
    if (t->ndim > T3_MAX_DIMS) t->ndim = T3_MAX_DIMS;
    for (int i = 0; i < t->ndim; i++) t->shape[i] = (int)sh->data[i];
    t3_compute_strides(t);
    t->data = (double *)calloc(t->total, sizeof(double));
    return (long long)t;
}

long long nuc_t3_ndim(long long h) { return ((Tensor3D *)(void *)h)->ndim; }
long long nuc_t3_shape(long long h, long long dim) { return ((Tensor3D *)(void *)h)->shape[(int)dim]; }
long long nuc_t3_total(long long h) { return ((Tensor3D *)(void *)h)->total; }

// ================================================================
//  Get / Set (flat index or multi-index)
// ================================================================

// v0.3.203: NUC-FEEDBACK runtime safety. Same hazard class as the
// 2D tensor accessor in nucleor_llvm_rt.c -- zero bounds checking
// meant OOB indices read/wrote arbitrary memory. Local cached
// lookup of NUCLEOR_VEC_OOB_LENIENT (the same env var that
// governs vec / hashmap / 2D tensor strict mode) opts back into
// the legacy unchecked path for production ML kernels.
static int g_t3_oob_lenient = 0;  /* 0=uncached, 1=panic, 2=lenient */
static int _t3_lenient(void) {
    if (g_t3_oob_lenient == 0) {
        const char *e = getenv("NUCLEOR_VEC_OOB_LENIENT");
        g_t3_oob_lenient = (e && e[0] == '1') ? 2 : 1;
    }
    return g_t3_oob_lenient == 2;
}

long long nuc_t3_get(long long h, long long i, long long j, long long k) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (!t) return 0;
    if (i < 0 || j < 0 || k < 0 || i >= t->shape[0] || j >= t->shape[1] || k >= t->shape[2]) {
        if (_t3_lenient()) return 0;
        fprintf(stderr, "PANIC: nuc_t3_get OOB: index (%lld,%lld,%lld), shape (%lld,%lld,%lld) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                i, j, k, (long long)t->shape[0], (long long)t->shape[1], (long long)t->shape[2]);
        fflush(stderr);
        exit(1);
    }
    int idx = (int)i * t->strides[0] + (int)j * t->strides[1] + (int)k * t->strides[2];
    return _t3_f2i(t->data[idx]);
}

void nuc_t3_set(long long h, long long i, long long j, long long k, long long val_bits) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (!t) return;
    if (i < 0 || j < 0 || k < 0 || i >= t->shape[0] || j >= t->shape[1] || k >= t->shape[2]) {
        if (_t3_lenient()) return;
        fprintf(stderr, "PANIC: nuc_t3_set OOB: index (%lld,%lld,%lld), shape (%lld,%lld,%lld) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                i, j, k, (long long)t->shape[0], (long long)t->shape[1], (long long)t->shape[2]);
        fflush(stderr);
        exit(1);
    }
    int idx = (int)i * t->strides[0] + (int)j * t->strides[1] + (int)k * t->strides[2];
    t->data[idx] = _t3_i2f(val_bits);
}

long long nuc_t3_get_flat(long long h, long long idx) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (!t) return 0;
    if (idx < 0 || idx >= t->total) {
        if (_t3_lenient()) return 0;
        fprintf(stderr, "PANIC: nuc_t3_get_flat OOB: index %lld, total %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                idx, (long long)t->total);
        fflush(stderr);
        exit(1);
    }
    return _t3_f2i(t->data[(int)idx]);
}

void nuc_t3_set_flat(long long h, long long idx, long long val_bits) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (!t) return;
    if (idx < 0 || idx >= t->total) {
        if (_t3_lenient()) return;
        fprintf(stderr, "PANIC: nuc_t3_set_flat OOB: index %lld, total %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                idx, (long long)t->total);
        fflush(stderr);
        exit(1);
    }
    t->data[(int)idx] = _t3_i2f(val_bits);
}

// ================================================================
//  Fill / Zeros / Ones
// ================================================================

void nuc_t3_fill(long long h, long long val_bits) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    double v = _t3_i2f(val_bits);
    for (int i = 0; i < t->total; i++) t->data[i] = v;
}

// ================================================================
//  Reshape (returns new tensor with same data, different shape)
// ================================================================

long long nuc_t3_reshape(long long h, long long shape_h) {
    typedef struct { long long *data; int len; int cap; } NVec;
    Tensor3D *src = (Tensor3D *)(void *)h;
    NVec *sh = (NVec *)(void *)shape_h;

    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = sh->len;
    if (t->ndim > T3_MAX_DIMS) t->ndim = T3_MAX_DIMS;
    for (int i = 0; i < t->ndim; i++) t->shape[i] = (int)sh->data[i];
    t3_compute_strides(t);
    if (t->total != src->total) { free(t); return 0; }
    t->data = (double *)malloc(t->total * sizeof(double));
    memcpy(t->data, src->data, t->total * sizeof(double));
    return (long long)t;
}

// ================================================================
//  Slice along a dimension (returns 1-rank-lower tensor)
// ================================================================

long long nuc_t3_slice(long long h, long long dim, long long index) {
    Tensor3D *src = (Tensor3D *)(void *)h;
    int d = (int)dim, idx = (int)index;
    if (d >= src->ndim) return 0;

    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = src->ndim - 1;
    int j = 0;
    for (int i = 0; i < src->ndim; i++) {
        if (i != d) t->shape[j++] = src->shape[i];
    }
    t3_compute_strides(t);
    t->data = (double *)malloc(t->total * sizeof(double));

    // Copy slice
    int outer = 1, inner = 1;
    for (int i = 0; i < d; i++) outer *= src->shape[i];
    for (int i = d + 1; i < src->ndim; i++) inner *= src->shape[i];

    int dest = 0;
    for (int o = 0; o < outer; o++) {
        int src_offset = o * src->shape[d] * inner + idx * inner;
        memcpy(t->data + dest, src->data + src_offset, inner * sizeof(double));
        dest += inner;
    }
    return (long long)t;
}

// ================================================================
//  Element-wise operations
// ================================================================

long long nuc_t3_add(long long ah, long long bh) {
    Tensor3D *a = (Tensor3D *)(void *)ah, *b = (Tensor3D *)(void *)bh;
    if (a->total != b->total) return 0;
    Tensor3D *c = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    *c = *a;
    c->data = (double *)malloc(c->total * sizeof(double));
    for (int i = 0; i < c->total; i++) c->data[i] = a->data[i] + b->data[i];
    return (long long)c;
}

long long nuc_t3_mul(long long ah, long long bh) {
    Tensor3D *a = (Tensor3D *)(void *)ah, *b = (Tensor3D *)(void *)bh;
    if (a->total != b->total) return 0;
    Tensor3D *c = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    *c = *a;
    c->data = (double *)malloc(c->total * sizeof(double));
    for (int i = 0; i < c->total; i++) c->data[i] = a->data[i] * b->data[i];
    return (long long)c;
}

long long nuc_t3_scale(long long h, long long s_bits) {
    Tensor3D *a = (Tensor3D *)(void *)h;
    double s = _t3_i2f(s_bits);
    Tensor3D *c = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    *c = *a;
    c->data = (double *)malloc(c->total * sizeof(double));
    for (int i = 0; i < c->total; i++) c->data[i] = a->data[i] * s;
    return (long long)c;
}

// ================================================================
//  Sum along axis
// ================================================================

long long nuc_t3_sum_axis(long long h, long long axis) {
    Tensor3D *src = (Tensor3D *)(void *)h;
    int ax = (int)axis;
    if (ax >= src->ndim) return 0;

    Tensor3D *dst = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    dst->ndim = src->ndim - 1;
    int j = 0;
    for (int i = 0; i < src->ndim; i++) if (i != ax) dst->shape[j++] = src->shape[i];
    t3_compute_strides(dst);
    dst->data = (double *)calloc(dst->total, sizeof(double));

    int outer = 1, inner = 1;
    for (int i = 0; i < ax; i++) outer *= src->shape[i];
    for (int i = ax + 1; i < src->ndim; i++) inner *= src->shape[i];
    int k = src->shape[ax];

    for (int o = 0; o < outer; o++)
        for (int s = 0; s < k; s++)
            for (int in = 0; in < inner; in++)
                dst->data[o * inner + in] += src->data[o * k * inner + s * inner + in];

    return (long long)dst;
}

// ================================================================
//  Batch matrix multiply: [B, M, K] x [B, K, N] -> [B, M, N]
// ================================================================

long long nuc_t3_bmm(long long ah, long long bh) {
    Tensor3D *a = (Tensor3D *)(void *)ah, *b = (Tensor3D *)(void *)bh;
    if (a->ndim != 3 || b->ndim != 3) return 0;
    int B = a->shape[0], M = a->shape[1], K = a->shape[2], N = b->shape[2];
    if (b->shape[0] != B || b->shape[1] != K) return 0;

    Tensor3D *c = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    c->ndim = 3; c->shape[0] = B; c->shape[1] = M; c->shape[2] = N;
    t3_compute_strides(c);
    c->data = (double *)calloc(c->total, sizeof(double));

    for (int bi = 0; bi < B; bi++)
        for (int i = 0; i < M; i++)
            for (int j = 0; j < N; j++) {
                double sum = 0;
                for (int k = 0; k < K; k++)
                    sum += a->data[bi * M * K + i * K + k] * b->data[bi * K * N + k * N + j];
                c->data[bi * M * N + i * N + j] = sum;
            }
    return (long long)c;
}

void nuc_t3_free(long long h) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (t) { free(t->data); free(t); }
}
