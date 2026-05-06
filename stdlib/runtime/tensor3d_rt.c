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

static void _check_t3_dims2(long long rows, long long cols) {
    if (rows < 0 || cols < 0) {
        fprintf(stderr, "PANIC: nuc_t3_new_2d: negative dim (%lld, %lld)\n", rows, cols);
        fflush(stderr); exit(1);
    }
    if (rows > 2147483647LL || cols > 2147483647LL) {
        fprintf(stderr, "PANIC: nuc_t3_new_2d: dim exceeds i32 (%lld, %lld)\n", rows, cols);
        fflush(stderr); exit(1);
    }
    if (rows > 0 && cols > (long long)(2147483647LL / rows)) {
        fprintf(stderr, "PANIC: nuc_t3_new_2d: total elements %lld * %lld exceeds i32\n", rows, cols);
        fflush(stderr); exit(1);
    }
}

long long nuc_t3_new_2d(long long rows, long long cols) {
    _check_t3_dims2(rows, cols);
    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = 2;
    t->shape[0] = (int)rows; t->shape[1] = (int)cols;
    t3_compute_strides(t);
    t->data = (double *)calloc((size_t)t->total, sizeof(double));
    return (long long)t;
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
// v0.3.228: nuc_t3_new_nd safety -- NULL shape handle, dim
// validation, total overflow check. Same hazard class as
// v0.3.225's nuc_t3_new fix.
long long nuc_t3_new_nd(long long shape_h) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *sh = (NVec *)(void *)shape_h;
    if (!sh) {
        fprintf(stderr, "PANIC: nuc_t3_new_nd: null shape handle\n");
        fflush(stderr); exit(1);
    }
    if (sh->len <= 0) {
        fprintf(stderr, "PANIC: nuc_t3_new_nd: empty shape (len %d)\n", sh->len);
        fflush(stderr); exit(1);
    }
    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = sh->len;
    if (t->ndim > T3_MAX_DIMS) t->ndim = T3_MAX_DIMS;
    long long total_check = 1;
    for (int i = 0; i < t->ndim; i++) {
        long long d = sh->data[i];
        if (d < 0 || d > 2147483647LL) {
            fprintf(stderr, "PANIC: nuc_t3_new_nd: dim[%d] out of i32 range (%lld)\n", i, d);
            fflush(stderr); free(t); exit(1);
        }
        if (d > 0 && total_check > 2147483647LL / d) {
            fprintf(stderr, "PANIC: nuc_t3_new_nd: total elements exceed i32 (dim[%d]=%lld)\n", i, d);
            fflush(stderr); free(t); exit(1);
        }
        total_check *= d;
        t->shape[i] = (int)d;
    }
    t3_compute_strides(t);
    t->data = (double *)calloc((size_t)t->total, sizeof(double));
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

// 2D matrix multiply: [M, K] x [K, N] -> [M, N]
long long nuc_t3_matmul(long long ah, long long bh) {
    Tensor3D *a = (Tensor3D *)(void *)ah, *b = (Tensor3D *)(void *)bh;
    if (!a || !b) return 0;
    if (a->ndim != 2 || b->ndim != 2) return 0;
    int M = a->shape[0], K = a->shape[1], N = b->shape[1];
    if (b->shape[0] != K) return 0;

    Tensor3D *c = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    c->ndim = 2; c->shape[0] = M; c->shape[1] = N;
    t3_compute_strides(c);
    c->data = (double *)calloc((size_t)c->total, sizeof(double));

    for (int i = 0; i < M; i++) {
        for (int k = 0; k < K; k++) {
            double av = a->data[i * K + k];
            for (int j = 0; j < N; j++) {
                c->data[i * N + j] += av * b->data[k * N + j];
            }
        }
    }
    return (long long)c;
}

long long nuc_t3_transpose(long long h) {
    Tensor3D *a = (Tensor3D *)(void *)h;
    if (!a || a->ndim != 2) return 0;
    int rows = a->shape[0], cols = a->shape[1];

    Tensor3D *t = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    t->ndim = 2; t->shape[0] = cols; t->shape[1] = rows;
    t3_compute_strides(t);
    t->data = (double *)malloc((size_t)t->total * sizeof(double));

    for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
            t->data[c * rows + r] = a->data[r * cols + c];
        }
    }
    return (long long)t;
}

long long nuc_t3_permute(long long h, long long axes_h) {
    typedef struct { long long *data; int len; int cap; } NVec;
    Tensor3D *src = (Tensor3D *)(void *)h;
    NVec *axes = (NVec *)(void *)axes_h;
    if (!src || !axes) return 0;
    if (axes->len != src->ndim) return 0;

    int used[T3_MAX_DIMS] = {0};
    int axis_map[T3_MAX_DIMS] = {0};
    for (int i = 0; i < axes->len; i++) {
        long long a = axes->data[i];
        if (a < 0 || a >= src->ndim) return 0;
        if (used[(int)a]) return 0;
        used[(int)a] = 1;
        axis_map[i] = (int)a;
    }

    Tensor3D *dst = (Tensor3D *)calloc(1, sizeof(Tensor3D));
    dst->ndim = src->ndim;
    for (int i = 0; i < dst->ndim; i++) dst->shape[i] = src->shape[axis_map[i]];
    t3_compute_strides(dst);
    dst->data = (double *)malloc((size_t)dst->total * sizeof(double));

    for (int out = 0; out < dst->total; out++) {
        int rem = out;
        int src_idx = 0;
        for (int d = 0; d < dst->ndim; d++) {
            int coord = rem / dst->strides[d];
            rem = rem % dst->strides[d];
            src_idx += coord * src->strides[axis_map[d]];
        }
        dst->data[out] = src->data[src_idx];
    }
    return (long long)dst;
}

void nuc_t3_free(long long h) {
    Tensor3D *t = (Tensor3D *)(void *)h;
    if (t) { free(t->data); free(t); }
}
