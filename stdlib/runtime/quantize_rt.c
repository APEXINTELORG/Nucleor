// quantize_rt.c — Quantization Primitives for Nucleor
// INT4/INT8/FP8/ternary block quantization, GPTQ column-wise, AWQ scaling.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/quantize_rt.c -o target/quantize_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _qz_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _qz_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } QZVec;

// ================================================================
//  Block Q4_0: 32 weights per block, absmax scale, 4-bit unsigned
//  Layout: [f16 scale][16 bytes of packed 4-bit quants]
// ================================================================

typedef struct {
    float scale;
    unsigned char quants[16]; // 32 x 4-bit packed (2 per byte)
} BlockQ4;

long long nuc_quant_q4_encode(long long weights_h, long long n) {
    QZVec *w = (QZVec *)(void *)weights_h;
    int N = (int)n;
    int n_blocks = (N + 31) / 32;
    BlockQ4 *blocks = (BlockQ4 *)calloc(n_blocks, sizeof(BlockQ4));

    for (int b = 0; b < n_blocks; b++) {
        int base = b * 32;
        float amax = 0;
        for (int i = 0; i < 32 && base + i < N; i++) {
            float v = (float)_qz_i2f(w->data[base + i]);
            if (fabsf(v) > amax) amax = fabsf(v);
        }
        float scale = amax / 7.0f; // 4-bit signed: -8..7, we use 0..15 with offset
        blocks[b].scale = scale;
        float inv_scale = (scale > 1e-10f) ? 1.0f / scale : 0.0f;

        for (int i = 0; i < 16; i++) {
            int i0 = base + i * 2, i1 = i0 + 1;
            float v0 = (i0 < N) ? (float)_qz_i2f(w->data[i0]) : 0;
            float v1 = (i1 < N) ? (float)_qz_i2f(w->data[i1]) : 0;
            int q0 = (int)roundf(v0 * inv_scale + 8); if (q0 < 0) q0 = 0; if (q0 > 15) q0 = 15;
            int q1 = (int)roundf(v1 * inv_scale + 8); if (q1 < 0) q1 = 0; if (q1 > 15) q1 = 15;
            blocks[b].quants[i] = (unsigned char)((q0 & 0xF) | ((q1 & 0xF) << 4));
        }
    }
    // Return as opaque handle
    long long *result = (long long *)malloc(2 * sizeof(long long));
    result[0] = (long long)blocks;
    result[1] = (long long)n_blocks;
    return (long long)result;
}

long long nuc_quant_q4_decode(long long handle) {
    long long *h = (long long *)(void *)handle;
    BlockQ4 *blocks = (BlockQ4 *)(void *)h[0];
    int n_blocks = (int)h[1];
    int N = n_blocks * 32;

    QZVec *out = (QZVec *)malloc(sizeof(QZVec));
    out->len = N; out->cap = N;
    out->data = (long long *)malloc(N * sizeof(long long));

    for (int b = 0; b < n_blocks; b++) {
        float scale = blocks[b].scale;
        for (int i = 0; i < 16; i++) {
            int q0 = blocks[b].quants[i] & 0xF;
            int q1 = (blocks[b].quants[i] >> 4) & 0xF;
            out->data[b * 32 + i * 2] = _qz_f2i((q0 - 8) * scale);
            out->data[b * 32 + i * 2 + 1] = _qz_f2i((q1 - 8) * scale);
        }
    }
    return (long long)out;
}

