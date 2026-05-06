// f64_buffer_rt.c -- caller-owned scratch buffers for raw double[] rod APIs.
//
// Several robotics and vision rods intentionally expose C-style double*
// interfaces for zero-copy interop. This helper gives Nucleor tests and
// adopters a small, typed way to allocate, fill, pass, and inspect those
// buffers without inventing per-rod ad hoc shims.

#include <stdlib.h>
#include <string.h>

typedef struct {
    long long len;
    double *data;
} NucF64Buf;

static double _fb_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _fb_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

long long nuc_f64_buf_new(long long len) {
    if (len <= 0 || len > (1LL << 28)) return 0;
    NucF64Buf *b = (NucF64Buf *)calloc(1, sizeof(NucF64Buf));
    if (!b) return 0;
    b->data = (double *)calloc((size_t)len, sizeof(double));
    if (!b->data) { free(b); return 0; }
    b->len = len;
    return (long long)(size_t)b;
}

long long nuc_f64_buf_len(long long h) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    return b ? b->len : 0;
}

long long nuc_f64_buf_ptr(long long h) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    return (b && b->data) ? (long long)(size_t)b->data : 0;
}

long long nuc_f64_buf_set(long long h, long long idx, long long val_bits) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    if (!b || !b->data || idx < 0 || idx >= b->len) return 0;
    b->data[idx] = _fb_i2f(val_bits);
    return 1;
}

long long nuc_f64_buf_get(long long h, long long idx) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    if (!b || !b->data || idx < 0 || idx >= b->len) return _fb_f2i(0.0);
    return _fb_f2i(b->data[idx]);
}

void nuc_f64_buf_zero(long long h) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    if (!b || !b->data || b->len <= 0) return;
    memset(b->data, 0, (size_t)b->len * sizeof(double));
}

void nuc_f64_buf_free(long long h) {
    NucF64Buf *b = (NucF64Buf *)(void *)(size_t)h;
    if (!b) return;
    free(b->data);
    free(b);
}
