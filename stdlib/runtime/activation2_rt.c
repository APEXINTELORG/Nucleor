// activation2_rt.c — Modern Activations, Norms, and Embeddings for Nucleor
// SwiGLU, GELU, RMSNorm, RoPE, DyT, JumpReLU, QK-Norm, DeepNorm, SiLU.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/activation2_rt.c -o target/activation2_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ac_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ac_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } ACVec;

static ACVec *acvec_new(int n) {
    ACVec *v = (ACVec *)malloc(sizeof(ACVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  GELU: x * 0.5 * (1 + erf(x / sqrt(2)))
// ================================================================

long long nuc_act_gelu(long long vh) {
    ACVec *v = (ACVec *)(void *)vh;
    ACVec *out = acvec_new(v->len);
    for (int i = 0; i < v->len; i++) {
        double x = _ac_i2f(v->data[i]);
        out->data[i] = _ac_f2i(0.5 * x * (1.0 + erf(x / sqrt(2.0))));
    }
    return (long long)out;
}

// ================================================================
//  SiLU (Swish): x * sigmoid(x)
// ================================================================

long long nuc_act_silu(long long vh) {
    ACVec *v = (ACVec *)(void *)vh;
    ACVec *out = acvec_new(v->len);
    for (int i = 0; i < v->len; i++) {
        double x = _ac_i2f(v->data[i]);
        out->data[i] = _ac_f2i(x / (1.0 + exp(-x)));
    }
    return (long long)out;
}

// ================================================================
//  SwiGLU: silu(xW1) * (xW2) — gated linear unit with swish
//  gate and value are pre-computed as separate Vec inputs
// ================================================================

long long nuc_act_swiglu(long long gate_h, long long value_h) {
    ACVec *gate = (ACVec *)(void *)gate_h;
    ACVec *value = (ACVec *)(void *)value_h;
    int n = gate->len < value->len ? gate->len : value->len;
    ACVec *out = acvec_new(n);
    for (int i = 0; i < n; i++) {
        double g = _ac_i2f(gate->data[i]);
        double v = _ac_i2f(value->data[i]);
        double silu = g / (1.0 + exp(-g));
        out->data[i] = _ac_f2i(silu * v);
    }
    return (long long)out;
}

// ================================================================
//  GeGLU: gelu(xW1) * (xW2)
// ================================================================

long long nuc_act_geglu(long long gate_h, long long value_h) {
    ACVec *gate = (ACVec *)(void *)gate_h;
    ACVec *value = (ACVec *)(void *)value_h;
    int n = gate->len < value->len ? gate->len : value->len;
    ACVec *out = acvec_new(n);
    for (int i = 0; i < n; i++) {
        double g = _ac_i2f(gate->data[i]);
        double v = _ac_i2f(value->data[i]);
        double gelu = 0.5 * g * (1.0 + erf(g / sqrt(2.0)));
        out->data[i] = _ac_f2i(gelu * v);
    }
    return (long long)out;
}

// ================================================================
//  JumpReLU: x * H(x - theta), theta is learned threshold
// ================================================================

long long nuc_act_jumprelu(long long vh, long long theta_bits) {
    ACVec *v = (ACVec *)(void *)vh;
    double theta = _ac_i2f(theta_bits);
    ACVec *out = acvec_new(v->len);
    for (int i = 0; i < v->len; i++) {
        double x = _ac_i2f(v->data[i]);
        out->data[i] = _ac_f2i(x > theta ? x : 0.0);
    }
    return (long long)out;
}

// ================================================================
//  Dynamic Tanh (DyT): tanh(alpha * x) — replaces LayerNorm entirely
//  alpha is a learned scalar per layer
// ================================================================

long long nuc_act_dyt(long long vh, long long alpha_bits) {
    ACVec *v = (ACVec *)(void *)vh;
    double alpha = _ac_i2f(alpha_bits);
    ACVec *out = acvec_new(v->len);
    for (int i = 0; i < v->len; i++) {
        out->data[i] = _ac_f2i(tanh(alpha * _ac_i2f(v->data[i])));
    }
    return (long long)out;
}

// ================================================================
//  RMSNorm: x / RMS(x) * gamma
//  RMS(x) = sqrt(mean(x^2) + eps)
// ================================================================

long long nuc_norm_rms(long long vh, long long gamma_h) {
    ACVec *v = (ACVec *)(void *)vh;
    ACVec *gamma = (ACVec *)(void *)gamma_h;
    int n = v->len;
    double eps = 1e-6;

    double sum_sq = 0;
    for (int i = 0; i < n; i++) { double x = _ac_i2f(v->data[i]); sum_sq += x * x; }
    double rms = sqrt(sum_sq / n + eps);
    double inv_rms = 1.0 / rms;

    ACVec *out = acvec_new(n);
    for (int i = 0; i < n; i++) {
        double x = _ac_i2f(v->data[i]) * inv_rms;
        double g = (gamma && i < gamma->len) ? _ac_i2f(gamma->data[i]) : 1.0;
        out->data[i] = _ac_f2i(x * g);
    }
    return (long long)out;
}

// ================================================================
//  QK-Norm: RMSNorm applied to Q and K vectors per head
// ================================================================

long long nuc_norm_qk(long long qk_h, long long head_dim) {
    ACVec *qk = (ACVec *)(void *)qk_h;
    int hd = (int)head_dim;
    int n_heads = qk->len / hd;
    ACVec *out = acvec_new(qk->len);

    for (int h = 0; h < n_heads; h++) {
        double sum_sq = 0;
        for (int i = 0; i < hd; i++) {
            double x = _ac_i2f(qk->data[h * hd + i]);
            sum_sq += x * x;
        }
        double inv_rms = 1.0 / sqrt(sum_sq / hd + 1e-6);
        for (int i = 0; i < hd; i++)
            out->data[h * hd + i] = _ac_f2i(_ac_i2f(qk->data[h * hd + i]) * inv_rms);
    }
    return (long long)out;
}

// ================================================================
//  Rotary Position Embedding (RoPE)
//  Applies complex rotation to pairs of dimensions.
//  x[2i], x[2i+1] are rotated by angle = pos * theta_i
//  theta_i = 10000^(-2i/d)
// ================================================================

long long nuc_rope_apply(long long vh, long long pos, long long head_dim) {
    ACVec *v = (ACVec *)(void *)vh;
    int hd = (int)head_dim;
    int n_heads = v->len / hd;
    ACVec *out = acvec_new(v->len);

    for (int h = 0; h < n_heads; h++) {
        for (int i = 0; i < hd / 2; i++) {
            double theta = (double)pos * pow(10000.0, -2.0 * i / hd);
            double cos_t = cos(theta), sin_t = sin(theta);
            int idx0 = h * hd + 2 * i;
            int idx1 = idx0 + 1;
            double x0 = _ac_i2f(v->data[idx0]);
            double x1 = _ac_i2f(v->data[idx1]);
            out->data[idx0] = _ac_f2i(x0 * cos_t - x1 * sin_t);
            out->data[idx1] = _ac_f2i(x0 * sin_t + x1 * cos_t);
        }
    }
    return (long long)out;
}

// Batch RoPE: apply to entire sequence at once
long long nuc_rope_apply_seq(long long vh, long long seq_len, long long head_dim, long long n_heads) {
    ACVec *v = (ACVec *)(void *)vh; // [seq, n_heads * head_dim]
    int sl = (int)seq_len, hd = (int)head_dim, nh = (int)n_heads;
    int stride = nh * hd;
    ACVec *out = acvec_new(sl * stride);

    for (int t = 0; t < sl; t++) {
        for (int h = 0; h < nh; h++) {
            for (int i = 0; i < hd / 2; i++) {
                double theta = (double)t * pow(10000.0, -2.0 * i / hd);
                double cos_t = cos(theta), sin_t = sin(theta);
                int base = t * stride + h * hd;
                double x0 = _ac_i2f(v->data[base + 2 * i]);
                double x1 = _ac_i2f(v->data[base + 2 * i + 1]);
                out->data[base + 2 * i] = _ac_f2i(x0 * cos_t - x1 * sin_t);
                out->data[base + 2 * i + 1] = _ac_f2i(x0 * sin_t + x1 * cos_t);
            }
        }
    }
    return (long long)out;
}

// ================================================================
//  DeepNorm: residual scaling for very deep transformers
//  output = x * alpha + sublayer(x)
// ================================================================

long long nuc_norm_deep(long long x_h, long long sublayer_h, long long alpha_bits) {
    ACVec *x = (ACVec *)(void *)x_h;
    ACVec *sub = (ACVec *)(void *)sublayer_h;
    double alpha = _ac_i2f(alpha_bits);
    int n = x->len < sub->len ? x->len : sub->len;
    ACVec *out = acvec_new(n);
    for (int i = 0; i < n; i++)
        out->data[i] = _ac_f2i(alpha * _ac_i2f(x->data[i]) + _ac_i2f(sub->data[i]));
    return (long long)out;
}

// ================================================================
//  Softmax (numerically stable, operates on Vec)
// ================================================================

long long nuc_act_softmax(long long vh) {
    ACVec *v = (ACVec *)(void *)vh;
    int n = v->len;
    ACVec *out = acvec_new(n);
    double max_val = _ac_i2f(v->data[0]);
    for (int i = 1; i < n; i++) { double x = _ac_i2f(v->data[i]); if (x > max_val) max_val = x; }
    double sum = 0;
    for (int i = 0; i < n; i++) { double e = exp(_ac_i2f(v->data[i]) - max_val); out->data[i] = _ac_f2i(e); sum += e; }
    for (int i = 0; i < n; i++) out->data[i] = _ac_f2i(_ac_i2f(out->data[i]) / sum);
    return (long long)out;
}

// ================================================================
//  Sigmoid
// ================================================================

long long nuc_act_sigmoid(long long vh) {
    ACVec *v = (ACVec *)(void *)vh;
    ACVec *out = acvec_new(v->len);
    for (int i = 0; i < v->len; i++) {
        double x = _ac_i2f(v->data[i]);
        out->data[i] = _ac_f2i(1.0 / (1.0 + exp(-x)));
    }
    return (long long)out;
}
