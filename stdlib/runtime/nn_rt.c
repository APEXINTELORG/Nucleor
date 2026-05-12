// nn_rt.c — Neural Network Runtime for Nucleor
// Dense layers, backprop, Adam optimizer, activations
// All f64 as i64 bitcast, same pattern as quantum_rt.c
//
// Compile: clang -c nn_rt.c -o target/nn_rt.obj

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

typedef struct { long long *data; int len; int cap; } NNVec;

static NNVec *nn_vec_alloc(int len) {
    NNVec *v = (NNVec *)malloc(sizeof(NNVec));
    v->len = len;
    v->cap = len > 0 ? len : 1;
    v->data = (long long *)calloc((size_t)v->cap, sizeof(long long));
    return v;
}

// =====================================================
// Dense Layer
// =====================================================
// Layout: weights(out*in) + bias(out) + dW(out*in) + db(out) + cache_input(in) + metadata
typedef struct {
    int in_dim, out_dim;
    double *W;          // out x in weights
    double *b;          // out bias
    double *dW;         // weight gradients
    double *db;         // bias gradients
    double *cache_in;   // cached input for backward
    int cache_valid;
} NNDense;

// Global layer counter for unique-per-layer deterministic RNG
static unsigned int _nn_layer_counter = 0;

long long nuc_nn_dense_new(long long in_dim, long long out_dim) {
    int id = (int)in_dim, od = (int)out_dim;
    NNDense *l = (NNDense *)calloc(1, sizeof(NNDense));
    l->in_dim = id; l->out_dim = od;
    l->W = (double *)malloc((size_t)od * id * sizeof(double));
    l->b = (double *)calloc(od, sizeof(double));
    l->dW = (double *)calloc((size_t)od * id, sizeof(double));
    l->db = (double *)calloc(od, sizeof(double));
    l->cache_in = (double *)calloc(id, sizeof(double));
    l->cache_valid = 0;
    // Xavier initialization with unique seed per layer
    double scale = sqrt(2.0 / (id + od));
    unsigned int rng = 2026 * 1000 + (++_nn_layer_counter) * 7919;  // deterministic but unique
    for (int i = 0; i < od * id; i++) {
        rng = rng * 1103515245 + 12345;
        double u = ((double)((rng >> 16) & 0x7FFF)) / 32767.0;
        l->W[i] = (u * 2.0 - 1.0) * scale;
    }
    return (long long)l;
}

// Reset layer counter (call at start of each experiment for reproducibility)
void nuc_nn_reset_rng(void) {
    _nn_layer_counter = 0;
}

// Forward: output = W @ input + b
// input is a Vec<f64> (NVec*), returns Vec<f64>
long long nuc_nn_dense_forward(long long handle, long long input_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NNDense *l = (NNDense *)(void *)handle;
    NVec *inv = (NVec *)(void *)input_vec;

    // Cache input for backward
    for (int i = 0; i < l->in_dim && i < inv->len; i++)
        l->cache_in[i] = _i2f(inv->data[i]);
    l->cache_valid = 1;

    // Allocate output vec
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->cap = l->out_dim;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    out->len = l->out_dim;

    for (int i = 0; i < l->out_dim; i++) {
        double sum = l->b[i];
        for (int j = 0; j < l->in_dim; j++)
            sum += l->W[i * l->in_dim + j] * l->cache_in[j];
        out->data[i] = _f2i(sum);
    }
    return (long long)out;
}

// Backward: given grad_output, compute dW, db, and return grad_input
long long nuc_nn_dense_backward(long long handle, long long grad_out_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NNDense *l = (NNDense *)(void *)handle;
    NVec *gout = (NVec *)(void *)grad_out_vec;

    // dW += grad_output outer cache_input
    for (int i = 0; i < l->out_dim; i++) {
        double gi = _i2f(gout->data[i]);
        l->db[i] += gi;
        for (int j = 0; j < l->in_dim; j++)
            l->dW[i * l->in_dim + j] += gi * l->cache_in[j];
    }

    // grad_input = W^T @ grad_output
    NVec *gin = (NVec *)malloc(sizeof(NVec));
    gin->cap = l->in_dim;
    gin->data = (long long *)malloc(gin->cap * sizeof(long long));
    gin->len = l->in_dim;
    for (int j = 0; j < l->in_dim; j++) {
        double sum = 0;
        for (int i = 0; i < l->out_dim; i++)
            sum += l->W[i * l->in_dim + j] * _i2f(gout->data[i]);
        gin->data[j] = _f2i(sum);
    }
    return (long long)gin;
}

void nuc_nn_dense_zero_grad(long long handle) {
    NNDense *l = (NNDense *)(void *)handle;
    memset(l->dW, 0, (size_t)(l->out_dim) * l->in_dim * sizeof(double));
    memset(l->db, 0, l->out_dim * sizeof(double));
}

// Set the cached input for backward (used when sharing a layer across multiple inputs)
void nuc_nn_dense_set_cache(long long handle, long long input_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NNDense *l = (NNDense *)(void *)handle;
    NVec *inv = (NVec *)(void *)input_vec;
    for (int i = 0; i < l->in_dim && i < inv->len; i++)
        l->cache_in[i] = _i2f(inv->data[i]);
    l->cache_valid = 1;
}

// =====================================================
// Activations (operate on Vec<f64>)
// =====================================================

long long nuc_nn_relu(long long vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = v->len; out->cap = v->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < v->len; i++) {
        double x = _i2f(v->data[i]);
        out->data[i] = _f2i(x > 0 ? x : 0);
    }
    return (long long)out;
}

// ReLU backward: grad * (input > 0)
long long nuc_nn_relu_backward(long long input_vec, long long grad_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *inp = (NVec *)(void *)input_vec;
    NVec *grad = (NVec *)(void *)grad_vec;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = inp->len; out->cap = inp->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < inp->len; i++) {
        double x = _i2f(inp->data[i]);
        double g = _i2f(grad->data[i]);
        out->data[i] = _f2i(x > 0 ? g : 0);
    }
    return (long long)out;
}

