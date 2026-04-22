// speculative_rt.c — Speculative Decoding for Nucleor
// Draft-verify tree construction, rejection sampling, token acceptance.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/speculative_rt.c -o target/speculative_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _sp_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _sp_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } SPVec;

static SPVec *spvec_new(int n) {
    SPVec *v = (SPVec *)malloc(sizeof(SPVec));
    v->len = n; v->cap = n; v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// Simple RNG for rejection sampling
static unsigned int sp_rng = 98765;
static double sp_uniform(void) {
    sp_rng = sp_rng * 1103515245 + 12345;
    return ((double)((sp_rng >> 16) & 0x7FFF)) / 32767.0;
}

void nuc_spec_seed(long long seed) { sp_rng = (unsigned int)seed; }

// ================================================================
//  Rejection Sampling for Speculative Decoding
//  For each draft token: accept with probability min(1, p_target / p_draft)
//  On rejection: sample from norm(max(0, p_target - p_draft))
//
//  draft_probs: [n_draft, vocab_size] — draft model probabilities
//  target_probs: [n_draft, vocab_size] — target model probabilities
//  draft_tokens: [n_draft] — tokens chosen by draft model
//
//  Returns: [accepted_length, corrected_token_or_-1]
// ================================================================

long long nuc_spec_verify(long long draft_probs_h, long long target_probs_h,
                           long long draft_tokens_h, long long n_draft, long long vocab_size) {
    SPVec *dp = (SPVec *)(void *)draft_probs_h;
    SPVec *tp = (SPVec *)(void *)target_probs_h;
    SPVec *dt = (SPVec *)(void *)draft_tokens_h;
    int nd = (int)n_draft, vs = (int)vocab_size;

    int accepted = 0;
    int correction_token = -1;

    for (int i = 0; i < nd; i++) {
        int token = (int)dt->data[i];
        double p_draft = _sp_i2f(dp->data[i * vs + token]);
        double p_target = _sp_i2f(tp->data[i * vs + token]);

        double accept_prob = (p_draft > 1e-15) ? p_target / p_draft : 0;
        if (accept_prob > 1.0) accept_prob = 1.0;

        double u = sp_uniform();
        if (u < accept_prob) {
            accepted++;
        } else {
            // Rejection: sample from adjusted distribution
            // p_adj = max(0, p_target - p_draft) / Z
            double Z = 0;
            double *p_adj = (double *)malloc(vs * sizeof(double));
            for (int v = 0; v < vs; v++) {
                double pt = _sp_i2f(tp->data[i * vs + v]);
                double pd = _sp_i2f(dp->data[i * vs + v]);
                p_adj[v] = pt - pd;
                if (p_adj[v] < 0) p_adj[v] = 0;
                Z += p_adj[v];
            }
            if (Z > 1e-15) {
                double r = sp_uniform() * Z;
                double cum = 0;
                for (int v = 0; v < vs; v++) {
                    cum += p_adj[v];
                    if (cum >= r) { correction_token = v; break; }
                }
            } else {
                // Fallback: sample from target
                double r = sp_uniform();
                double cum = 0;
                for (int v = 0; v < vs; v++) {
                    cum += _sp_i2f(tp->data[i * vs + v]);
                    if (cum >= r) { correction_token = v; break; }
                }
            }
            free(p_adj);
            break;
        }
    }

    // Result: [accepted_length, correction_token]
    SPVec *result = spvec_new(2);
    result->data[0] = accepted;
    result->data[1] = correction_token;
    return (long long)result;
}

// ================================================================
//  Tree-based Draft Construction
//  Given top-k tokens at each position, build a candidate tree.
//  Returns flat token sequence + tree mask for batched verification.
// ================================================================

typedef struct TreeNode TreeNode;
struct TreeNode {
    int token;
    double prob;
    TreeNode **children;
    int n_children;
    int depth;
    int flat_idx; // position in flattened sequence
};

static TreeNode *tree_new(int token, double prob, int depth) {
    TreeNode *n = (TreeNode *)calloc(1, sizeof(TreeNode));
    n->token = token; n->prob = prob; n->depth = depth;
    return n;
}

static void tree_add_child(TreeNode *parent, TreeNode *child) {
    parent->children = (TreeNode **)realloc(parent->children,
                                             (parent->n_children + 1) * sizeof(TreeNode *));
    parent->children[parent->n_children++] = child;
}

// Build tree from top-k logits at each depth
// topk_tokens: [max_depth, k] — token ids
// topk_probs: [max_depth, k] — probabilities
long long nuc_spec_build_tree(long long topk_tokens_h, long long topk_probs_h,
                                long long max_depth, long long k, long long max_nodes) {
    SPVec *tokens = (SPVec *)(void *)topk_tokens_h;
    SPVec *probs = (SPVec *)(void *)topk_probs_h;
    int md = (int)max_depth, K = (int)k, mn = (int)max_nodes;

    // Flatten tree in BFS order for batched verification
    int flat_size = 0;
    SPVec *flat_tokens = spvec_new(mn);
    SPVec *flat_parents = spvec_new(mn); // parent index for each node

    // Level 0: top-k tokens
    int level_start = 0, level_end = 0;
    for (int i = 0; i < K && flat_size < mn; i++) {
        flat_tokens->data[flat_size] = tokens->data[i];
        flat_parents->data[flat_size] = -1; // root
        flat_size++;
    }
    level_end = flat_size;

    // Deeper levels: expand top-k from each parent
    for (int d = 1; d < md && flat_size < mn; d++) {
        int new_end = flat_size;
        for (int p = level_start; p < level_end && flat_size < mn; p++) {
            // Use depth-d top-k tokens (simplified: same set for all parents)
            int n_expand = K;
            if (flat_size + n_expand > mn) n_expand = mn - flat_size;
            for (int i = 0; i < n_expand; i++) {
                flat_tokens->data[flat_size] = tokens->data[d * K + i];
                flat_parents->data[flat_size] = p;
                flat_size++;
            }
        }
        level_start = level_end;
        level_end = flat_size;
    }

    flat_tokens->len = flat_size;
    flat_parents->len = flat_size;

    // Pack result: [flat_tokens_handle, flat_parents_handle, size]
    SPVec *result = spvec_new(3);
    result->data[0] = (long long)flat_tokens;
    result->data[1] = (long long)flat_parents;
    result->data[2] = flat_size;
    return (long long)result;
}

// ================================================================
//  Generate causal attention mask for tree verification
//  Each node can only attend to its ancestors in the tree.
// ================================================================

long long nuc_spec_tree_mask(long long parents_h, long long n_nodes) {
    SPVec *parents = (SPVec *)(void *)parents_h;
    int n = (int)n_nodes;

    // mask[i][j] = 1 if node j is an ancestor of node i (or j == i)
    SPVec *mask = spvec_new(n * n);
    for (int i = 0; i < n; i++) {
        mask->data[i * n + i] = 1; // self
        int p = (int)parents->data[i];
        while (p >= 0) {
            mask->data[i * n + p] = 1;
            p = (int)parents->data[p];
        }
    }
    return (long long)mask;
}

// ================================================================
//  Sample from logits (temperature + top-k)
// ================================================================

long long nuc_spec_sample(long long logits_h, long long temperature_bits, long long top_k) {
    SPVec *logits = (SPVec *)(void *)logits_h;
    double temp = _sp_i2f(temperature_bits);
    int K = (int)top_k;
    int n = logits->len;
    if (temp <= 0) temp = 1.0;

    // Apply temperature
    double *probs = (double *)malloc(n * sizeof(double));
    double max_val = _sp_i2f(logits->data[0]);
    for (int i = 1; i < n; i++) { double v = _sp_i2f(logits->data[i]); if (v > max_val) max_val = v; }
    double sum = 0;
    for (int i = 0; i < n; i++) {
        probs[i] = exp((_sp_i2f(logits->data[i]) - max_val) / temp);
        sum += probs[i];
    }
    for (int i = 0; i < n; i++) probs[i] /= sum;

    // Top-K filtering
    if (K > 0 && K < n) {
        // Find K-th largest probability
        double *sorted = (double *)malloc(n * sizeof(double));
        memcpy(sorted, probs, n * sizeof(double));
        for (int i = 0; i < K; i++)
            for (int j = i + 1; j < n; j++)
                if (sorted[j] > sorted[i]) { double t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }
        double threshold = sorted[K - 1];
        free(sorted);
        sum = 0;
        for (int i = 0; i < n; i++) {
            if (probs[i] < threshold) probs[i] = 0;
            sum += probs[i];
        }
        if (sum > 1e-15) for (int i = 0; i < n; i++) probs[i] /= sum;
    }

    // Sample
    double r = sp_uniform();
    double cum = 0;
    int token = 0;
    for (int i = 0; i < n; i++) { cum += probs[i]; if (cum >= r) { token = i; break; } }

    free(probs);
    return (long long)token;
}
