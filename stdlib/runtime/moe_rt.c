// moe_rt.c — Mixture of Experts Routing for Nucleor
// Top-K gating, token dispatch/gather, load balancing, expert forward.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/moe_rt.c -o target/moe_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _mo_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _mo_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } MOVec;

static MOVec *movec_new(int n) {
    MOVec *v = (MOVec *)malloc(sizeof(MOVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Softmax Gating with Top-K Selection
//  gate_logits: [n_tokens, n_experts]
//  Returns: indices [n_tokens, K], weights [n_tokens, K]
// ================================================================

typedef struct {
    long long indices;  // MOVec [n_tokens * K]
    long long weights;  // MOVec [n_tokens * K] (f64 bitcast)
} MoERouting;

long long nuc_moe_topk_gate(long long logits_h, long long n_tokens, long long n_experts, long long K) {
    MOVec *logits = (MOVec *)(void *)logits_h;
    int nt = (int)n_tokens, ne = (int)n_experts, k = (int)K;

    MOVec *indices = movec_new(nt * k);
    MOVec *weights = movec_new(nt * k);

    for (int t = 0; t < nt; t++) {
        // Softmax over experts
        double max_val = -1e30;
        for (int e = 0; e < ne; e++) {
            double v = _mo_i2f(logits->data[t * ne + e]);
            if (v > max_val) max_val = v;
        }
        double *probs = (double *)malloc(ne * sizeof(double));
        double sum = 0;
        for (int e = 0; e < ne; e++) {
            probs[e] = exp(_mo_i2f(logits->data[t * ne + e]) - max_val);
            sum += probs[e];
        }
        for (int e = 0; e < ne; e++) probs[e] /= sum;

        // Select top-K
        int *selected = (int *)calloc(ne, sizeof(int));
        for (int ki = 0; ki < k; ki++) {
            int best = -1;
            double best_p = -1;
            for (int e = 0; e < ne; e++) {
                if (!selected[e] && probs[e] > best_p) { best_p = probs[e]; best = e; }
            }
            if (best >= 0) {
                selected[best] = 1;
                indices->data[t * k + ki] = best;
                weights->data[t * k + ki] = _mo_f2i(best_p);
            }
        }

        // Renormalize selected weights
        double wsum = 0;
        for (int ki = 0; ki < k; ki++) wsum += _mo_i2f(weights->data[t * k + ki]);
        if (wsum > 1e-10) {
            for (int ki = 0; ki < k; ki++)
                weights->data[t * k + ki] = _mo_f2i(_mo_i2f(weights->data[t * k + ki]) / wsum);
        }

        free(probs); free(selected);
    }

    MoERouting *result = (MoERouting *)malloc(sizeof(MoERouting));
    result->indices = (long long)indices;
    result->weights = (long long)weights;
    return (long long)result;
}

long long nuc_moe_route_indices(long long h) { return ((MoERouting *)(void *)h)->indices; }
long long nuc_moe_route_weights(long long h) { return ((MoERouting *)(void *)h)->weights; }

// ================================================================
//  Token Dispatch: scatter tokens to their assigned experts
//  Returns per-expert token lists
// ================================================================

long long nuc_moe_dispatch(long long tokens_h, long long indices_h,
                            long long n_tokens, long long dim, long long n_experts, long long K) {
    MOVec *tokens = (MOVec *)(void *)tokens_h; // [n_tokens, dim]
    MOVec *indices = (MOVec *)(void *)indices_h; // [n_tokens * K]
    int nt = (int)n_tokens, d = (int)dim, ne = (int)n_experts, k = (int)K;

    // Count tokens per expert
    int *counts = (int *)calloc(ne, sizeof(int));
    for (int i = 0; i < nt * k; i++) counts[(int)indices->data[i]]++;

    // Allocate per-expert buffers
    // Pack as flat: [expert_0_tokens..., expert_1_tokens..., ...]
    // with a header: [count_0, offset_0, count_1, offset_1, ...]
    int total = nt * k;
    MOVec *dispatched = movec_new(ne * 2 + total * d);

    int *offsets = (int *)calloc(ne, sizeof(int));
    int running = ne * 2; // skip header
    for (int e = 0; e < ne; e++) {
        dispatched->data[e * 2] = counts[e];
        dispatched->data[e * 2 + 1] = running;
        offsets[e] = running;
        running += counts[e] * d;
    }
    dispatched->len = running;

    // Fill
    int *cur = (int *)calloc(ne, sizeof(int));
    for (int t = 0; t < nt; t++) {
        for (int ki = 0; ki < k; ki++) {
            int e = (int)indices->data[t * k + ki];
            int dst = offsets[e] + cur[e] * d;
            for (int j = 0; j < d; j++)
                dispatched->data[dst + j] = tokens->data[t * d + j];
            cur[e]++;
        }
    }

    free(counts); free(offsets); free(cur);
    return (long long)dispatched;
}

// ================================================================
//  Weighted Combine: gather expert outputs and combine by gate weights
// ================================================================

long long nuc_moe_combine(long long expert_outputs_h, long long indices_h,
                           long long weights_h, long long n_tokens, long long dim, long long K) {
    // expert_outputs_h: flat Vec matching dispatch layout
    // For simplicity: expert_outputs[t*K + ki] = expert output for token t, expert ki
    MOVec *eout = (MOVec *)(void *)expert_outputs_h; // [n_tokens * K, dim]
    MOVec *weights = (MOVec *)(void *)weights_h;
    int nt = (int)n_tokens, d = (int)dim, k = (int)K;

    MOVec *out = movec_new(nt * d);
    for (int t = 0; t < nt; t++) {
        for (int j = 0; j < d; j++) {
            double sum = 0;
            for (int ki = 0; ki < k; ki++) {
                double w = _mo_i2f(weights->data[t * k + ki]);
                double v = _mo_i2f(eout->data[(t * k + ki) * d + j]);
                sum += w * v;
            }
            out->data[t * d + j] = _mo_f2i(sum);
        }
    }
    return (long long)out;
}

// ================================================================
//  Load Balance Tracking
// ================================================================

typedef struct {
    int n_experts;
    long long *token_counts;
    long long total_tokens;
    double *bias; // auxiliary-loss-free bias terms
} LoadBalancer;

long long nuc_moe_balance_new(long long n_experts) {
    int ne = (int)n_experts;
    LoadBalancer *lb = (LoadBalancer *)calloc(1, sizeof(LoadBalancer));
    lb->n_experts = ne;
    lb->token_counts = (long long *)calloc(ne, sizeof(long long));
    lb->bias = (double *)calloc(ne, sizeof(double));
    return (long long)lb;
}

void nuc_moe_balance_update(long long lbh, long long indices_h, long long n_tokens, long long K) {
    LoadBalancer *lb = (LoadBalancer *)(void *)lbh;
    MOVec *indices = (MOVec *)(void *)indices_h;
    int nt = (int)n_tokens, k = (int)K;
    for (int i = 0; i < nt * k; i++) lb->token_counts[(int)indices->data[i]]++;
    lb->total_tokens += nt * k;

    // Adjust bias: increase for underloaded, decrease for overloaded
    double avg = (double)lb->total_tokens / lb->n_experts;
    for (int e = 0; e < lb->n_experts; e++) {
        double load_ratio = lb->token_counts[e] / (avg > 0 ? avg : 1);
        lb->bias[e] += 0.01 * (1.0 - load_ratio); // nudge toward balance
    }
}

// Get bias to add to gate logits (auxiliary-loss-free balancing)
long long nuc_moe_balance_bias(long long lbh) {
    LoadBalancer *lb = (LoadBalancer *)(void *)lbh;
    MOVec *bias = movec_new(lb->n_experts);
    for (int i = 0; i < lb->n_experts; i++) bias->data[i] = _mo_f2i(lb->bias[i]);
    return (long long)bias;
}

// Load balance coefficient of variation (lower = more balanced)
long long nuc_moe_balance_cv(long long lbh) {
    LoadBalancer *lb = (LoadBalancer *)(void *)lbh;
    double mean = 0;
    for (int e = 0; e < lb->n_experts; e++) mean += lb->token_counts[e];
    mean /= lb->n_experts;
    double var = 0;
    for (int e = 0; e < lb->n_experts; e++) {
        double d = lb->token_counts[e] - mean;
        var += d * d;
    }
    double std = sqrt(var / lb->n_experts);
    return _mo_f2i(mean > 0 ? std / mean : 0);
}