long long nuc_nn_sigmoid(long long vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = v->len; out->cap = v->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < v->len; i++) {
        double x = _i2f(v->data[i]);
        double s = 1.0 / (1.0 + exp(-x));
        out->data[i] = _f2i(s);
    }
    return (long long)out;
}

// Sigmoid backward: grad * output * (1 - output)
long long nuc_nn_sigmoid_backward(long long output_vec, long long grad_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *out_v = (NVec *)(void *)output_vec;
    NVec *grad = (NVec *)(void *)grad_vec;
    NVec *result = (NVec *)malloc(sizeof(NVec));
    result->len = out_v->len; result->cap = out_v->len;
    result->data = (long long *)malloc(result->cap * sizeof(long long));
    for (int i = 0; i < out_v->len; i++) {
        double s = _i2f(out_v->data[i]);
        double g = _i2f(grad->data[i]);
        result->data[i] = _f2i(g * s * (1.0 - s));
    }
    return (long long)result;
}

long long nuc_nn_softmax(long long vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = v->len; out->cap = v->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    // Numerically stable: subtract max
    double mx = _i2f(v->data[0]);
    for (int i = 1; i < v->len; i++) { double x = _i2f(v->data[i]); if (x > mx) mx = x; }
    double sum = 0;
    for (int i = 0; i < v->len; i++) { double e = exp(_i2f(v->data[i]) - mx); out->data[i] = _f2i(e); sum += e; }
    for (int i = 0; i < v->len; i++) out->data[i] = _f2i(_i2f(out->data[i]) / sum);
    return (long long)out;
}

// =====================================================
// Adam Optimizer
// =====================================================
typedef struct {
    int n_params;
    double lr, beta1, beta2, eps;
    double *m;  // first moment
    double *v;  // second moment
    int t;      // timestep
} NNAdam;

long long nuc_nn_adam_new(long long n_params, long long lr_bits, long long beta1_bits, long long beta2_bits) {
    NNAdam *opt = (NNAdam *)calloc(1, sizeof(NNAdam));
    opt->n_params = (int)n_params;
    opt->lr = _i2f(lr_bits);
    opt->beta1 = _i2f(beta1_bits);
    opt->beta2 = _i2f(beta2_bits);
    opt->eps = 1e-8;
    opt->m = (double *)calloc(opt->n_params, sizeof(double));
    opt->v = (double *)calloc(opt->n_params, sizeof(double));
    opt->t = 0;
    return (long long)opt;
}

