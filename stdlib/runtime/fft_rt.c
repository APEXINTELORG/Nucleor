// fft_rt.c — Standalone Fast Fourier Transform for Nucleor
// Cooley-Tukey radix-2, 1D/2D, convolution, power spectrum, correlation.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/fft_rt.c -o target/fft_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ff_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ff_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } FFVec;

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  Radix-2 FFT (in-place, Cooley-Tukey)
//  re[n], im[n], n must be power of 2
//  sign = -1 for forward, +1 for inverse
// ================================================================

static void fft_core(double *re, double *im, int n, int sign) {
    // Bit-reversal permutation
    for (int i = 1, j = 0; i < n; i++) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            double t = re[i]; re[i] = re[j]; re[j] = t;
            t = im[i]; im[i] = im[j]; im[j] = t;
        }
    }

    // Butterfly
    for (int len = 2; len <= n; len <<= 1) {
        double ang = sign * 2 * M_PI / len;
        double wn_re = cos(ang), wn_im = sin(ang);
        for (int i = 0; i < n; i += len) {
            double w_re = 1, w_im = 0;
            for (int j = 0; j < len / 2; j++) {
                int u_idx = i + j, v_idx = i + j + len / 2;
                double t_re = w_re * re[v_idx] - w_im * im[v_idx];
                double t_im = w_re * im[v_idx] + w_im * re[v_idx];
                re[v_idx] = re[u_idx] - t_re;
                im[v_idx] = im[u_idx] - t_im;
                re[u_idx] += t_re;
                im[u_idx] += t_im;
                double wr = w_re * wn_re - w_im * wn_im;
                w_im = w_re * wn_im + w_im * wn_re;
                w_re = wr;
            }
        }
    }

    if (sign == 1) {
        for (int i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
    }
}

static int next_pow2(int n) {
    int p = 1; while (p < n) p <<= 1; return p;
}

// ================================================================
//  1D FFT
//  data: Vec<f64> [re0, im0, re1, im1, ...] interleaved
//  forward: 1 = forward, 0 = inverse
//  Returns interleaved complex Vec
// ================================================================

long long nuc_fft_1d(long long data_h, long long n, long long forward) {
    FFVec *data = (FFVec *)(void *)data_h;
    int N = (int)n;
    int N2 = next_pow2(N);

    double *re = (double *)calloc(N2, sizeof(double));
    double *im = (double *)calloc(N2, sizeof(double));
    for (int i = 0; i < N && i * 2 + 1 < data->len; i++) {
        re[i] = _ff_i2f(data->data[i * 2]);
        im[i] = _ff_i2f(data->data[i * 2 + 1]);
    }

    fft_core(re, im, N2, forward ? -1 : 1);

    FFVec *result = (FFVec *)malloc(sizeof(FFVec));
    result->len = N2 * 2; result->cap = result->len;
    result->data = (long long *)malloc(result->len * sizeof(long long));
    for (int i = 0; i < N2; i++) {
        result->data[i * 2] = _ff_f2i(re[i]);
        result->data[i * 2 + 1] = _ff_f2i(im[i]);
    }
    free(re); free(im);
    return (long long)result;
}

// ================================================================
//  1D FFT from real data (returns interleaved complex)
// ================================================================

long long nuc_fft_1d_real(long long data_h, long long n) {
    FFVec *data = (FFVec *)(void *)data_h;
    int N = (int)n;
    int N2 = next_pow2(N);

    double *re = (double *)calloc(N2, sizeof(double));
    double *im = (double *)calloc(N2, sizeof(double));
    for (int i = 0; i < N && i < data->len; i++) re[i] = _ff_i2f(data->data[i]);

    fft_core(re, im, N2, -1);

    FFVec *result = (FFVec *)malloc(sizeof(FFVec));
    result->len = N2 * 2; result->cap = result->len;
    result->data = (long long *)malloc(result->len * sizeof(long long));
    for (int i = 0; i < N2; i++) {
        result->data[i * 2] = _ff_f2i(re[i]);
        result->data[i * 2 + 1] = _ff_f2i(im[i]);
    }
    free(re); free(im);
    return (long long)result;
}

// ================================================================
//  FFT-based Convolution
// ================================================================

