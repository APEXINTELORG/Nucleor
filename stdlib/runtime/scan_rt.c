// scan_rt.c — Parallel Prefix Scan (Associative Scan) for Nucleor
// Inclusive/exclusive prefix sum, segmented scan, generic associative scan.
// Core primitive for SSMs, xLSTM, RWKV, cumulative operations.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/scan_rt.c -o target/scan_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _sc_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _sc_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } SCVec;

static SCVec *scvec_new(int n) {
    SCVec *v = (SCVec *)malloc(sizeof(SCVec));
    v->len = n; v->cap = n; v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Inclusive Prefix Sum (Blelloch-style, sequential)
// ================================================================

long long nuc_scan_prefix_sum(long long vh) {
    SCVec *v = (SCVec *)(void *)vh;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running = 0;
    for (int i = 0; i < n; i++) {
        running += _sc_i2f(v->data[i]);
        out->data[i] = _sc_f2i(running);
    }
    return (long long)out;
}

// Exclusive prefix sum (shifted by one, first element = 0)
long long nuc_scan_prefix_sum_exclusive(long long vh) {
    SCVec *v = (SCVec *)(void *)vh;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running = 0;
    for (int i = 0; i < n; i++) {
        out->data[i] = _sc_f2i(running);
        running += _sc_i2f(v->data[i]);
    }
    return (long long)out;
}

// ================================================================
//  Prefix Product (for cumulative decay in SSMs)
// ================================================================

long long nuc_scan_prefix_prod(long long vh) {
    SCVec *v = (SCVec *)(void *)vh;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running = 1.0;
    for (int i = 0; i < n; i++) {
        running *= _sc_i2f(v->data[i]);
        out->data[i] = _sc_f2i(running);
    }
    return (long long)out;
}

// ================================================================
//  Prefix Max (for running maximum)
// ================================================================

long long nuc_scan_prefix_max(long long vh) {
    SCVec *v = (SCVec *)(void *)vh;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running = -1e30;
    for (int i = 0; i < n; i++) {
        double x = _sc_i2f(v->data[i]);
        if (x > running) running = x;
        out->data[i] = _sc_f2i(running);
    }
    return (long long)out;
}

// ================================================================
//  Generic Associative Scan
//  op: function(a, b) -> c (must be associative)
//  Used for SSM recurrences: (a_i, b_i) * (a_j, b_j) = (a_i * a_j, a_j * b_i + b_j)
//  Operates on pairs: a_vec[i], b_vec[i]
// ================================================================

long long nuc_scan_associative_linear(long long a_h, long long b_h) {
    // For linear recurrence: h_t = a_t * h_{t-1} + b_t
    // Associative scan with op: (a1,b1) * (a2,b2) = (a1*a2, a2*b1 + b2)
    SCVec *a = (SCVec *)(void *)a_h; // decay factors
    SCVec *b = (SCVec *)(void *)b_h; // input terms
    int n = a->len;

    // Result: for each t, compute h_t = a[0]*a[1]*...*a[t]*h_0 + accumulated b terms
    double *a_acc = (double *)malloc(n * sizeof(double));
    double *b_acc = (double *)malloc(n * sizeof(double));

    a_acc[0] = _sc_i2f(a->data[0]);
    b_acc[0] = _sc_i2f(b->data[0]);
    for (int i = 1; i < n; i++) {
        double ai = _sc_i2f(a->data[i]);
        double bi = _sc_i2f(b->data[i]);
        a_acc[i] = a_acc[i - 1] * ai;
        b_acc[i] = ai * b_acc[i - 1] + bi;
    }

    // Pack result: [a_acc..., b_acc...]
    SCVec *out = scvec_new(2 * n);
    for (int i = 0; i < n; i++) {
        out->data[i] = _sc_f2i(a_acc[i]);
        out->data[n + i] = _sc_f2i(b_acc[i]);
    }
    free(a_acc); free(b_acc);
    return (long long)out;
}

// ================================================================
//  Segmented Prefix Sum (reset at segment boundaries)
//  flags: Vec where 1 = start of new segment
// ================================================================

long long nuc_scan_segmented_sum(long long vh, long long flags_h) {
    SCVec *v = (SCVec *)(void *)vh;
    SCVec *flags = (SCVec *)(void *)flags_h;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running = 0;
    for (int i = 0; i < n; i++) {
        if (flags->data[i]) running = 0;
        running += _sc_i2f(v->data[i]);
        out->data[i] = _sc_f2i(running);
    }
    return (long long)out;
}

// ================================================================
//  Cumulative Softmax (online, for attention-like operations)
//  Returns cumulative log-sum-exp and running softmax values
// ================================================================

long long nuc_scan_cumulative_logsumexp(long long vh) {
    SCVec *v = (SCVec *)(void *)vh;
    int n = v->len;
    SCVec *out = scvec_new(n);
    double running_max = _sc_i2f(v->data[0]);
    double running_sum = 1.0;
    out->data[0] = _sc_f2i(running_max + log(running_sum));

    for (int i = 1; i < n; i++) {
        double x = _sc_i2f(v->data[i]);
        double new_max = running_max > x ? running_max : x;
        running_sum = running_sum * exp(running_max - new_max) + exp(x - new_max);
        running_max = new_max;
        out->data[i] = _sc_f2i(new_max + log(running_sum));
    }
    return (long long)out;
}

// ================================================================
//  SSM Scan: h_t = exp(decay_t) * h_{t-1} + input_t
//  Vectorized over state dimension N.
//  decay: [L, N], input: [L, N] -> output: [L, N]
// ================================================================

long long nuc_scan_ssm(long long decay_h, long long input_h, long long L, long long N) {
    SCVec *decay = (SCVec *)(void *)decay_h;
    SCVec *input = (SCVec *)(void *)input_h;
    int seq = (int)L, state = (int)N;
    SCVec *out = scvec_new(seq * state);

    double *h = (double *)calloc(state, sizeof(double));
    for (int t = 0; t < seq; t++) {
        for (int n = 0; n < state; n++) {
            double d = exp(_sc_i2f(decay->data[t * state + n]));
            double x = _sc_i2f(input->data[t * state + n]);
            h[n] = d * h[n] + x;
            out->data[t * state + n] = _sc_f2i(h[n]);
        }
    }
    free(h);
    return (long long)out;
}