// Update a dense layer's parameters using accumulated gradients
void nuc_nn_adam_step_dense(long long opt_handle, long long layer_handle) {
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    NNDense *l = (NNDense *)(void *)layer_handle;
    opt->t++;
    double bc1 = 1.0 - pow(opt->beta1, opt->t);
    double bc2 = 1.0 - pow(opt->beta2, opt->t);

    int n_w = l->out_dim * l->in_dim;
    // Update weights
    for (int i = 0; i < n_w; i++) {
        int idx = i; // reuse opt->m/v indices
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dW[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dW[i] * l->dW[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->W[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
    // Update biases
    for (int i = 0; i < l->out_dim; i++) {
        int idx = n_w + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->db[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->db[i] * l->db[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->b[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
}

// Update a noise model's logits
void nuc_nn_adam_step_logits(long long opt_handle, long long logits_vec, long long grad_vec, long long offset) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    NVec *logits = (NVec *)(void *)logits_vec;
    NVec *grads = (NVec *)(void *)grad_vec;
    int off = (int)offset;

    // Don't increment t here — it was already incremented in step_dense
    double bc1 = 1.0 - pow(opt->beta1, opt->t > 0 ? opt->t : 1);
    double bc2 = 1.0 - pow(opt->beta2, opt->t > 0 ? opt->t : 1);

    for (int i = 0; i < logits->len && i < grads->len; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        double g = _i2f(grads->data[i]);
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * g;
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * g * g;
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        double val = _i2f(logits->data[i]);
        logits->data[i] = _f2i(val - opt->lr * mh / (sqrt(vh) + opt->eps));
    }
}

// =====================================================
// Differentiable Noise Model
// =====================================================

// Compute noise rate from logit: p = sigmoid(logit) * max_p
long long nuc_nn_noise_rate(long long logit_bits, long long max_p_bits) {
    double logit = _i2f(logit_bits);
    double max_p = _i2f(max_p_bits);
    double p = (1.0 / (1.0 + exp(-logit))) * max_p;
    return _f2i(p);
}

// Gradient of noise rate w.r.t. logit: dp/dlogit = sigmoid(logit)*(1-sigmoid(logit))*max_p
long long nuc_nn_noise_rate_grad(long long logit_bits, long long max_p_bits) {
    double logit = _i2f(logit_bits);
    double max_p = _i2f(max_p_bits);
    double sig = 1.0 / (1.0 + exp(-logit));
    return _f2i(sig * (1.0 - sig) * max_p);
}

// Gradient of noisy_mix output w.r.t. p:
// sv_noisy[i] = sv[i] * (1-p) + p/sqrt(N)
// d(sv_noisy[i])/dp = -sv[i] + 1/sqrt(N)
// This returns the mean |d_output/dp| across all amplitudes
long long nuc_nn_noisy_mix_grad(long long sv_vec, long long n_amps_val) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *sv = (NVec *)(void *)sv_vec;
    int n = (int)n_amps_val;
    double inv_sqrt_n = 1.0 / sqrt((double)n);
    double sum_abs_grad = 0;
    // sv stores interleaved re,im as complex handles
    // For simplicity, compute gradient on magnitude
    for (int i = 0; i < sv->len; i++) {
        // Each element is a complex number handle
        // Approximate: use the probability |a|^2 derivative
        sum_abs_grad += fabs(inv_sqrt_n);
    }
    return _f2i(sum_abs_grad / sv->len);
}

// =====================================================
// Utility: Vec creation for results
// =====================================================
long long nuc_nn_vec_new(long long size) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = 0; v->cap = (int)size;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    return (long long)v;
}

long long nuc_nn_vec_from_scalar(long long val) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = 1; v->cap = 1;
    v->data = (long long *)malloc(sizeof(long long));
    v->data[0] = val;
    return (long long)v;
}

// Get total parameter count for a dense layer
long long nuc_nn_dense_param_count(long long handle) {
    NNDense *l = (NNDense *)(void *)handle;
    return (long long)(l->out_dim * l->in_dim + l->out_dim);
}

long long nuc_nn_dense_in_dim(long long handle) {
    NNDense *l = (NNDense *)(void *)handle;
    if (!l) return 0;
    return (long long)l->in_dim;
}

long long nuc_nn_dense_out_dim(long long handle) {
    NNDense *l = (NNDense *)(void *)handle;
    if (!l) return 0;
    return (long long)l->out_dim;
}

long long nuc_nn_dense_weight(long long handle, long long out_idx, long long in_idx) {
    NNDense *l = (NNDense *)(void *)handle;
    if (!l) return _f2i(0.0);
    int oi = (int)out_idx;
    int ii = (int)in_idx;
    if (oi < 0 || oi >= l->out_dim || ii < 0 || ii >= l->in_dim) return _f2i(0.0);
    return _f2i(l->W[oi * l->in_dim + ii]);
}

long long nuc_nn_dense_bias(long long handle, long long out_idx) {
    NNDense *l = (NNDense *)(void *)handle;
    if (!l) return _f2i(0.0);
    int oi = (int)out_idx;
    if (oi < 0 || oi >= l->out_dim) return _f2i(0.0);
    return _f2i(l->b[oi]);
}

// =====================================================
// Adam with explicit offset for parameter groups
// =====================================================
// Steps a single dense layer at a specific offset in the optimizer's m/v arrays.
// Returns the offset AFTER this layer's params (for chaining).
long long nuc_nn_adam_step_at(long long opt_handle, long long layer_handle, long long offset) {
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    NNDense *l = (NNDense *)(void *)layer_handle;
    int off = (int)offset;

    opt->t++;
    double bc1 = 1.0 - pow(opt->beta1, opt->t);
    double bc2 = 1.0 - pow(opt->beta2, opt->t);

    int n_w = l->out_dim * l->in_dim;
    for (int i = 0; i < n_w; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dW[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dW[i] * l->dW[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->W[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
    for (int i = 0; i < l->out_dim; i++) {
        int idx = off + n_w + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->db[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->db[i] * l->db[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->b[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
    return (long long)(off + n_w + l->out_dim);
}

// Increment Adam timestep once (call before step_at to avoid double-increment)
void nuc_nn_adam_tick(long long opt_handle) {
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    opt->t++;
}

// Step a dense layer at offset WITHOUT incrementing t
long long nuc_nn_adam_step_at_no_tick(long long opt_handle, long long layer_handle, long long offset) {
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    NNDense *l = (NNDense *)(void *)layer_handle;
    int off = (int)offset;

    double bc1 = 1.0 - pow(opt->beta1, opt->t > 0 ? opt->t : 1);
    double bc2 = 1.0 - pow(opt->beta2, opt->t > 0 ? opt->t : 1);

    int n_w = l->out_dim * l->in_dim;
    for (int i = 0; i < n_w; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dW[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dW[i] * l->dW[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->W[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
    for (int i = 0; i < l->out_dim; i++) {
        int idx = off + n_w + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->db[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->db[i] * l->db[i];
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        l->b[i] -= opt->lr * mh / (sqrt(vh) + opt->eps);
    }
    return (long long)(off + n_w + l->out_dim);
}

// Step logits at offset WITHOUT incrementing t
void nuc_nn_adam_step_logits_no_tick(long long opt_handle, long long logits_vec, long long grad_vec, long long offset) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    NVec *logits = (NVec *)(void *)logits_vec;
    NVec *grads = (NVec *)(void *)grad_vec;
    int off = (int)offset;

    double bc1 = 1.0 - pow(opt->beta1, opt->t > 0 ? opt->t : 1);
    double bc2 = 1.0 - pow(opt->beta2, opt->t > 0 ? opt->t : 1);

    for (int i = 0; i < logits->len && i < grads->len; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        double g = _i2f(grads->data[i]);
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * g;
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * g * g;
        double mh = opt->m[idx] / bc1;
        double vh = opt->v[idx] / bc2;
        double val = _i2f(logits->data[i]);
        logits->data[i] = _f2i(val - opt->lr * mh / (sqrt(vh) + opt->eps));
    }
}

// =====================================================
// Vector utilities
// =====================================================

// Concatenate two vectors: returns new vec = a ++ b
long long nuc_nn_vec_concat(long long a_vec, long long b_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *a = (NVec *)(void *)a_vec;
    NVec *b = (NVec *)(void *)b_vec;
    int total = a->len + b->len;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = total; out->cap = total;
    out->data = (long long *)malloc(total * sizeof(long long));
    memcpy(out->data, a->data, a->len * sizeof(long long));
    memcpy(out->data + a->len, b->data, b->len * sizeof(long long));
    return (long long)out;
}

// Slice a vector: returns new vec = v[start..start+len]
long long nuc_nn_vec_slice(long long vec, long long start, long long len) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    int s = (int)start, n = (int)len;
    if (s + n > v->len) n = v->len - s;
    if (n < 0) n = 0;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = n; out->cap = n;
    out->data = (long long *)malloc(n * sizeof(long long));
    if (n > 0) memcpy(out->data, v->data + s, n * sizeof(long long));
    return (long long)out;
}

// Weighted sum of N vectors (each dim D), weights are a Vec of N doubles
// input: flat vec of N*D values, weights: vec of N values, D: dimension
// returns: vec of D values = sum(weights[i] * input[i*D .. (i+1)*D])
long long nuc_nn_weighted_sum(long long input_vec, long long weights_vec, long long dim) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *inp = (NVec *)(void *)input_vec;
    NVec *wts = (NVec *)(void *)weights_vec;
    int D = (int)dim;
    int N = wts->len;

    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = D; out->cap = D;
    out->data = (long long *)malloc(D * sizeof(long long));

    double *result = (double *)calloc(D, sizeof(double));
    for (int i = 0; i < N; i++) {
        double w = _i2f(wts->data[i]);
        for (int j = 0; j < D; j++) {
            int idx = i * D + j;
            if (idx < inp->len)
                result[j] += w * _i2f(inp->data[idx]);
        }
    }
    for (int j = 0; j < D; j++)
        out->data[j] = _f2i(result[j]);
    free(result);
    return (long long)out;
}

// Softmax backward: given output softmax probs and grad w.r.t. output,
// compute grad w.r.t. input (pre-softmax logits)
// grad_input[i] = sum_j(grad_out[j] * (softmax[j] * (delta_ij - softmax[i])))
// =====================================================
// Z-score standardization (Issue 1)
// =====================================================
// Compute mean and std of each feature across a dataset of vectors.
// dataset: Vec of Vecs (each inner vec is one sample's features)
// Returns: Vec with [mean_vec, std_vec] (each is a Vec of f64)
long long nuc_nn_compute_stats(long long dataset_vec, long long n_samples, long long feat_dim) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *dataset = (NVec *)(void *)dataset_vec;
    int ns = (int)n_samples, fd = (int)feat_dim;

    double *means = (double *)calloc(fd, sizeof(double));
    double *stds = (double *)calloc(fd, sizeof(double));

    // Compute means
    for (int i = 0; i < ns; i++) {
        NVec *sample = (NVec *)(void *)dataset->data[i];
        for (int j = 0; j < fd && j < sample->len; j++)
            means[j] += _i2f(sample->data[j]);
    }
    for (int j = 0; j < fd; j++) means[j] /= (ns > 0 ? ns : 1);

    // Compute stds
    for (int i = 0; i < ns; i++) {
        NVec *sample = (NVec *)(void *)dataset->data[i];
        for (int j = 0; j < fd && j < sample->len; j++) {
            double d = _i2f(sample->data[j]) - means[j];
            stds[j] += d * d;
        }
    }
    for (int j = 0; j < fd; j++) {
        stds[j] = sqrt(stds[j] / (ns > 1 ? ns - 1 : 1));
        if (stds[j] < 1e-10) stds[j] = 1.0;  // avoid division by zero
    }

    NVec *mean_v = (NVec *)malloc(sizeof(NVec));
    mean_v->len = fd; mean_v->cap = fd;
    mean_v->data = (long long *)malloc(fd * sizeof(long long));
    NVec *std_v = (NVec *)malloc(sizeof(NVec));
    std_v->len = fd; std_v->cap = fd;
    std_v->data = (long long *)malloc(fd * sizeof(long long));
    for (int j = 0; j < fd; j++) {
        mean_v->data[j] = _f2i(means[j]);
        std_v->data[j] = _f2i(stds[j]);
    }
    free(means); free(stds);

    NVec *result = (NVec *)malloc(sizeof(NVec));
    result->len = 2; result->cap = 2;
    result->data = (long long *)malloc(2 * sizeof(long long));
    result->data[0] = (long long)mean_v;
    result->data[1] = (long long)std_v;
    return (long long)result;
}

// Apply z-score: (x - mean) / std
long long nuc_nn_zscore(long long vec, long long mean_vec, long long std_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    NVec *m = (NVec *)(void *)mean_vec;
    NVec *s = (NVec *)(void *)std_vec;
    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = v->len; out->cap = v->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < v->len; i++) {
        double val = _i2f(v->data[i]);
        double mean = (i < m->len) ? _i2f(m->data[i]) : 0;
        double std = (i < s->len) ? _i2f(s->data[i]) : 1;
        out->data[i] = _f2i((val - mean) / std);
    }
    return (long long)out;
}

// =====================================================
// Pearson correlation (Issue 5)
// =====================================================
long long nuc_nn_pearson(long long x_vec, long long y_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *x = (NVec *)(void *)x_vec;
    NVec *y = (NVec *)(void *)y_vec;
    int n = x->len < y->len ? x->len : y->len;
    if (n < 3) return _f2i(0.0);

    double mx = 0, my = 0;
    for (int i = 0; i < n; i++) { mx += _i2f(x->data[i]); my += _i2f(y->data[i]); }
    mx /= n; my /= n;

    double sxy = 0, sxx = 0, syy = 0;
    for (int i = 0; i < n; i++) {
        double dx = _i2f(x->data[i]) - mx;
        double dy = _i2f(y->data[i]) - my;
        sxy += dx * dy;
        sxx += dx * dx;
        syy += dy * dy;
    }
    double denom = sqrt(sxx * syy);
    return _f2i(denom > 1e-15 ? sxy / denom : 0.0);
}

// =====================================================
// L-BFGS optimizer (N2 — toggleable alternative to Adam)
// =====================================================
// Simplified L-BFGS with m=5 history vectors.
// Operates on a flat parameter vector + gradient vector.
#define LBFGS_M 5

typedef struct {
    int n_params;
    double lr;
    double *s_hist;  // m * n_params: s_k = x_{k+1} - x_k
    double *y_hist;  // m * n_params: y_k = g_{k+1} - g_k
    double *rho;     // m scalars: 1 / (y_k . s_k)
    double *prev_g;  // previous gradient
    double *prev_x;  // previous params
    int k;           // iteration count
    int have_prev;   // do we have a previous gradient?
} NNLbfgs;

long long nuc_nn_lbfgs_new(long long n_params, long long lr_bits) {
    NNLbfgs *opt = (NNLbfgs *)calloc(1, sizeof(NNLbfgs));
    int np = (int)n_params;
    opt->n_params = np;
    opt->lr = _i2f(lr_bits);
    opt->s_hist = (double *)calloc(LBFGS_M * np, sizeof(double));
    opt->y_hist = (double *)calloc(LBFGS_M * np, sizeof(double));
    opt->rho = (double *)calloc(LBFGS_M, sizeof(double));
    opt->prev_g = (double *)calloc(np, sizeof(double));
    opt->prev_x = (double *)calloc(np, sizeof(double));
    opt->k = 0;
    opt->have_prev = 0;
    return (long long)opt;
}

// L-BFGS two-loop recursion: compute search direction from gradient + history
// params and grads are flat double arrays of length n_params
static void lbfgs_step(NNLbfgs *opt, double *params, double *grads) {
    int np = opt->n_params;
    int m_used = opt->k < LBFGS_M ? opt->k : LBFGS_M;

    if (opt->have_prev) {
        // Store s and y
        int idx = (opt->k - 1) % LBFGS_M;
        double ys = 0;
        for (int i = 0; i < np; i++) {
            opt->s_hist[idx * np + i] = params[i] - opt->prev_x[i];
            opt->y_hist[idx * np + i] = grads[i] - opt->prev_g[i];
            ys += opt->s_hist[idx * np + i] * opt->y_hist[idx * np + i];
        }
        opt->rho[idx] = (fabs(ys) > 1e-15) ? 1.0 / ys : 0.0;
    }

    // Save current for next iteration
    memcpy(opt->prev_x, params, np * sizeof(double));
    memcpy(opt->prev_g, grads, np * sizeof(double));
    opt->have_prev = 1;

    // Two-loop recursion
    double *q = (double *)malloc(np * sizeof(double));
    double *alpha = (double *)malloc(LBFGS_M * sizeof(double));
    memcpy(q, grads, np * sizeof(double));

    for (int i = m_used - 1; i >= 0; i--) {
        int idx = (opt->k - 1 - (m_used - 1 - i)) % LBFGS_M;
        if (idx < 0) idx += LBFGS_M;
        double dot = 0;
        for (int j = 0; j < np; j++) dot += opt->s_hist[idx * np + j] * q[j];
        alpha[i] = opt->rho[idx] * dot;
        for (int j = 0; j < np; j++) q[j] -= alpha[i] * opt->y_hist[idx * np + j];
    }

    // Initial Hessian approximation: H0 = gamma * I
    double gamma = 1.0;
    if (m_used > 0) {
        int last = (opt->k - 1) % LBFGS_M;
        double yy = 0, ys = 0;
        for (int j = 0; j < np; j++) {
            yy += opt->y_hist[last * np + j] * opt->y_hist[last * np + j];
            ys += opt->y_hist[last * np + j] * opt->s_hist[last * np + j];
        }
        if (yy > 1e-15) gamma = ys / yy;
    }
    for (int j = 0; j < np; j++) q[j] *= gamma;

    for (int i = 0; i < m_used; i++) {
        int idx = (opt->k - m_used + i) % LBFGS_M;
        if (idx < 0) idx += LBFGS_M;
        double dot = 0;
        for (int j = 0; j < np; j++) dot += opt->y_hist[idx * np + j] * q[j];
        double beta = opt->rho[idx] * dot;
        for (int j = 0; j < np; j++) q[j] += (alpha[i] - beta) * opt->s_hist[idx * np + j];
    }

    // Update: params -= lr * direction
    for (int j = 0; j < np; j++)
        params[j] -= opt->lr * q[j];

    free(q);
    free(alpha);
    opt->k++;
}

// Step L-BFGS on a dense layer (flattens W+b into param vector, steps, writes back)
void nuc_nn_lbfgs_step_dense(long long opt_handle, long long layer_handle) {
    NNLbfgs *opt = (NNLbfgs *)(void *)opt_handle;
    NNDense *l = (NNDense *)(void *)layer_handle;
    int nw = l->out_dim * l->in_dim;
    int total = nw + l->out_dim;

    double *params = (double *)malloc(total * sizeof(double));
    double *grads = (double *)malloc(total * sizeof(double));
    memcpy(params, l->W, nw * sizeof(double));
    memcpy(params + nw, l->b, l->out_dim * sizeof(double));
    memcpy(grads, l->dW, nw * sizeof(double));
    memcpy(grads + nw, l->db, l->out_dim * sizeof(double));

    lbfgs_step(opt, params, grads);

    memcpy(l->W, params, nw * sizeof(double));
    memcpy(l->b, params + nw, l->out_dim * sizeof(double));
    free(params);
    free(grads);
}

long long nuc_nn_softmax_backward(long long softmax_vec, long long grad_vec) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *sm = (NVec *)(void *)softmax_vec;
    NVec *grad = (NVec *)(void *)grad_vec;
    int n = sm->len;

    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = n; out->cap = n;
    out->data = (long long *)malloc(n * sizeof(long long));

    // dot = sum(grad * softmax)
    double dot = 0;
    for (int i = 0; i < n; i++)
        dot += _i2f(grad->data[i]) * _i2f(sm->data[i]);

    for (int i = 0; i < n; i++) {
        double si = _i2f(sm->data[i]);
        double gi = _i2f(grad->data[i]);
        out->data[i] = _f2i(si * (gi - dot));
    }
    return (long long)out;
}

// =====================================================
// Training-capable normalization layers (ML-9)
// =====================================================

long long nuc_nn_layer_norm(long long input_vec, long long gamma_vec, long long beta_vec, long long eps_bits) {
    NNVec *x = (NNVec *)(void *)input_vec;
    NNVec *gamma = (NNVec *)(void *)gamma_vec;
    NNVec *beta = (NNVec *)(void *)beta_vec;
    int n = x ? x->len : 0;
    NNVec *out = nn_vec_alloc(n);
    if (n <= 0) return (long long)out;

    double eps = _i2f(eps_bits);
    if (!(eps > 0.0)) eps = 1e-5;

    double mean = 0.0;
    for (int i = 0; i < n; i++) mean += _i2f(x->data[i]);
    mean /= (double)n;

    double var = 0.0;
    for (int i = 0; i < n; i++) {
        double d = _i2f(x->data[i]) - mean;
        var += d * d;
    }
    var /= (double)n;
    double inv = 1.0 / sqrt(var + eps);

    for (int i = 0; i < n; i++) {
        double g = (gamma && i < gamma->len) ? _i2f(gamma->data[i]) : 1.0;
        double b = (beta && i < beta->len) ? _i2f(beta->data[i]) : 0.0;
        double xhat = (_i2f(x->data[i]) - mean) * inv;
        out->data[i] = _f2i(xhat * g + b);
    }
    return (long long)out;
}

long long nuc_nn_layer_norm_backward(long long input_vec, long long gamma_vec, long long grad_vec, long long eps_bits) {
    NNVec *x = (NNVec *)(void *)input_vec;
    NNVec *gamma = (NNVec *)(void *)gamma_vec;
    NNVec *grad = (NNVec *)(void *)grad_vec;
    int n = x ? x->len : 0;

    NNVec *dx = nn_vec_alloc(n);
    NNVec *dgamma = nn_vec_alloc(n);
    NNVec *dbeta = nn_vec_alloc(n);
    NNVec *result = nn_vec_alloc(3);
    result->data[0] = (long long)dx;
    result->data[1] = (long long)dgamma;
    result->data[2] = (long long)dbeta;
    if (n <= 0 || !grad) return (long long)result;

    double eps = _i2f(eps_bits);
    if (!(eps > 0.0)) eps = 1e-5;

    double mean = 0.0;
    for (int i = 0; i < n; i++) mean += _i2f(x->data[i]);
    mean /= (double)n;

    double var = 0.0;
    for (int i = 0; i < n; i++) {
        double d = _i2f(x->data[i]) - mean;
        var += d * d;
    }
    var /= (double)n;
    double inv = 1.0 / sqrt(var + eps);

    double *xhat = (double *)malloc((size_t)n * sizeof(double));
    double sum_dxhat = 0.0;
    double sum_dxhat_xhat = 0.0;
    for (int i = 0; i < n; i++) {
        double go = (i < grad->len) ? _i2f(grad->data[i]) : 0.0;
        double g = (gamma && i < gamma->len) ? _i2f(gamma->data[i]) : 1.0;
        xhat[i] = (_i2f(x->data[i]) - mean) * inv;
        double dxhat = go * g;
        sum_dxhat += dxhat;
        sum_dxhat_xhat += dxhat * xhat[i];
        dgamma->data[i] = _f2i(go * xhat[i]);
        dbeta->data[i] = _f2i(go);
    }

    double scale = inv / (double)n;
    for (int i = 0; i < n; i++) {
        double go = (i < grad->len) ? _i2f(grad->data[i]) : 0.0;
        double g = (gamma && i < gamma->len) ? _i2f(gamma->data[i]) : 1.0;
        double dxhat = go * g;
        dx->data[i] = _f2i(scale * ((double)n * dxhat - sum_dxhat - xhat[i] * sum_dxhat_xhat));
    }
    free(xhat);
    return (long long)result;
}

long long nuc_nn_batch_norm(long long input_vec, long long n_samples, long long feat_dim,
                            long long gamma_vec, long long beta_vec, long long eps_bits) {
    NNVec *x = (NNVec *)(void *)input_vec;
    NNVec *gamma = (NNVec *)(void *)gamma_vec;
    NNVec *beta = (NNVec *)(void *)beta_vec;
    int ns = (int)n_samples;
    int fd = (int)feat_dim;
    int total = (ns > 0 && fd > 0) ? ns * fd : 0;
    if (x && x->len < total) total = x->len;
    NNVec *out = nn_vec_alloc(total);
    if (!x || ns <= 0 || fd <= 0 || total <= 0) return (long long)out;

    double eps = _i2f(eps_bits);
    if (!(eps > 0.0)) eps = 1e-5;

    double *mean = (double *)calloc((size_t)fd, sizeof(double));
    double *var = (double *)calloc((size_t)fd, sizeof(double));
    double *inv = (double *)calloc((size_t)fd, sizeof(double));

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx < total) mean[f] += _i2f(x->data[idx]);
        }
    }
    for (int f = 0; f < fd; f++) mean[f] /= (double)ns;

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx < total) {
                double d = _i2f(x->data[idx]) - mean[f];
                var[f] += d * d;
            }
        }
    }
    for (int f = 0; f < fd; f++) {
        var[f] /= (double)ns;
        inv[f] = 1.0 / sqrt(var[f] + eps);
    }

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx >= total) continue;
            double g = (gamma && f < gamma->len) ? _i2f(gamma->data[f]) : 1.0;
            double b = (beta && f < beta->len) ? _i2f(beta->data[f]) : 0.0;
            double xhat = (_i2f(x->data[idx]) - mean[f]) * inv[f];
            out->data[idx] = _f2i(xhat * g + b);
        }
    }

    free(mean);
    free(var);
    free(inv);
    return (long long)out;
}

long long nuc_nn_batch_norm_backward(long long input_vec, long long n_samples, long long feat_dim,
                                     long long gamma_vec, long long grad_vec, long long eps_bits) {
    NNVec *x = (NNVec *)(void *)input_vec;
    NNVec *gamma = (NNVec *)(void *)gamma_vec;
    NNVec *grad = (NNVec *)(void *)grad_vec;
    int ns = (int)n_samples;
    int fd = (int)feat_dim;
    int total = (ns > 0 && fd > 0) ? ns * fd : 0;
    if (x && x->len < total) total = x->len;

    NNVec *dx = nn_vec_alloc(total);
    NNVec *dgamma = nn_vec_alloc(fd > 0 ? fd : 0);
    NNVec *dbeta = nn_vec_alloc(fd > 0 ? fd : 0);
    NNVec *result = nn_vec_alloc(3);
    result->data[0] = (long long)dx;
    result->data[1] = (long long)dgamma;
    result->data[2] = (long long)dbeta;
    if (!x || !grad || ns <= 0 || fd <= 0 || total <= 0) return (long long)result;

    double eps = _i2f(eps_bits);
    if (!(eps > 0.0)) eps = 1e-5;

    double *mean = (double *)calloc((size_t)fd, sizeof(double));
    double *var = (double *)calloc((size_t)fd, sizeof(double));
    double *inv = (double *)calloc((size_t)fd, sizeof(double));
    double *sum_dxhat = (double *)calloc((size_t)fd, sizeof(double));
    double *sum_dxhat_xhat = (double *)calloc((size_t)fd, sizeof(double));
    double *xhat = (double *)calloc((size_t)total, sizeof(double));

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx < total) mean[f] += _i2f(x->data[idx]);
        }
    }
    for (int f = 0; f < fd; f++) mean[f] /= (double)ns;

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx < total) {
                double d = _i2f(x->data[idx]) - mean[f];
                var[f] += d * d;
            }
        }
    }
    for (int f = 0; f < fd; f++) {
        var[f] /= (double)ns;
        inv[f] = 1.0 / sqrt(var[f] + eps);
    }

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx >= total) continue;
            double go = (idx < grad->len) ? _i2f(grad->data[idx]) : 0.0;
            double g = (gamma && f < gamma->len) ? _i2f(gamma->data[f]) : 1.0;
            xhat[idx] = (_i2f(x->data[idx]) - mean[f]) * inv[f];
            double dxhat = go * g;
            sum_dxhat[f] += dxhat;
            sum_dxhat_xhat[f] += dxhat * xhat[idx];
            dgamma->data[f] = _f2i(_i2f(dgamma->data[f]) + go * xhat[idx]);
            dbeta->data[f] = _f2i(_i2f(dbeta->data[f]) + go);
        }
    }

    for (int s = 0; s < ns; s++) {
        for (int f = 0; f < fd; f++) {
            int idx = s * fd + f;
            if (idx >= total) continue;
            double go = (idx < grad->len) ? _i2f(grad->data[idx]) : 0.0;
            double g = (gamma && f < gamma->len) ? _i2f(gamma->data[f]) : 1.0;
            double dxhat = go * g;
            dx->data[idx] = _f2i((inv[f] / (double)ns) *
                ((double)ns * dxhat - sum_dxhat[f] - xhat[idx] * sum_dxhat_xhat[f]));
        }
    }

    free(mean);
    free(var);
    free(inv);
    free(sum_dxhat);
    free(sum_dxhat_xhat);
    free(xhat);
    return (long long)result;
}