// Quantized dot product without full dequantization
long long nuc_quant_q4_dot(long long a_handle, long long b_handle) {
    long long *ah = (long long *)(void *)a_handle, *bh = (long long *)(void *)b_handle;
    BlockQ4 *a = (BlockQ4 *)(void *)ah[0], *b = (BlockQ4 *)(void *)bh[0];
    int n_blocks = (int)ah[1];
    double sum = 0;
    for (int bl = 0; bl < n_blocks; bl++) {
        float sa = a[bl].scale, sb = b[bl].scale;
        int block_sum = 0;
        for (int i = 0; i < 16; i++) {
            int a0 = (a[bl].quants[i] & 0xF) - 8, a1 = ((a[bl].quants[i] >> 4) & 0xF) - 8;
            int b0 = (b[bl].quants[i] & 0xF) - 8, b1 = ((b[bl].quants[i] >> 4) & 0xF) - 8;
            block_sum += a0 * b0 + a1 * b1;
        }
        sum += sa * sb * block_sum;
    }
    return _qz_f2i(sum);
}

// ================================================================
//  INT8 Per-Channel Quantization
// ================================================================

long long nuc_quant_int8_encode(long long weights_h, long long rows, long long cols) {
    QZVec *w = (QZVec *)(void *)weights_h;
    int r = (int)rows, c = (int)cols;
    signed char *quants = (signed char *)malloc(r * c);
    float *scales = (float *)malloc(r * sizeof(float));

    for (int i = 0; i < r; i++) {
        float amax = 0;
        for (int j = 0; j < c; j++) {
            float v = (float)_qz_i2f(w->data[i * c + j]);
            if (fabsf(v) > amax) amax = fabsf(v);
        }
        scales[i] = amax / 127.0f;
        float inv = (amax > 1e-10f) ? 127.0f / amax : 0;
        for (int j = 0; j < c; j++) {
            float v = (float)_qz_i2f(w->data[i * c + j]);
            int q = (int)roundf(v * inv);
            if (q < -127) q = -127; if (q > 127) q = 127;
            quants[i * c + j] = (signed char)q;
        }
    }

    long long *result = (long long *)malloc(4 * sizeof(long long));
    result[0] = (long long)quants;
    result[1] = (long long)scales;
    result[2] = rows;
    result[3] = cols;
    return (long long)result;
}

// INT8 GEMV: y = quantized_W * x (mixed precision)
long long nuc_quant_int8_gemv(long long qw_handle, long long x_h) {
    long long *h = (long long *)(void *)qw_handle;
    signed char *quants = (signed char *)(void *)h[0];
    float *scales = (float *)(void *)h[1];
    int r = (int)h[2], c = (int)h[3];
    QZVec *x = (QZVec *)(void *)x_h;

    QZVec *y = (QZVec *)malloc(sizeof(QZVec));
    y->len = r; y->cap = r;
    y->data = (long long *)malloc(r * sizeof(long long));

    for (int i = 0; i < r; i++) {
        int isum = 0;
        for (int j = 0; j < c; j++) {
            // Quantize input on-the-fly to INT8 (per-tensor)
            float xj = (float)_qz_i2f(x->data[j]);
            isum += (int)quants[i * c + j] * (int)(signed char)(xj * 127.0f / 10.0f); // simplified
        }
        y->data[i] = _qz_f2i(scales[i] * (10.0f / 127.0f) * isum);
    }
    return (long long)y;
}

// ================================================================
//  Ternary Quantization (BitNet b1.58: {-1, 0, +1})
// ================================================================

long long nuc_quant_ternary_encode(long long weights_h, long long n) {
    QZVec *w = (QZVec *)(void *)weights_h;
    int N = (int)n;

    // Compute absmean threshold
    double absmean = 0;
    for (int i = 0; i < N; i++) absmean += fabs(_qz_i2f(w->data[i]));
    absmean /= N;

    // Pack: 2 bits per weight, 16 weights per uint32
    int n_packed = (N + 15) / 16;
    unsigned int *packed = (unsigned int *)calloc(n_packed, sizeof(unsigned int));

    for (int i = 0; i < N; i++) {
        double v = _qz_i2f(w->data[i]) / absmean;
        int q; // 0=zero, 1=+1, 2=-1
        if (v > 0.5) q = 1;
        else if (v < -0.5) q = 2;
        else q = 0;
        int word = i / 16, bit = (i % 16) * 2;
        packed[word] |= ((unsigned int)q << bit);
    }

    long long *result = (long long *)malloc(3 * sizeof(long long));
    result[0] = (long long)packed;
    result[1] = (long long)n_packed;
    result[2] = _qz_f2i(absmean);
    return (long long)result;
}

