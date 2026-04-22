// signal_rt.c — Digital Signal Processing for Nucleor
// FIR/IIR filters, Butterworth design, windows, Hilbert, envelope, resampling.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/signal_rt.c -o target/signal_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _sg_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _sg_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } SGVec;

static SGVec *sgvec_new(int n) {
    SGVec *v = (SGVec *)malloc(sizeof(SGVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  FIR Filter (direct convolution)
// ================================================================

long long nuc_sig_fir_filter(long long signal_h, long long coeffs_h) {
    SGVec *x = (SGVec *)(void *)signal_h;
    SGVec *h = (SGVec *)(void *)coeffs_h;
    int nx = x->len, nh = h->len;
    SGVec *y = sgvec_new(nx);

    for (int i = 0; i < nx; i++) {
        double sum = 0;
        for (int j = 0; j < nh; j++) {
            int idx = i - j;
            if (idx >= 0 && idx < nx)
                sum += _sg_i2f(h->data[j]) * _sg_i2f(x->data[idx]);
        }
        y->data[i] = _sg_f2i(sum);
    }
    return (long long)y;
}

// ================================================================
//  IIR Filter (Direct Form II)
//  y[n] = sum(b[k]*x[n-k]) - sum(a[k]*y[n-k])
// ================================================================

long long nuc_sig_iir_filter(long long signal_h, long long b_h, long long a_h) {
    SGVec *x = (SGVec *)(void *)signal_h;
    SGVec *b = (SGVec *)(void *)b_h;
    SGVec *a = (SGVec *)(void *)a_h;
    int nx = x->len, nb = b->len, na = a->len;
    SGVec *y = sgvec_new(nx);

    double a0 = _sg_i2f(a->data[0]);
    if (fabs(a0) < 1e-30) a0 = 1.0;

    for (int i = 0; i < nx; i++) {
        double sum = 0;
        for (int j = 0; j < nb; j++) {
            if (i - j >= 0) sum += _sg_i2f(b->data[j]) * _sg_i2f(x->data[i - j]);
        }
        for (int j = 1; j < na; j++) {
            if (i - j >= 0) sum -= _sg_i2f(a->data[j]) * _sg_i2f(y->data[i - j]);
        }
        y->data[i] = _sg_f2i(sum / a0);
    }
    return (long long)y;
}

// ================================================================
//  Butterworth Lowpass Filter Design (2nd order)
//  Returns [b0, b1, b2, a0, a1, a2] as Vec
// ================================================================

long long nuc_sig_butterworth(long long order, long long cutoff_bits, long long sr_bits) {
    double fc = _sg_i2f(cutoff_bits), sr = _sg_i2f(sr_bits);
    double w = tan(M_PI * fc / sr);
    double w2 = w * w;
    double n_ord = (int)order;

    // 2nd order Butterworth
    double q = sqrt(2.0); // Q for 2nd order Butterworth
    double a0 = 1 + w / q + w2;

    SGVec *coeffs = sgvec_new(6);
    coeffs->data[0] = _sg_f2i(w2 / a0);           // b0
    coeffs->data[1] = _sg_f2i(2 * w2 / a0);       // b1
    coeffs->data[2] = _sg_f2i(w2 / a0);           // b2
    coeffs->data[3] = _sg_f2i(1.0);                // a0 (normalized)
    coeffs->data[4] = _sg_f2i(2 * (w2 - 1) / a0); // a1
    coeffs->data[5] = _sg_f2i((1 - w / q + w2) / a0); // a2
    (void)n_ord; // higher orders would chain 2nd-order sections
    return (long long)coeffs;
}

// ================================================================
//  Window Functions
// ================================================================

long long nuc_sig_window_hamming(long long n) {
    int N = (int)n;
    SGVec *w = sgvec_new(N);
    for (int i = 0; i < N; i++)
        w->data[i] = _sg_f2i(0.54 - 0.46 * cos(2 * M_PI * i / (N - 1)));
    return (long long)w;
}

long long nuc_sig_window_hann(long long n) {
    int N = (int)n;
    SGVec *w = sgvec_new(N);
    for (int i = 0; i < N; i++)
        w->data[i] = _sg_f2i(0.5 * (1 - cos(2 * M_PI * i / (N - 1))));
    return (long long)w;
}

long long nuc_sig_window_blackman(long long n) {
    int N = (int)n;
    SGVec *w = sgvec_new(N);
    for (int i = 0; i < N; i++)
        w->data[i] = _sg_f2i(0.42 - 0.5 * cos(2 * M_PI * i / (N - 1))
                              + 0.08 * cos(4 * M_PI * i / (N - 1)));
    return (long long)w;
}

// ================================================================
//  Envelope (magnitude of analytic signal via Hilbert approx)
// ================================================================

long long nuc_sig_envelope(long long signal_h) {
    SGVec *x = (SGVec *)(void *)signal_h;
    int n = x->len;
    SGVec *env = sgvec_new(n);

    // Simple envelope: sqrt(x^2 + hilbert(x)^2)
    // Hilbert approximation via FIR (odd-length, 1/k for odd k)
    int hlen = 31;
    for (int i = 0; i < n; i++) {
        double xi = _sg_i2f(x->data[i]);
        double hi = 0;
        for (int k = 1; k <= hlen; k += 2) {
            double coeff = 2.0 / (M_PI * k);
            if (i - k >= 0) hi += coeff * _sg_i2f(x->data[i - k]);
            if (i + k < n) hi -= coeff * _sg_i2f(x->data[i + k]);
        }
        env->data[i] = _sg_f2i(sqrt(xi * xi + hi * hi));
    }
    return (long long)env;
}

// ================================================================
//  Zero Crossings
// ================================================================

long long nuc_sig_zero_crossings(long long signal_h) {
    SGVec *x = (SGVec *)(void *)signal_h;
    SGVec *crossings = sgvec_new(0);
    crossings->cap = 256;
    crossings->data = (long long *)realloc(crossings->data, 256 * sizeof(long long));

    for (int i = 1; i < x->len; i++) {
        double a = _sg_i2f(x->data[i - 1]), b = _sg_i2f(x->data[i]);
        if ((a >= 0 && b < 0) || (a < 0 && b >= 0)) {
            if (crossings->len >= crossings->cap) {
                crossings->cap *= 2;
                crossings->data = (long long *)realloc(crossings->data, crossings->cap * sizeof(long long));
            }
            crossings->data[crossings->len++] = i;
        }
    }
    return (long long)crossings;
}

// ================================================================
//  Downsample by integer factor
// ================================================================

long long nuc_sig_downsample(long long signal_h, long long factor) {
    SGVec *x = (SGVec *)(void *)signal_h;
    int f = (int)factor;
    if (f < 1) f = 1;
    int out_len = x->len / f;
    SGVec *y = sgvec_new(out_len);
    for (int i = 0; i < out_len; i++) y->data[i] = x->data[i * f];
    return (long long)y;
}

// ================================================================
//  Upsample by integer factor (zero-insertion)
// ================================================================

long long nuc_sig_upsample(long long signal_h, long long factor) {
    SGVec *x = (SGVec *)(void *)signal_h;
    int f = (int)factor;
    if (f < 1) f = 1;
    int out_len = x->len * f;
    SGVec *y = sgvec_new(out_len);
    for (int i = 0; i < x->len; i++) y->data[i * f] = x->data[i];
    return (long long)y;
}