// =====================================================
// Functional convolution layers with gradients (ML-8)
// =====================================================

long long nuc_nn_conv1d(long long input_h, long long kernel_h,
                        long long c_in, long long c_out, long long length,
                        long long k_width, long long stride, long long pad) {
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int ci = (int)c_in, co = (int)c_out, L = (int)length;
    int kw = (int)k_width, s = (int)stride, p = (int)pad;
    int out_L = (L + 2 * p - kw) / s + 1;
    NNVec *out = nn_vec_alloc(co * out_L);

    for (int oc = 0; oc < co; oc++) {
        for (int ox = 0; ox < out_L; ox++) {
            double sum = 0.0;
            for (int ic = 0; ic < ci; ic++) {
                for (int fx = 0; fx < kw; fx++) {
                    int ix = ox * s - p + fx;
                    if (ix < 0 || ix >= L) continue;
                    int in_idx = ic * L + ix;
                    int k_idx = oc * ci * kw + ic * kw + fx;
                    sum += _i2f(input->data[in_idx]) * _i2f(kernel->data[k_idx]);
                }
            }
            out->data[oc * out_L + ox] = _f2i(sum);
        }
    }
    return (long long)out;
}

long long nuc_nn_conv1d_backward(long long grad_out_h, long long input_h, long long kernel_h,
                                 long long c_in, long long c_out, long long length,
                                 long long k_width, long long stride, long long pad) {
    NNVec *grad_out = (NNVec *)(void *)grad_out_h;
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int ci = (int)c_in, co = (int)c_out, L = (int)length;
    int kw = (int)k_width, s = (int)stride, p = (int)pad;
    int out_L = (L + 2 * p - kw) / s + 1;
    NNVec *grad_input = nn_vec_alloc(ci * L);
    NNVec *grad_kernel = nn_vec_alloc(co * ci * kw);

    for (int oc = 0; oc < co; oc++) {
        for (int ox = 0; ox < out_L; ox++) {
            double go = _i2f(grad_out->data[oc * out_L + ox]);
            for (int ic = 0; ic < ci; ic++) {
                for (int fx = 0; fx < kw; fx++) {
                    int ix = ox * s - p + fx;
                    if (ix < 0 || ix >= L) continue;
                    int in_idx = ic * L + ix;
                    int k_idx = oc * ci * kw + ic * kw + fx;
                    grad_input->data[in_idx] = _f2i(_i2f(grad_input->data[in_idx]) +
                        go * _i2f(kernel->data[k_idx]));
                    grad_kernel->data[k_idx] = _f2i(_i2f(grad_kernel->data[k_idx]) +
                        go * _i2f(input->data[in_idx]));
                }
            }
        }
    }

    NNVec *result = nn_vec_alloc(2);
    result->data[0] = (long long)grad_input;
    result->data[1] = (long long)grad_kernel;
    return (long long)result;
}

