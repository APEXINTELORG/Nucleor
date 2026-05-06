// transformer_rt.c — Transformer Architecture Building Blocks for Nucleor
// Scaled dot-product attention, multi-head attention, layer norm,
// feedforward, positional encoding, softmax, cross-entropy.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/transformer_rt.c -o target/transformer_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _tr_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _tr_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } TRVec;

static TRVec *trvec_new(int n) {
    TRVec *v = (TRVec *)malloc(sizeof(TRVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  Softmax (in-place on Vec<f64>)
// ================================================================

long long nuc_tf_softmax(long long vh) {
    TRVec *v = (TRVec *)(void *)vh;
    int n = v->len;
    TRVec *out = trvec_new(n);

    double max_val = _tr_i2f(v->data[0]);
    for (int i = 1; i < n; i++) {
        double x = _tr_i2f(v->data[i]);
        if (x > max_val) max_val = x;
    }
    double sum = 0;
    for (int i = 0; i < n; i++) {
        double e = exp(_tr_i2f(v->data[i]) - max_val);
        out->data[i] = _tr_f2i(e);
        sum += e;
    }
    for (int i = 0; i < n; i++) {
        out->data[i] = _tr_f2i(_tr_i2f(out->data[i]) / sum);
    }
    return (long long)out;
}

// ================================================================
//  Layer Normalization
//  x: Vec<f64> [d], gamma: Vec<f64> [d], beta: Vec<f64> [d]
// ================================================================

long long nuc_tf_layer_norm(long long xh, long long gamma_h, long long beta_h) {
    TRVec *x = (TRVec *)(void *)xh;
    TRVec *gamma = (TRVec *)(void *)gamma_h;
    TRVec *beta = (TRVec *)(void *)beta_h;
    int d = x->len;

    double mean = 0, var = 0;
    for (int i = 0; i < d; i++) mean += _tr_i2f(x->data[i]);
    mean /= d;
    for (int i = 0; i < d; i++) {
        double diff = _tr_i2f(x->data[i]) - mean;
        var += diff * diff;
    }
    var /= d;
    double inv_std = 1.0 / sqrt(var + 1e-5);

    TRVec *out = trvec_new(d);
    for (int i = 0; i < d; i++) {
        double norm = (_tr_i2f(x->data[i]) - mean) * inv_std;
        double y = norm * _tr_i2f(gamma->data[i]) + _tr_i2f(beta->data[i]);
        out->data[i] = _tr_f2i(y);
    }
    return (long long)out;
}

// ================================================================
//  Scaled Dot-Product Attention
//  Q: [seq_q, d_k], K: [seq_k, d_k], V: [seq_k, d_v]
//  All stored as flat Vec<f64>
// ================================================================

static long long tf_attention_split_impl(long long Q_h, long long K_h, long long V_h,
                                         long long seq_q, long long seq_k,
                                         long long d_k, long long d_v, int causal) {
    TRVec *Q = (TRVec *)(void *)Q_h;
    TRVec *K = (TRVec *)(void *)K_h;
    TRVec *V = (TRVec *)(void *)V_h;
    int sq = (int)seq_q, sk = (int)seq_k, dk = (int)d_k, dv = (int)d_v;
    double scale = 1.0 / sqrt((double)dk);

    TRVec *out = trvec_new(sq * dv);

    // For each query position
    for (int i = 0; i < sq; i++) {
        // Compute attention scores
        double *scores = (double *)malloc(sk * sizeof(double));
        double max_s = -1e30;
        for (int j = 0; j < sk; j++) {
            if (causal && j > i) {
                scores[j] = -1e30;
                continue;
            }
            double dot = 0;
            for (int k = 0; k < dk; k++)
                dot += _tr_i2f(Q->data[i * dk + k]) * _tr_i2f(K->data[j * dk + k]);
            scores[j] = dot * scale;
            if (scores[j] > max_s) max_s = scores[j];
        }

        // Softmax
        double sum_exp = 0;
        for (int j = 0; j < sk; j++) {
            scores[j] = exp(scores[j] - max_s);
            sum_exp += scores[j];
        }
        for (int j = 0; j < sk; j++) scores[j] /= sum_exp;

        // Weighted sum of values
        for (int k = 0; k < dv; k++) {
            double val = 0;
            for (int j = 0; j < sk; j++)
                val += scores[j] * _tr_i2f(V->data[j * dv + k]);
            out->data[i * dv + k] = _tr_f2i(val);
        }
        free(scores);
    }
    return (long long)out;
}

long long nuc_tf_attention_split(long long Q_h, long long K_h, long long V_h,
                                   long long seq_q, long long seq_k, long long d_k, long long d_v) {
    return tf_attention_split_impl(Q_h, K_h, V_h, seq_q, seq_k, d_k, d_v, 0);
}

long long nuc_tf_attention_split_masked(long long Q_h, long long K_h, long long V_h,
                                          long long seq_q, long long seq_k, long long d_k, long long d_v,
                                          long long causal) {
    return tf_attention_split_impl(Q_h, K_h, V_h, seq_q, seq_k, d_k, d_v, causal != 0);
}

long long nuc_tf_attention_causal(long long Q_h, long long K_h, long long V_h,
                                    long long seq_len, long long d_k) {
    return tf_attention_split_impl(Q_h, K_h, V_h, seq_len, seq_len, d_k, d_k, 1);
}

// ================================================================
//  Multi-Head Attention
//  Splits Q, K, V into n_heads, applies attention, concatenates.
// ================================================================

long long nuc_tf_multihead_split(long long Q_h, long long K_h, long long V_h,
                                   long long seq_q, long long seq_k, long long d_model, long long n_heads) {
    TRVec *Q = (TRVec *)(void *)Q_h;
    TRVec *K = (TRVec *)(void *)K_h;
    TRVec *V = (TRVec *)(void *)V_h;
    int sq = (int)seq_q, sk = (int)seq_k, dm = (int)d_model, nh = (int)n_heads;
    int dk = dm / nh;

    TRVec *out = trvec_new(sq * dm);

    for (int h = 0; h < nh; h++) {
        // Extract head slices
        TRVec *Qh = trvec_new(sq * dk);
        TRVec *Kh = trvec_new(sk * dk);
        TRVec *Vh = trvec_new(sk * dk);

        for (int i = 0; i < sq; i++)
            for (int j = 0; j < dk; j++)
                Qh->data[i * dk + j] = Q->data[i * dm + h * dk + j];
        for (int i = 0; i < sk; i++)
            for (int j = 0; j < dk; j++) {
                Kh->data[i * dk + j] = K->data[i * dm + h * dk + j];
                Vh->data[i * dk + j] = V->data[i * dm + h * dk + j];
            }

        long long attn = nuc_tf_attention_split((long long)Qh, (long long)Kh, (long long)Vh,
                                                  sq, sk, dk, dk);
        TRVec *ah = (TRVec *)(void *)attn;

        // Copy to output
        for (int i = 0; i < sq; i++)
            for (int j = 0; j < dk; j++)
                out->data[i * dm + h * dk + j] = ah->data[i * dk + j];
    }
    return (long long)out;
}

long long nuc_tf_multihead_split_masked(long long Q_h, long long K_h, long long V_h,
                                          long long seq_q, long long seq_k, long long d_model,
                                          long long n_heads, long long causal) {
    TRVec *Q = (TRVec *)(void *)Q_h;
    TRVec *K = (TRVec *)(void *)K_h;
    TRVec *V = (TRVec *)(void *)V_h;
    int sq = (int)seq_q, sk = (int)seq_k, dm = (int)d_model, nh = (int)n_heads;
    int dk = dm / nh;

    TRVec *out = trvec_new(sq * dm);

    for (int h = 0; h < nh; h++) {
        TRVec *Qh = trvec_new(sq * dk);
        TRVec *Kh = trvec_new(sk * dk);
        TRVec *Vh = trvec_new(sk * dk);

        for (int i = 0; i < sq; i++)
            for (int j = 0; j < dk; j++)
                Qh->data[i * dk + j] = Q->data[i * dm + h * dk + j];
        for (int i = 0; i < sk; i++)
            for (int j = 0; j < dk; j++) {
                Kh->data[i * dk + j] = K->data[i * dm + h * dk + j];
                Vh->data[i * dk + j] = V->data[i * dm + h * dk + j];
            }

        long long attn = nuc_tf_attention_split_masked((long long)Qh, (long long)Kh, (long long)Vh,
                                                         sq, sk, dk, dk, causal);
        TRVec *ah = (TRVec *)(void *)attn;

        for (int i = 0; i < sq; i++)
            for (int j = 0; j < dk; j++)
                out->data[i * dm + h * dk + j] = ah->data[i * dk + j];
    }
    return (long long)out;
}

long long nuc_tf_encoder_decoder_block(long long tgt_Q_h, long long tgt_K_h, long long tgt_V_h,
                                         long long mem_K_h, long long mem_V_h,
                                         long long seq_tgt, long long seq_src,
                                         long long d_model, long long n_heads) {
    long long self_h = nuc_tf_multihead_split_masked(
        tgt_Q_h, tgt_K_h, tgt_V_h, seq_tgt, seq_tgt, d_model, n_heads, 1);
    return nuc_tf_multihead_split(
        self_h, mem_K_h, mem_V_h, seq_tgt, seq_src, d_model, n_heads);
}

// 5-arg / 6-arg shims — match the rod's declared arity. Pre-2026-05-05
// the rod declared `(Q, K, V, seq_len, d_k)` but C took 7 args
// (`seq_q, seq_k, d_k, d_v`), reading garbage from un-pushed slots.
// These shims assume self-attention (seq_q == seq_k) and same K/V dim
// (d_k == d_v) — the standard self-attention case. Adopters who need
// cross-attention or asymmetric d_k/d_v call the `_split` form.
long long nuc_tf_attention(long long Q_h, long long K_h, long long V_h,
                             long long seq_len, long long d_k) {
    return nuc_tf_attention_split(Q_h, K_h, V_h, seq_len, seq_len, d_k, d_k);
}

long long nuc_tf_multihead(long long Q_h, long long K_h, long long V_h,
                             long long seq_len, long long d_model, long long n_heads) {
    return nuc_tf_multihead_split(Q_h, K_h, V_h, seq_len, seq_len, d_model, n_heads);
}

// ================================================================
//  Feedforward (2-layer MLP with GELU activation)
//  x: [d], W1: [d_ff, d], b1: [d_ff], W2: [d, d_ff], b2: [d]
// ================================================================

long long nuc_tf_feedforward(long long xh, long long W1_h, long long b1_h,
                              long long W2_h, long long b2_h,
                              long long d_in, long long d_ff) {
    TRVec *x = (TRVec *)(void *)xh;
    TRVec *W1 = (TRVec *)(void *)W1_h, *b1 = (TRVec *)(void *)b1_h;
    TRVec *W2 = (TRVec *)(void *)W2_h, *b2 = (TRVec *)(void *)b2_h;
    int di = (int)d_in, df = (int)d_ff;

    // Hidden = GELU(W1 @ x + b1)
    double *hidden = (double *)malloc(df * sizeof(double));
    for (int i = 0; i < df; i++) {
        double sum = _tr_i2f(b1->data[i]);
        for (int j = 0; j < di; j++)
            sum += _tr_i2f(W1->data[i * di + j]) * _tr_i2f(x->data[j]);
        // GELU approximation
        double gelu = 0.5 * sum * (1.0 + tanh(sqrt(2.0 / M_PI) * (sum + 0.044715 * sum * sum * sum)));
        hidden[i] = gelu;
    }

    // Output = W2 @ hidden + b2
    TRVec *out = trvec_new(di);
    for (int i = 0; i < di; i++) {
        double sum = _tr_i2f(b2->data[i]);
        for (int j = 0; j < df; j++)
            sum += _tr_i2f(W2->data[i * df + j]) * hidden[j];
        out->data[i] = _tr_f2i(sum);
    }
    free(hidden);
    return (long long)out;
}

// ================================================================
//  Positional Encoding (sinusoidal)
//  Returns flat Vec<f64> [seq_len, d_model]
// ================================================================

long long nuc_tf_positional_encoding(long long seq_len, long long d_model) {
    int sl = (int)seq_len, dm = (int)d_model;
    TRVec *pe = trvec_new(sl * dm);
    for (int pos = 0; pos < sl; pos++) {
        for (int i = 0; i < dm; i++) {
            double angle = (double)pos / pow(10000.0, (double)(2 * (i / 2)) / dm);
            double val = (i % 2 == 0) ? sin(angle) : cos(angle);
            pe->data[pos * dm + i] = _tr_f2i(val);
        }
    }
    return (long long)pe;
}

// ================================================================
//  Cross-Entropy Loss
//  pred: Vec<f64> (logits), target: i64 (class index)
// ================================================================

long long nuc_tf_cross_entropy(long long pred_h, long long target) {
    TRVec *pred = (TRVec *)(void *)pred_h;
    int n = pred->len;
    int t = (int)target;

    // Softmax then -log(p[target])
    double max_val = _tr_i2f(pred->data[0]);
    for (int i = 1; i < n; i++) {
        double x = _tr_i2f(pred->data[i]);
        if (x > max_val) max_val = x;
    }
    double sum_exp = 0;
    for (int i = 0; i < n; i++) sum_exp += exp(_tr_i2f(pred->data[i]) - max_val);
    double log_sum = max_val + log(sum_exp);
    double loss = log_sum - _tr_i2f(pred->data[t]);
    return _tr_f2i(loss);
}