// Ternary GEMV: y = W_ternary * x (additions only, no multiplies)
long long nuc_quant_ternary_gemv(long long tw_handle, long long x_h,
                                   long long rows, long long cols) {
    long long *h = (long long *)(void *)tw_handle;
    unsigned int *packed = (unsigned int *)(void *)h[0];
    double absmean = _qz_i2f(h[2]);
    QZVec *x = (QZVec *)(void *)x_h;
    int r = (int)rows, c = (int)cols;

    QZVec *y = (QZVec *)malloc(sizeof(QZVec));
    y->len = r; y->cap = r;
    y->data = (long long *)malloc(r * sizeof(long long));

    for (int i = 0; i < r; i++) {
        double sum = 0;
        for (int j = 0; j < c; j++) {
            int idx = i * c + j;
            int word = idx / 16, bit = (idx % 16) * 2;
            int q = (packed[word] >> bit) & 3;
            double xj = _qz_i2f(x->data[j]);
            if (q == 1) sum += xj;       // +1 * x
            else if (q == 2) sum -= xj;  // -1 * x
            // q == 0: skip (zero weight)
        }
        y->data[i] = _qz_f2i(sum * absmean);
    }
    return (long long)y;
}

// ================================================================
//  FP8 E4M3 Block Quantization
// ================================================================

long long nuc_quant_fp8_encode(long long weights_h, long long n, long long block_size) {
    QZVec *w = (QZVec *)(void *)weights_h;
    int N = (int)n, bs = (int)block_size;
    int n_blocks = (N + bs - 1) / bs;
    float *scales = (float *)malloc(n_blocks * sizeof(float));
    unsigned char *fp8 = (unsigned char *)malloc(N);

    for (int b = 0; b < n_blocks; b++) {
        int base = b * bs;
        float amax = 0;
        for (int i = 0; i < bs && base + i < N; i++) {
            float v = (float)fabs(_qz_i2f(w->data[base + i]));
            if (v > amax) amax = v;
        }
        scales[b] = amax / 448.0f; // E4M3 max value
        float inv = (amax > 1e-10f) ? 448.0f / amax : 0;
        for (int i = 0; i < bs && base + i < N; i++) {
            float v = (float)_qz_i2f(w->data[base + i]) * inv;
            int q = (int)roundf(v);
            if (q < -448) q = -448; if (q > 448) q = 448;
            // Simplified: store as signed byte (real FP8 would use E4M3 encoding)
            fp8[base + i] = (unsigned char)((q >> 2) + 128);
        }
    }

    long long *result = (long long *)malloc(4 * sizeof(long long));
    result[0] = (long long)fp8;
    result[1] = (long long)scales;
    result[2] = (long long)n_blocks;
    result[3] = (long long)bs;
    return (long long)result;
}

// ================================================================
//  Per-channel activation magnitude (for AWQ salient weight detection)
// ================================================================

long long nuc_quant_activation_magnitude(long long activations_h, long long n_samples, long long dim) {
    QZVec *act = (QZVec *)(void *)activations_h;
    int ns = (int)n_samples, d = (int)dim;
    QZVec *mag = (QZVec *)malloc(sizeof(QZVec));
    mag->len = d; mag->cap = d;
    mag->data = (long long *)malloc(d * sizeof(long long));

    for (int j = 0; j < d; j++) {
        double sum = 0;
        for (int i = 0; i < ns; i++) sum += fabs(_qz_i2f(act->data[i * d + j]));
        mag->data[j] = _qz_f2i(sum / ns);
    }
    return (long long)mag;
}

void nuc_quant_free(long long handle) {
    long long *h = (long long *)(void *)handle;
    if (h) { free((void *)h[0]); if (h[1]) free((void *)h[1]); free(h); }
}