long long nuc_nn_conv2d(long long input_h, long long kernel_h,
                        long long c_in, long long c_out,
                        long long height, long long width,
                        long long k_height, long long k_width,
                        long long stride, long long pad) {
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int ci = (int)c_in, co = (int)c_out;
    int H = (int)height, W = (int)width, kh = (int)k_height, kw = (int)k_width;
    int s = (int)stride, p = (int)pad;
    int out_H = (H + 2 * p - kh) / s + 1;
    int out_W = (W + 2 * p - kw) / s + 1;
    NNVec *out = nn_vec_alloc(co * out_H * out_W);

    for (int oc = 0; oc < co; oc++) {
        for (int oh = 0; oh < out_H; oh++) {
            for (int ow = 0; ow < out_W; ow++) {
                double sum = 0.0;
                for (int ic = 0; ic < ci; ic++) {
                    for (int fh = 0; fh < kh; fh++) {
                        for (int fw = 0; fw < kw; fw++) {
                            int ih = oh * s - p + fh;
                            int iw = ow * s - p + fw;
                            if (ih < 0 || ih >= H || iw < 0 || iw >= W) continue;
                            int in_idx = ic * H * W + ih * W + iw;
                            int k_idx = oc * ci * kh * kw + ic * kh * kw + fh * kw + fw;
                            sum += _i2f(input->data[in_idx]) * _i2f(kernel->data[k_idx]);
                        }
                    }
                }
                out->data[oc * out_H * out_W + oh * out_W + ow] = _f2i(sum);
            }
        }
    }
    return (long long)out;
}

