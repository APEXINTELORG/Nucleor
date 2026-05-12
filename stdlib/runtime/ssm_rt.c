// ssm_rt.c — State Space Models for Nucleor
// Mamba selective scan, RWKV WKV operator, xLSTM exponential gating.
// Linear-time sequence modeling as transformer alternative.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/ssm_rt.c -o target/ssm_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ss_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ss_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } SSVec;

static SSVec *ssvec_new(int n) {
    SSVec *v = (SSVec *)malloc(sizeof(SSVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Mamba Selective Scan (S6)
//  Input: x[L,D], delta[L,D], A[D,N], B[L,N], C[L,N]
//  Output: y[L,D]
//  Recurrence: h_t = diag(exp(delta_t * A)) * h_{t-1} + delta_t * B_t * x_t
//              y_t = C_t^T * h_t
//  All stored flat, row-major.
// ================================================================

long long nuc_ssm_selective_scan(long long x_h, long long delta_h,
                                  long long A_h, long long B_h, long long C_h,
                                  long long L, long long D, long long N) {
    SSVec *x = (SSVec *)(void *)x_h;
    SSVec *delta = (SSVec *)(void *)delta_h;
    SSVec *A = (SSVec *)(void *)A_h;
    SSVec *B = (SSVec *)(void *)B_h;
    SSVec *C = (SSVec *)(void *)C_h;
    int seq = (int)L, dim = (int)D, state = (int)N;

    // h: [D, N] hidden state
    double *h = (double *)calloc((size_t)dim * state, sizeof(double));
    SSVec *y = ssvec_new(seq * dim);

    for (int t = 0; t < seq; t++) {
        for (int d = 0; d < dim; d++) {
            double dt = _ss_i2f(delta->data[t * dim + d]);
            double xt = _ss_i2f(x->data[t * dim + d]);

            // Update hidden state: h[d,n] = exp(dt * A[d,n]) * h[d,n] + dt * B[t,n] * xt
            double yt = 0;
            for (int n = 0; n < state; n++) {
                double a = _ss_i2f(A->data[d * state + n]);
                double b = _ss_i2f(B->data[t * state + n]);
                double c = _ss_i2f(C->data[t * state + n]);

                double decay = exp(dt * a);
                h[d * state + n] = decay * h[d * state + n] + dt * b * xt;
                yt += c * h[d * state + n];
            }
            y->data[t * dim + d] = _ss_f2i(yt);
        }
    }
    free(h);
    return (long long)y;
}

// Backward for nuc_ssm_selective_scan.
// Returns Vec handles: [grad_x, grad_delta, grad_A, grad_B, grad_C].
long long nuc_ssm_selective_scan_backward(long long x_h, long long delta_h,
                                           long long A_h, long long B_h, long long C_h,
                                           long long grad_y_h,
                                           long long L, long long D, long long N) {
    SSVec *x = (SSVec *)(void *)x_h;
    SSVec *delta = (SSVec *)(void *)delta_h;
    SSVec *A = (SSVec *)(void *)A_h;
    SSVec *B = (SSVec *)(void *)B_h;
    SSVec *C = (SSVec *)(void *)C_h;
    SSVec *grad_y = (SSVec *)(void *)grad_y_h;
    int seq = (int)L, dim = (int)D, state = (int)N;
    int ds = dim * state;

    double *h_hist = (double *)calloc((size_t)(seq + 1) * ds, sizeof(double));
    for (int t = 0; t < seq; t++) {
        for (int d = 0; d < dim; d++) {
            double dt = _ss_i2f(delta->data[t * dim + d]);
            double xt = _ss_i2f(x->data[t * dim + d]);
            for (int n = 0; n < state; n++) {
                double a = _ss_i2f(A->data[d * state + n]);
                double b = _ss_i2f(B->data[t * state + n]);
                double decay = exp(dt * a);
                double h_prev = h_hist[t * ds + d * state + n];
                h_hist[(t + 1) * ds + d * state + n] = decay * h_prev + dt * b * xt;
            }
        }
    }

    SSVec *grad_x = ssvec_new(seq * dim);
    SSVec *grad_delta = ssvec_new(seq * dim);
    SSVec *grad_A = ssvec_new(dim * state);
    SSVec *grad_B = ssvec_new(seq * state);
    SSVec *grad_C = ssvec_new(seq * state);
    double *gx = (double *)calloc((size_t)seq * dim, sizeof(double));
    double *gd = (double *)calloc((size_t)seq * dim, sizeof(double));
    double *gA = (double *)calloc((size_t)dim * state, sizeof(double));
    double *gB = (double *)calloc((size_t)seq * state, sizeof(double));
    double *gC = (double *)calloc((size_t)seq * state, sizeof(double));
    double *bar_h_next = (double *)calloc(ds, sizeof(double));
    double *bar_h_prev = (double *)calloc(ds, sizeof(double));

    for (int t = seq - 1; t >= 0; t--) {
        memset(bar_h_prev, 0, ds * sizeof(double));
        for (int d = 0; d < dim; d++) {
            double dt = _ss_i2f(delta->data[t * dim + d]);
            double xt = _ss_i2f(x->data[t * dim + d]);
            double gy = _ss_i2f(grad_y->data[t * dim + d]);
            for (int n = 0; n < state; n++) {
                int dn = d * state + n;
                double a = _ss_i2f(A->data[dn]);
                double b = _ss_i2f(B->data[t * state + n]);
                double c = _ss_i2f(C->data[t * state + n]);
                double decay = exp(dt * a);
                double h_prev = h_hist[t * ds + dn];
                double h_t = h_hist[(t + 1) * ds + dn];
                double bar_h = gy * c + bar_h_next[dn];
                double grad_decay = bar_h * h_prev;

                gC[t * state + n] += gy * h_t;
                gd[t * dim + d] += bar_h * b * xt + grad_decay * a * decay;
                gA[dn] += grad_decay * dt * decay;
                gB[t * state + n] += bar_h * dt * xt;
                gx[t * dim + d] += bar_h * dt * b;
                bar_h_prev[dn] += bar_h * decay;
            }
        }
        memcpy(bar_h_next, bar_h_prev, ds * sizeof(double));
    }

    for (int i = 0; i < seq * dim; i++) {
        grad_x->data[i] = _ss_f2i(gx[i]);
        grad_delta->data[i] = _ss_f2i(gd[i]);
    }
    for (int i = 0; i < dim * state; i++) grad_A->data[i] = _ss_f2i(gA[i]);
    for (int i = 0; i < seq * state; i++) {
        grad_B->data[i] = _ss_f2i(gB[i]);
        grad_C->data[i] = _ss_f2i(gC[i]);
    }

    SSVec *result = ssvec_new(5);
    result->data[0] = (long long)grad_x;
    result->data[1] = (long long)grad_delta;
    result->data[2] = (long long)grad_A;
    result->data[3] = (long long)grad_B;
    result->data[4] = (long long)grad_C;

    free(h_hist); free(gx); free(gd); free(gA); free(gB); free(gC);
    free(bar_h_next); free(bar_h_prev);
    return (long long)result;
}

// ================================================================
//  Mamba-2 SSD (Structured State Space Duality)
//  Chunked computation: process chunks of size P, accumulate states.
//  Within chunk: use materialized attention (quadratic but P is small).
//  Between chunks: linear state transfer.
// ================================================================

long long nuc_ssm_ssd_chunked(long long x_h, long long A_h, long long B_h, long long C_h,
                                long long L, long long D, long long N, long long chunk_size) {
    SSVec *x = (SSVec *)(void *)x_h;
    SSVec *A = (SSVec *)(void *)A_h;
    SSVec *B = (SSVec *)(void *)B_h;
    SSVec *C = (SSVec *)(void *)C_h;
    int seq = (int)L, dim = (int)D, state_n = (int)N, P = (int)chunk_size;
    int n_chunks = (seq + P - 1) / P;

    double *h = (double *)calloc((size_t)dim * state_n, sizeof(double));
    SSVec *y = ssvec_new(seq * dim);

    for (int ch = 0; ch < n_chunks; ch++) {
        int t_start = ch * P;
        int t_end = t_start + P;
        if (t_end > seq) t_end = seq;
        int clen = t_end - t_start;

        // Intra-chunk: quadratic attention within chunk
        for (int d = 0; d < dim; d++) {
            // Reset chunk-local state from inter-chunk state
            double *h_local = (double *)calloc(state_n, sizeof(double));
            for (int n = 0; n < state_n; n++) h_local[n] = h[d * state_n + n];

            for (int t = 0; t < clen; t++) {
                int gt = t_start + t;
                double xt = _ss_i2f(x->data[gt * dim + d]);
                double yt = 0;

                for (int n = 0; n < state_n; n++) {
                    double a = _ss_i2f(A->data[d * state_n + n]);
                    double b = _ss_i2f(B->data[gt * state_n + n]);
                    double c = _ss_i2f(C->data[gt * state_n + n]);
                    double decay = exp(a); // unit timestep within chunk
                    h_local[n] = decay * h_local[n] + b * xt;
                    yt += c * h_local[n];
                }
                y->data[gt * dim + d] = _ss_f2i(yt);
            }

            // Update inter-chunk state
            for (int n = 0; n < state_n; n++) h[d * state_n + n] = h_local[n];
            free(h_local);
        }
    }
    free(h);
    return (long long)y;
}

// ================================================================
//  RWKV WKV Operator (v5/v6 matrix-valued state)
//  s_t = diag(w_t) * s_{t-1} + k_t * v_t^T
//  o_t = s_t * r_t (matrix-vector product)
//  w: [L,D] time decay, k: [L,D], v: [L,D], r: [L,D]
//  State s is [D_head, D_head] per head.
// ================================================================

long long nuc_ssm_rwkv_wkv(long long w_h, long long k_h, long long v_h, long long r_h,
                             long long L, long long D_head) {
    SSVec *w = (SSVec *)(void *)w_h;
    SSVec *k = (SSVec *)(void *)k_h;
    SSVec *v = (SSVec *)(void *)v_h;
    SSVec *r = (SSVec *)(void *)r_h;
    int seq = (int)L, dh = (int)D_head;

    // State matrix s: [dh, dh]
    double *s = (double *)calloc((size_t)dh * dh, sizeof(double));
    SSVec *out = ssvec_new(seq * dh);

    for (int t = 0; t < seq; t++) {
        // Decay: s = diag(exp(w_t)) * s
        for (int i = 0; i < dh; i++) {
            double wi = exp(_ss_i2f(w->data[t * dh + i]));
            for (int j = 0; j < dh; j++) s[i * dh + j] *= wi;
        }

        // Rank-1 update: s += k_t * v_t^T
        for (int i = 0; i < dh; i++) {
            double ki = _ss_i2f(k->data[t * dh + i]);
            for (int j = 0; j < dh; j++) {
                s[i * dh + j] += ki * _ss_i2f(v->data[t * dh + j]);
            }
        }

        // Output: o_t = s * r_t
        for (int i = 0; i < dh; i++) {
            double sum = 0;
            for (int j = 0; j < dh; j++)
                sum += s[i * dh + j] * _ss_i2f(r->data[t * dh + j]);
            out->data[t * dh + i] = _ss_f2i(sum);
        }
    }
    free(s);
    return (long long)out;
}

// ================================================================
//  xLSTM Exponential Gating
//  Replaces sigmoid with exp for gates, using log-domain stabilization.
//  f_t = exp(f_gate_t), i_t = exp(i_gate_t)
//  Stabilized via: m_t = max(log(f_t) + m_{t-1}, log(i_t))
//  c_t = f_t/exp(m_t) * c_{t-1} + i_t/exp(m_t) * z_t
// ================================================================

long long nuc_ssm_xlstm_cell(long long x_h, long long Wf_h, long long Wi_h,
                               long long Wz_h, long long Wo_h,
                               long long L, long long D) {
    SSVec *x = (SSVec *)(void *)x_h;
    SSVec *Wf = (SSVec *)(void *)Wf_h; // [D,D] forget gate weights
    SSVec *Wi = (SSVec *)(void *)Wi_h;
    SSVec *Wz = (SSVec *)(void *)Wz_h; // cell input
    SSVec *Wo = (SSVec *)(void *)Wo_h; // output gate
    int seq = (int)L, dim = (int)D;

    double *c = (double *)calloc(dim, sizeof(double)); // cell state
    double *m = (double *)calloc(dim, sizeof(double)); // log normalizer
    SSVec *out = ssvec_new(seq * dim);

    for (int t = 0; t < seq; t++) {
        for (int d = 0; d < dim; d++) {
            // Compute gates via dot product (simplified: diagonal weights)
            double xt = _ss_i2f(x->data[t * dim + d]);
            double log_f = _ss_i2f(Wf->data[d]) * xt; // forget gate (log domain)
            double log_i = _ss_i2f(Wi->data[d]) * xt; // input gate (log domain)
            double z = tanh(_ss_i2f(Wz->data[d]) * xt); // cell input
            double o = 1.0 / (1.0 + exp(-_ss_i2f(Wo->data[d]) * xt)); // output gate (sigmoid)

            // Stabilized exponential gating
            double m_new = log_f + m[d];
            if (log_i > m_new) m_new = log_i;

            double f_stable = exp(log_f + m[d] - m_new);
            double i_stable = exp(log_i - m_new);

            c[d] = f_stable * c[d] + i_stable * z;
            m[d] = m_new;

            out->data[t * dim + d] = _ss_f2i(o * c[d]);
        }
    }
    free(c); free(m);
    return (long long)out;
}

// ================================================================
//  Discretize continuous SSM: A_bar = exp(delta * A), B_bar = (A_bar - I) * A^{-1} * B
//  For diagonal A (common case): A_bar[i] = exp(delta * A[i])
// ================================================================

long long nuc_ssm_discretize_zoh(long long A_h, long long B_h, long long delta_bits, long long N) {
    SSVec *A = (SSVec *)(void *)A_h;
    SSVec *B = (SSVec *)(void *)B_h;
    double dt = _ss_i2f(delta_bits);
    int n = (int)N;

    SSVec *Ab = ssvec_new(n); // discretized A (diagonal)
    SSVec *Bb = ssvec_new(n); // discretized B

    for (int i = 0; i < n; i++) {
        double a = _ss_i2f(A->data[i]);
        double b = _ss_i2f(B->data[i]);
        double ea = exp(dt * a);
        Ab->data[i] = _ss_f2i(ea);
        // B_bar = (exp(dt*A) - 1) / A * B (for diagonal A)
        double bb = (fabs(a) > 1e-10) ? (ea - 1.0) / a * b : dt * b;
        Bb->data[i] = _ss_f2i(bb);
    }

    // Pack both into single result: [Ab..., Bb...]
    SSVec *result = ssvec_new(2 * n);
    for (int i = 0; i < n; i++) {
        result->data[i] = Ab->data[i];
        result->data[n + i] = Bb->data[i];
    }
    return (long long)result;
}