long long nuc_fft_convolve(long long a_h, long long b_h, long long n) {
    FFVec *a = (FFVec *)(void *)a_h, *b = (FFVec *)(void *)b_h;
    int N = (int)n;
    int N2 = next_pow2(2 * N);

    double *a_re = (double *)calloc(N2, sizeof(double));
    double *a_im = (double *)calloc(N2, sizeof(double));
    double *b_re = (double *)calloc(N2, sizeof(double));
    double *b_im = (double *)calloc(N2, sizeof(double));

    for (int i = 0; i < N && i < a->len; i++) a_re[i] = _ff_i2f(a->data[i]);
    for (int i = 0; i < N && i < b->len; i++) b_re[i] = _ff_i2f(b->data[i]);

    fft_core(a_re, a_im, N2, -1);
    fft_core(b_re, b_im, N2, -1);

    // Pointwise complex multiply
    double *c_re = (double *)malloc(N2 * sizeof(double));
    double *c_im = (double *)malloc(N2 * sizeof(double));
    for (int i = 0; i < N2; i++) {
        c_re[i] = a_re[i] * b_re[i] - a_im[i] * b_im[i];
        c_im[i] = a_re[i] * b_im[i] + a_im[i] * b_re[i];
    }

    fft_core(c_re, c_im, N2, 1);

    FFVec *result = (FFVec *)malloc(sizeof(FFVec));
    result->len = N2; result->cap = N2;
    result->data = (long long *)malloc(N2 * sizeof(long long));
    for (int i = 0; i < N2; i++) result->data[i] = _ff_f2i(c_re[i]);

    free(a_re); free(a_im); free(b_re); free(b_im);
    free(c_re); free(c_im);
    return (long long)result;
}

// ================================================================
//  Power Spectrum (|FFT(x)|^2)
// ================================================================

long long nuc_fft_power_spectrum(long long data_h, long long n) {
    FFVec *data = (FFVec *)(void *)data_h;
    int N = (int)n;
    int N2 = next_pow2(N);

    double *re = (double *)calloc(N2, sizeof(double));
    double *im = (double *)calloc(N2, sizeof(double));
    for (int i = 0; i < N && i < data->len; i++) re[i] = _ff_i2f(data->data[i]);

    fft_core(re, im, N2, -1);

    int half = N2 / 2 + 1;
    FFVec *result = (FFVec *)malloc(sizeof(FFVec));
    result->len = half; result->cap = half;
    result->data = (long long *)malloc(half * sizeof(long long));
    for (int i = 0; i < half; i++)
        result->data[i] = _ff_f2i(re[i] * re[i] + im[i] * im[i]);

    free(re); free(im);
    return (long long)result;
}

// ================================================================
//  Cross-Correlation via FFT
// ================================================================

long long nuc_fft_correlate(long long a_h, long long b_h, long long n) {
    FFVec *a = (FFVec *)(void *)a_h, *b = (FFVec *)(void *)b_h;
    int N = (int)n;
    int N2 = next_pow2(2 * N);

    double *a_re = (double *)calloc(N2, sizeof(double));
    double *a_im = (double *)calloc(N2, sizeof(double));
    double *b_re = (double *)calloc(N2, sizeof(double));
    double *b_im = (double *)calloc(N2, sizeof(double));

    for (int i = 0; i < N && i < a->len; i++) a_re[i] = _ff_i2f(a->data[i]);
    for (int i = 0; i < N && i < b->len; i++) b_re[i] = _ff_i2f(b->data[i]);

    fft_core(a_re, a_im, N2, -1);
    fft_core(b_re, b_im, N2, -1);

    // Multiply A * conj(B)
    double *c_re = (double *)malloc(N2 * sizeof(double));
    double *c_im = (double *)malloc(N2 * sizeof(double));
    for (int i = 0; i < N2; i++) {
        c_re[i] = a_re[i] * b_re[i] + a_im[i] * b_im[i];
        c_im[i] = -a_re[i] * b_im[i] + a_im[i] * b_re[i];
    }

    fft_core(c_re, c_im, N2, 1);

    FFVec *result = (FFVec *)malloc(sizeof(FFVec));
    result->len = N2; result->cap = N2;
    result->data = (long long *)malloc(N2 * sizeof(long long));
    for (int i = 0; i < N2; i++) result->data[i] = _ff_f2i(c_re[i]);

    free(a_re); free(a_im); free(b_re); free(b_im);
    free(c_re); free(c_im);
    return (long long)result;
}