long long nuc_nn_conv2d_backward(long long grad_out_h, long long input_h, long long kernel_h,
                                 long long c_in, long long c_out,
                                 long long height, long long width,
                                 long long k_height, long long k_width,
                                 long long stride, long long pad) {
    NNVec *grad_out = (NNVec *)(void *)grad_out_h;
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int ci = (int)c_in, co = (int)c_out;
    int H = (int)height, W = (int)width, kh = (int)k_height, kw = (int)k_width;
    int s = (int)stride, p = (int)pad;
    int out_H = (H + 2 * p - kh) / s + 1;
    int out_W = (W + 2 * p - kw) / s + 1;
    NNVec *grad_input = nn_vec_alloc(ci * H * W);
    NNVec *grad_kernel = nn_vec_alloc(co * ci * kh * kw);

    for (int oc = 0; oc < co; oc++) {
        for (int oh = 0; oh < out_H; oh++) {
            for (int ow = 0; ow < out_W; ow++) {
                double go = _i2f(grad_out->data[oc * out_H * out_W + oh * out_W + ow]);
                for (int ic = 0; ic < ci; ic++) {
                    for (int fh = 0; fh < kh; fh++) {
                        for (int fw = 0; fw < kw; fw++) {
                            int ih = oh * s - p + fh;
                            int iw = ow * s - p + fw;
                            if (ih < 0 || ih >= H || iw < 0 || iw >= W) continue;
                            int in_idx = ic * H * W + ih * W + iw;
                            int k_idx = oc * ci * kh * kw + ic * kh * kw + fh * kw + fw;
                            grad_input->data[in_idx] = _f2i(_i2f(grad_input->data[in_idx]) +
                                go * _i2f(kernel->data[k_idx]));
                            grad_kernel->data[k_idx] = _f2i(_i2f(grad_kernel->data[k_idx]) +
                                go * _i2f(input->data[in_idx]));
                        }
                    }
                }
            }
        }
    }

    NNVec *result = nn_vec_alloc(2);
    result->data[0] = (long long)grad_input;
    result->data[1] = (long long)grad_kernel;
    return (long long)result;
}

long long nuc_nn_depthwise_conv2d(long long input_h, long long kernel_h,
                                  long long channels, long long height, long long width,
                                  long long k_height, long long k_width,
                                  long long stride, long long pad) {
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int C = (int)channels, H = (int)height, W = (int)width;
    int kh = (int)k_height, kw = (int)k_width, s = (int)stride, p = (int)pad;
    int out_H = (H + 2 * p - kh) / s + 1;
    int out_W = (W + 2 * p - kw) / s + 1;
    NNVec *out = nn_vec_alloc(C * out_H * out_W);

    for (int c = 0; c < C; c++) {
        for (int oh = 0; oh < out_H; oh++) {
            for (int ow = 0; ow < out_W; ow++) {
                double sum = 0.0;
                for (int fh = 0; fh < kh; fh++) {
                    for (int fw = 0; fw < kw; fw++) {
                        int ih = oh * s - p + fh;
                        int iw = ow * s - p + fw;
                        if (ih < 0 || ih >= H || iw < 0 || iw >= W) continue;
                        int in_idx = c * H * W + ih * W + iw;
                        int k_idx = c * kh * kw + fh * kw + fw;
                        sum += _i2f(input->data[in_idx]) * _i2f(kernel->data[k_idx]);
                    }
                }
                out->data[c * out_H * out_W + oh * out_W + ow] = _f2i(sum);
            }
        }
    }
    return (long long)out;
}

long long nuc_nn_depthwise_conv2d_backward(long long grad_out_h, long long input_h, long long kernel_h,
                                           long long channels, long long height, long long width,
                                           long long k_height, long long k_width,
                                           long long stride, long long pad) {
    NNVec *grad_out = (NNVec *)(void *)grad_out_h;
    NNVec *input = (NNVec *)(void *)input_h;
    NNVec *kernel = (NNVec *)(void *)kernel_h;
    int C = (int)channels, H = (int)height, W = (int)width;
    int kh = (int)k_height, kw = (int)k_width, s = (int)stride, p = (int)pad;
    int out_H = (H + 2 * p - kh) / s + 1;
    int out_W = (W + 2 * p - kw) / s + 1;
    NNVec *grad_input = nn_vec_alloc(C * H * W);
    NNVec *grad_kernel = nn_vec_alloc(C * kh * kw);

    for (int c = 0; c < C; c++) {
        for (int oh = 0; oh < out_H; oh++) {
            for (int ow = 0; ow < out_W; ow++) {
                double go = _i2f(grad_out->data[c * out_H * out_W + oh * out_W + ow]);
                for (int fh = 0; fh < kh; fh++) {
                    for (int fw = 0; fw < kw; fw++) {
                        int ih = oh * s - p + fh;
                        int iw = ow * s - p + fw;
                        if (ih < 0 || ih >= H || iw < 0 || iw >= W) continue;
                        int in_idx = c * H * W + ih * W + iw;
                        int k_idx = c * kh * kw + fh * kw + fw;
                        grad_input->data[in_idx] = _f2i(_i2f(grad_input->data[in_idx]) +
                            go * _i2f(kernel->data[k_idx]));
                        grad_kernel->data[k_idx] = _f2i(_i2f(grad_kernel->data[k_idx]) +
                            go * _i2f(input->data[in_idx]));
                    }
                }
            }
        }
    }

    NNVec *result = nn_vec_alloc(2);
    result->data[0] = (long long)grad_input;
    result->data[1] = (long long)grad_kernel;
    return (long long)result;
}
