// gnn_rt.c — Graph Neural Network Runtime for Nucleor
// GATv2Conv, GlobalAttention pooling, graph data structures.
// Matches PyTorch Geometric GATv2Conv + GlobalAttention.
//
// Compile: clang -c gnn_rt.c -o target/gnn_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _gi2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _gf2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }
typedef struct { long long *data; int len; int cap; } GVec;

static void gvec_push(GVec *v, long long val) {
    if (v->len >= v->cap) {
        v->cap = v->cap * 2 + 4;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
    }
    v->data[v->len++] = val;
}

// =====================================================
// Graph data structure
// A graph has: node_features[n_nodes * feat_dim], edge_src[], edge_dst[]
// =====================================================
typedef struct {
    int n_nodes;
    int feat_dim;
    double *node_feats;  // n_nodes * feat_dim
    int n_edges;
    int *edge_src;       // n_edges
    int *edge_dst;       // n_edges
} Graph;

// Create graph from Nucleor Vecs
// node_feat_vec: flat Vec of n_nodes * feat_dim f64 values
// edge_src_vec, edge_dst_vec: Vec of int pairs
long long nuc_gnn_graph_new(long long node_feat_vec, long long n_nodes, long long feat_dim,
                             long long edge_src_vec, long long edge_dst_vec, long long n_edges) {
    GVec *nfv = (GVec *)(void *)node_feat_vec;
    GVec *esv = (GVec *)(void *)edge_src_vec;
    GVec *edv = (GVec *)(void *)edge_dst_vec;

    Graph *g = (Graph *)calloc(1, sizeof(Graph));
    g->n_nodes = (int)n_nodes;
    g->feat_dim = (int)feat_dim;
    g->n_edges = (int)n_edges;

    g->node_feats = (double *)malloc(g->n_nodes * g->feat_dim * sizeof(double));
    for (int i = 0; i < g->n_nodes * g->feat_dim && i < nfv->len; i++)
        g->node_feats[i] = _gi2f(nfv->data[i]);

    g->edge_src = (int *)malloc(g->n_edges * sizeof(int));
    g->edge_dst = (int *)malloc(g->n_edges * sizeof(int));
    for (int i = 0; i < g->n_edges; i++) {
        g->edge_src[i] = (i < esv->len) ? (int)esv->data[i] : 0;
        g->edge_dst[i] = (i < edv->len) ? (int)edv->data[i] : 0;
    }
    return (long long)g;
}

void nuc_gnn_graph_free(long long handle) {
    Graph *g = (Graph *)(void *)handle;
    if (!g) return;
    free(g->node_feats); free(g->edge_src); free(g->edge_dst); free(g);
}

// =====================================================
// GATv2Conv: Graph Attention Network v2 Convolution
// For each edge (i,j): compute attention score, then aggregate
//
// GATv2: score = a^T * LeakyReLU(W_l * x_i + W_r * x_j)
// alpha = softmax(scores) over neighbors
// h_i = sum_j(alpha_ij * W_r * x_j)
// =====================================================
typedef struct {
    int in_dim, out_dim;
    double *W_l;      // out_dim * in_dim (left/source transform)
    double *W_r;      // out_dim * in_dim (right/target transform)
    double *a;        // out_dim (attention vector)
    double *bias;     // out_dim
    // Gradients
    double *dW_l, *dW_r, *da, *dbias;
    // Cache for backward
    double *cache_h;  // n_nodes * out_dim (output)
    int cache_n_nodes;
} GATv2Layer;

// Xavier init helper
static unsigned int _gnn_rng = 77777;
static double gnn_rand_xavier(int fan_in, int fan_out) {
    _gnn_rng = _gnn_rng * 1103515245 + 12345;
    double u = ((double)((_gnn_rng >> 16) & 0x7FFF)) / 32767.0;
    double scale = sqrt(2.0 / (fan_in + fan_out));
    return (u * 2.0 - 1.0) * scale;
}

long long nuc_gnn_gatv2_new(long long in_dim, long long out_dim) {
    int id = (int)in_dim, od = (int)out_dim;
    GATv2Layer *layer = (GATv2Layer *)calloc(1, sizeof(GATv2Layer));
    layer->in_dim = id;
    layer->out_dim = od;
    layer->W_l = (double *)malloc(od * id * sizeof(double));
    layer->W_r = (double *)malloc(od * id * sizeof(double));
    layer->a = (double *)malloc(od * sizeof(double));
    layer->bias = (double *)calloc(od, sizeof(double));
    layer->dW_l = (double *)calloc(od * id, sizeof(double));
    layer->dW_r = (double *)calloc(od * id, sizeof(double));
    layer->da = (double *)calloc(od, sizeof(double));
    layer->dbias = (double *)calloc(od, sizeof(double));
    layer->cache_h = NULL;

    for (int i = 0; i < od * id; i++) {
        layer->W_l[i] = gnn_rand_xavier(id, od);
        layer->W_r[i] = gnn_rand_xavier(id, od);
    }
    for (int i = 0; i < od; i++)
        layer->a[i] = gnn_rand_xavier(od, 1);
    return (long long)layer;
}

// Forward: returns Vec of n_nodes * out_dim f64 values
long long nuc_gnn_gatv2_forward(long long layer_handle, long long graph_handle) {
    GATv2Layer *layer = (GATv2Layer *)(void *)layer_handle;
    Graph *g = (Graph *)(void *)graph_handle;
    int n = g->n_nodes, id = layer->in_dim, od = layer->out_dim;
    int ne = g->n_edges;

    // Compute W_l * x_i and W_r * x_j for all nodes
    double *Wl_x = (double *)calloc(n * od, sizeof(double)); // W_l * x for each node
    double *Wr_x = (double *)calloc(n * od, sizeof(double)); // W_r * x for each node
    for (int i = 0; i < n; i++) {
        for (int o = 0; o < od; o++) {
            double sl = 0, sr = 0;
            for (int j = 0; j < id; j++) {
                sl += layer->W_l[o * id + j] * g->node_feats[i * id + j];
                sr += layer->W_r[o * id + j] * g->node_feats[i * id + j];
            }
            Wl_x[i * od + o] = sl;
            Wr_x[i * od + o] = sr;
        }
    }

    // For each edge, compute attention score: a^T * LeakyReLU(Wl*x_src + Wr*x_dst)
    double *edge_scores = (double *)calloc(ne, sizeof(double));
    for (int e = 0; e < ne; e++) {
        int src = g->edge_src[e], dst = g->edge_dst[e];
        double score = 0;
        for (int o = 0; o < od; o++) {
            double val = Wl_x[src * od + o] + Wr_x[dst * od + o];
            // LeakyReLU (negative_slope=0.2)
            if (val < 0) val *= 0.2;
            score += layer->a[o] * val;
        }
        edge_scores[e] = score;
    }

    // Softmax per destination node (normalize over incoming edges)
    double *edge_alpha = (double *)calloc(ne, sizeof(double));
    // Find max score per dst node for numerical stability
    double *max_score = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) max_score[i] = -1e30;
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        if (edge_scores[e] > max_score[dst]) max_score[dst] = edge_scores[e];
    }
    double *sum_exp = (double *)calloc(n, sizeof(double));
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        edge_alpha[e] = exp(edge_scores[e] - max_score[dst]);
        sum_exp[dst] += edge_alpha[e];
    }
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        edge_alpha[e] = (sum_exp[dst] > 1e-15) ? edge_alpha[e] / sum_exp[dst] : 1.0 / ne;
    }

    // Aggregate: h_dst = sum_{src->dst}(alpha * Wr * x_src) + bias
    double *h = (double *)calloc(n * od, sizeof(double));
    for (int e = 0; e < ne; e++) {
        int src = g->edge_src[e], dst = g->edge_dst[e];
        for (int o = 0; o < od; o++)
            h[dst * od + o] += edge_alpha[e] * Wr_x[src * od + o];
    }
    for (int i = 0; i < n; i++)
        for (int o = 0; o < od; o++)
            h[i * od + o] += layer->bias[o];

    // Cache output for backward
    if (layer->cache_h) free(layer->cache_h);
    layer->cache_h = (double *)malloc(n * od * sizeof(double));
    memcpy(layer->cache_h, h, n * od * sizeof(double));
    layer->cache_n_nodes = n;

    // Pack into Vec
    GVec *out = (GVec *)malloc(sizeof(GVec));
    out->len = n * od;
    out->cap = n * od;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < n * od; i++)
        out->data[i] = _gf2i(h[i]);

    free(Wl_x); free(Wr_x); free(edge_scores); free(edge_alpha);
    free(max_score); free(sum_exp); free(h);
    return (long long)out;
}

// GATv2 Backward: given grad w.r.t. output node features [n_nodes * out_dim],
// compute gradients for W_l, W_r, a, bias and return grad w.r.t. input node features.
// This is the full backprop through the attention mechanism.
long long nuc_gnn_gatv2_backward(long long layer_handle, long long graph_handle, long long grad_out_vec) {
    GATv2Layer *layer = (GATv2Layer *)(void *)layer_handle;
    Graph *g = (Graph *)(void *)graph_handle;
    GVec *grad_out = (GVec *)(void *)grad_out_vec;
    int n = g->n_nodes, id = layer->in_dim, od = layer->out_dim, ne = g->n_edges;

    // Recompute forward values needed for backward
    double *Wl_x = (double *)calloc(n * od, sizeof(double));
    double *Wr_x = (double *)calloc(n * od, sizeof(double));
    for (int i = 0; i < n; i++)
        for (int o = 0; o < od; o++) {
            double sl = 0, sr = 0;
            for (int j = 0; j < id; j++) {
                sl += layer->W_l[o * id + j] * g->node_feats[i * id + j];
                sr += layer->W_r[o * id + j] * g->node_feats[i * id + j];
            }
            Wl_x[i * od + o] = sl;
            Wr_x[i * od + o] = sr;
        }

    // Recompute attention scores and alphas
    double *edge_scores = (double *)calloc(ne, sizeof(double));
    double *leaky_vals = (double *)calloc(ne * od, sizeof(double)); // store pre-leaky values
    for (int e = 0; e < ne; e++) {
        int src = g->edge_src[e], dst = g->edge_dst[e];
        double score = 0;
        for (int o = 0; o < od; o++) {
            double val = Wl_x[src * od + o] + Wr_x[dst * od + o];
            leaky_vals[e * od + o] = val;
            if (val < 0) val *= 0.2;
            score += layer->a[o] * val;
        }
        edge_scores[e] = score;
    }

    double *edge_alpha = (double *)calloc(ne, sizeof(double));
    double *max_score = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) max_score[i] = -1e30;
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        if (edge_scores[e] > max_score[dst]) max_score[dst] = edge_scores[e];
    }
    double *sum_exp = (double *)calloc(n, sizeof(double));
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        edge_alpha[e] = exp(edge_scores[e] - max_score[dst]);
        sum_exp[dst] += edge_alpha[e];
    }
    for (int e = 0; e < ne; e++) {
        int dst = g->edge_dst[e];
        edge_alpha[e] = (sum_exp[dst] > 1e-15) ? edge_alpha[e] / sum_exp[dst] : 1.0 / ne;
    }

    // === BACKWARD ===

    // grad_out is [n * od]: gradient w.r.t. h_dst[i][o]
    // h_dst[i][o] = sum_edges_to_i(alpha_e * Wr_x[src][o]) + bias[o]

    // d(loss)/d(bias[o]) = sum_i(grad_out[i*od+o])
    for (int i = 0; i < n; i++)
        for (int o = 0; o < od; o++)
            layer->dbias[o] += _gi2f(grad_out->data[i * od + o]);

    // d(loss)/d(alpha_e) = sum_o(grad_out[dst*od+o] * Wr_x[src][o])
    double *d_alpha = (double *)calloc(ne, sizeof(double));
    // d(loss)/d(Wr_x[src][o]) += alpha_e * grad_out[dst*od+o]
    double *d_Wr_x = (double *)calloc(n * od, sizeof(double));

    for (int e = 0; e < ne; e++) {
        int src = g->edge_src[e], dst = g->edge_dst[e];
        for (int o = 0; o < od; o++) {
            double go = _gi2f(grad_out->data[dst * od + o]);
            d_alpha[e] += go * Wr_x[src * od + o];
            d_Wr_x[src * od + o] += edge_alpha[e] * go;
        }
    }

    // Backprop through softmax: d(loss)/d(score_e) from d(loss)/d(alpha_e)
    // For softmax: d(alpha_e)/d(score_f) = alpha_e * (delta_ef - alpha_f) [same dst]
    double *d_score = (double *)calloc(ne, sizeof(double));
    // Simplified: d_score[e] = alpha[e] * (d_alpha[e] - sum_f_same_dst(alpha[f]*d_alpha[f]))
    // First compute dot[dst] = sum_f(alpha[f] * d_alpha[f]) for each dst
    double *dot_per_dst = (double *)calloc(n, sizeof(double));
    for (int e = 0; e < ne; e++)
        dot_per_dst[g->edge_dst[e]] += edge_alpha[e] * d_alpha[e];
    for (int e = 0; e < ne; e++)
        d_score[e] = edge_alpha[e] * (d_alpha[e] - dot_per_dst[g->edge_dst[e]]);

    // Backprop through score = a^T * LeakyReLU(Wl_x[src] + Wr_x[dst])
    // d(loss)/d(a[o]) += d_score[e] * leaky(val[e][o])
    // d(loss)/d(val[e][o]) = d_score[e] * a[o] * d(leaky)/d(val)
    double *d_Wl_x = (double *)calloc(n * od, sizeof(double));
    double *d_Wr_x_attn = (double *)calloc(n * od, sizeof(double)); // from attention path

    for (int e = 0; e < ne; e++) {
        int src = g->edge_src[e], dst = g->edge_dst[e];
        for (int o = 0; o < od; o++) {
            double val = leaky_vals[e * od + o];
            double leaky_val = (val < 0) ? val * 0.2 : val;
            double leaky_grad = (val < 0) ? 0.2 : 1.0;

            layer->da[o] += d_score[e] * leaky_val;
            double d_val = d_score[e] * layer->a[o] * leaky_grad;
            // val = Wl_x[src][o] + Wr_x[dst][o], so gradient splits
            d_Wl_x[src * od + o] += d_val;
            d_Wr_x_attn[dst * od + o] += d_val;
        }
    }

    // Combine d_Wr_x from aggregation path and attention path
    // d(loss)/d(W_r[o][j]) = sum_i(d_Wr_x_total[i][o] * x[i][j])
    // d(loss)/d(W_l[o][j]) = sum_i(d_Wl_x[i][o] * x[i][j])
    for (int i = 0; i < n; i++)
        for (int o = 0; o < od; o++) {
            double d_wr_total = d_Wr_x[i * od + o] + d_Wr_x_attn[i * od + o];
            for (int j = 0; j < id; j++) {
                layer->dW_r[o * id + j] += d_wr_total * g->node_feats[i * id + j];
                layer->dW_l[o * id + j] += d_Wl_x[i * od + o] * g->node_feats[i * id + j];
            }
        }

    // Gradient w.r.t. input node features: d(loss)/d(x[i][j])
    // = sum_o(d_Wr_x_total[i][o] * W_r[o][j] + d_Wl_x[i][o] * W_l[o][j])
    GVec *grad_input = (GVec *)malloc(sizeof(GVec));
    grad_input->len = n * id; grad_input->cap = n * id;
    grad_input->data = (long long *)malloc(n * id * sizeof(long long));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < id; j++) {
            double g_ij = 0;
            for (int o = 0; o < od; o++) {
                double d_wr_total = d_Wr_x[i * od + o] + d_Wr_x_attn[i * od + o];
                g_ij += d_wr_total * layer->W_r[o * id + j];
                g_ij += d_Wl_x[i * od + o] * layer->W_l[o * id + j];
            }
            grad_input->data[i * id + j] = _gf2i(g_ij);
        }

    free(Wl_x); free(Wr_x); free(edge_scores); free(leaky_vals);
    free(edge_alpha); free(max_score); free(sum_exp);
    free(d_alpha); free(d_Wr_x); free(d_score);
    free(dot_per_dst); free(d_Wl_x); free(d_Wr_x_attn);
    return (long long)grad_input;
}

// Adam step for GATv2 layer (update W_l, W_r, a, bias from accumulated gradients)
void nuc_gnn_gatv2_adam_step(long long layer_handle, long long opt_handle, long long offset) {
    GATv2Layer *l = (GATv2Layer *)(void *)layer_handle;
    typedef struct { int n_params; double lr, beta1, beta2, eps; double *m; double *v; int t; } NNAdam;
    NNAdam *opt = (NNAdam *)(void *)opt_handle;
    int id = l->in_dim, od = l->out_dim;
    int off = (int)offset;

    double bc1 = 1.0 - pow(opt->beta1, opt->t > 0 ? opt->t : 1);
    double bc2 = 1.0 - pow(opt->beta2, opt->t > 0 ? opt->t : 1);

    // Update W_l
    for (int i = 0; i < od * id; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dW_l[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dW_l[i] * l->dW_l[i];
        l->W_l[i] -= opt->lr * (opt->m[idx]/bc1) / (sqrt(opt->v[idx]/bc2) + opt->eps);
    }
    off += od * id;
    // Update W_r
    for (int i = 0; i < od * id; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dW_r[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dW_r[i] * l->dW_r[i];
        l->W_r[i] -= opt->lr * (opt->m[idx]/bc1) / (sqrt(opt->v[idx]/bc2) + opt->eps);
    }
    off += od * id;
    // Update a
    for (int i = 0; i < od; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->da[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->da[i] * l->da[i];
        l->a[i] -= opt->lr * (opt->m[idx]/bc1) / (sqrt(opt->v[idx]/bc2) + opt->eps);
    }
    off += od;
    // Update bias
    for (int i = 0; i < od; i++) {
        int idx = off + i;
        if (idx >= opt->n_params) break;
        opt->m[idx] = opt->beta1 * opt->m[idx] + (1.0 - opt->beta1) * l->dbias[i];
        opt->v[idx] = opt->beta2 * opt->v[idx] + (1.0 - opt->beta2) * l->dbias[i] * l->dbias[i];
        l->bias[i] -= opt->lr * (opt->m[idx]/bc1) / (sqrt(opt->v[idx]/bc2) + opt->eps);
    }
}

void nuc_gnn_gatv2_zero_grad(long long handle) {
    GATv2Layer *l = (GATv2Layer *)(void *)handle;
    memset(l->dW_l, 0, l->out_dim * l->in_dim * sizeof(double));
    memset(l->dW_r, 0, l->out_dim * l->in_dim * sizeof(double));
    memset(l->da, 0, l->out_dim * sizeof(double));
    memset(l->dbias, 0, l->out_dim * sizeof(double));
}

long long nuc_gnn_gatv2_param_count(long long handle) {
    GATv2Layer *l = (GATv2Layer *)(void *)handle;
    return (long long)(2 * l->out_dim * l->in_dim + l->out_dim + l->out_dim); // W_l + W_r + a + bias
}

// =====================================================
// GlobalAttention pooling
// gate_nn produces a scalar per node, softmax across nodes, weighted sum
// Input: node features [n_nodes * dim]
// gate: Linear(dim, 1) weights
// Output: single vector of dim
// =====================================================
typedef struct {
    int dim;
    double *gate_w;  // dim weights (Linear(dim, 1) without bias)
    double *dgate_w;
} GlobalAttnPool;

long long nuc_gnn_global_attn_new(long long dim) {
    int d = (int)dim;
    GlobalAttnPool *pool = (GlobalAttnPool *)calloc(1, sizeof(GlobalAttnPool));
    pool->dim = d;
    pool->gate_w = (double *)malloc(d * sizeof(double));
    pool->dgate_w = (double *)calloc(d, sizeof(double));
    for (int i = 0; i < d; i++)
        pool->gate_w[i] = gnn_rand_xavier(d, 1);
    return (long long)pool;
}

// Forward: node_feats_vec is flat [n_nodes * dim], returns [dim] aggregated
long long nuc_gnn_global_attn_forward(long long pool_handle, long long node_feats_vec, long long n_nodes) {
    GlobalAttnPool *pool = (GlobalAttnPool *)(void *)pool_handle;
    GVec *nfv = (GVec *)(void *)node_feats_vec;
    int n = (int)n_nodes, d = pool->dim;

    // Compute gate scores: score_i = gate_w^T * x_i
    double *scores = (double *)malloc(n * sizeof(double));
    double max_s = -1e30;
    for (int i = 0; i < n; i++) {
        double s = 0;
        for (int j = 0; j < d; j++)
            s += pool->gate_w[j] * _gi2f(nfv->data[i * d + j]);
        scores[i] = s;
        if (s > max_s) max_s = s;
    }

    // Softmax
    double sum_exp = 0;
    for (int i = 0; i < n; i++) {
        scores[i] = exp(scores[i] - max_s);
        sum_exp += scores[i];
    }
    for (int i = 0; i < n; i++)
        scores[i] /= sum_exp;

    // Weighted sum
    GVec *out = (GVec *)malloc(sizeof(GVec));
    out->len = d; out->cap = d;
    out->data = (long long *)malloc(d * sizeof(long long));
    for (int j = 0; j < d; j++) {
        double s = 0;
        for (int i = 0; i < n; i++)
            s += scores[i] * _gi2f(nfv->data[i * d + j]);
        out->data[j] = _gf2i(s);
    }

    free(scores);
    return (long long)out;
}

// =====================================================
// LayerNorm: normalize per-feature across a vector
// Input: [dim], Output: [dim] normalized to mean=0, var=1
// =====================================================
long long nuc_gnn_layer_norm(long long vec, long long dim) {
    GVec *v = (GVec *)(void *)vec;
    int d = (int)dim;
    double eps = 1e-5;

    // Compute mean and variance
    double mean = 0;
    for (int i = 0; i < d && i < v->len; i++)
        mean += _gi2f(v->data[i]);
    mean /= d;

    double var = 0;
    for (int i = 0; i < d && i < v->len; i++) {
        double diff = _gi2f(v->data[i]) - mean;
        var += diff * diff;
    }
    var /= d;

    double inv_std = 1.0 / sqrt(var + eps);

    GVec *out = (GVec *)malloc(sizeof(GVec));
    out->len = d; out->cap = d;
    out->data = (long long *)malloc(d * sizeof(long long));
    for (int i = 0; i < d; i++)
        out->data[i] = _gf2i((_gi2f(v->data[i]) - mean) * inv_std);
    return (long long)out;
}

// =====================================================
// Build circuit DAG graph for GNN
// Returns graph handle with 24-dim node features and qubit-wire edges
// =====================================================
long long nuc_gnn_circuit_to_graph(long long gates_vec, long long nq) {
    GVec *gates = (GVec *)(void *)gates_vec;
    int ng = gates->len / 3;  // gates stored as [type, q0, q1] triples
    int n_qubits = (int)nq;

    // Node features: 24-dim per gate
    // [gate_type_onehot(9), qubit_bits(12), is_2q(1), angle_norm(1), position_norm(1)]
    int feat_dim = 24;
    double *node_feats = (double *)calloc(ng * feat_dim, sizeof(double));

    // Edge construction: connect gates on same qubit wire
    int *qubit_last_gate = (int *)malloc(n_qubits * sizeof(int));
    for (int q = 0; q < n_qubits; q++) qubit_last_gate[q] = -1;

    int *esrc = (int *)malloc(ng * 2 * sizeof(int)); // max 2 edges per gate
    int *edst = (int *)malloc(ng * 2 * sizeof(int));
    int n_edges = 0;

    for (int gi = 0; gi < ng; gi++) {
        int gt = (int)gates->data[gi * 3];
        int q0 = (int)gates->data[gi * 3 + 1];
        int q1 = (int)gates->data[gi * 3 + 2];
        int is_2q = (q1 >= 0) ? 1 : 0;

        // One-hot gate type (9 types: H, CNOT, X, Z, RZ, RX, CP, ...)
        int offset = gi * feat_dim;
        if (gt >= 0 && gt < 9) node_feats[offset + gt] = 1.0;

        // Qubit bits (12 positions max)
        if (q0 >= 0 && q0 < 12) node_feats[offset + 9 + q0] = 1.0;
        if (q1 >= 0 && q1 < 12) node_feats[offset + 9 + q1] = 1.0;

        // is_2q, angle_norm, position_norm
        node_feats[offset + 21] = (double)is_2q;
        node_feats[offset + 22] = 0.5; // default angle (normalized)
        node_feats[offset + 23] = (ng > 1) ? (double)gi / (ng - 1) : 0;

        // Edges: connect from last gate on same qubit(s)
        if (q0 >= 0 && q0 < n_qubits && qubit_last_gate[q0] >= 0) {
            esrc[n_edges] = qubit_last_gate[q0];
            edst[n_edges] = gi;
            n_edges++;
        }
        if (q0 >= 0 && q0 < n_qubits) qubit_last_gate[q0] = gi;

        if (is_2q && q1 >= 0 && q1 < n_qubits) {
            if (qubit_last_gate[q1] >= 0) {
                esrc[n_edges] = qubit_last_gate[q1];
                edst[n_edges] = gi;
                n_edges++;
            }
            qubit_last_gate[q1] = gi;
        }
    }

    // Build Graph struct
    Graph *g = (Graph *)calloc(1, sizeof(Graph));
    g->n_nodes = ng;
    g->feat_dim = feat_dim;
    g->node_feats = node_feats;
    g->n_edges = n_edges;
    g->edge_src = (int *)malloc(n_edges * sizeof(int));
    g->edge_dst = (int *)malloc(n_edges * sizeof(int));
    memcpy(g->edge_src, esrc, n_edges * sizeof(int));
    memcpy(g->edge_dst, edst, n_edges * sizeof(int));

    free(qubit_last_gate); free(esrc); free(edst);
    return (long long)g;
}

// Get graph node count
long long nuc_gnn_graph_n_nodes(long long handle) {
    Graph *g = (Graph *)(void *)handle;
    return g ? g->n_nodes : 0;
}

// global_mean_pool: average all node features into one vector
long long nuc_gnn_global_mean_pool(long long node_feats_vec, long long n_nodes, long long dim) {
    GVec *nfv = (GVec *)(void *)node_feats_vec;
    int n = (int)n_nodes, d = (int)dim;

    GVec *out = (GVec *)malloc(sizeof(GVec));
    out->len = d; out->cap = d;
    out->data = (long long *)malloc(d * sizeof(long long));

    for (int j = 0; j < d; j++) {
        double s = 0;
        for (int i = 0; i < n; i++)
            s += _gi2f(nfv->data[i * d + j]);
        out->data[j] = _gf2i(s / n);
    }
    return (long long)out;
}

// ReLU on flat vector (element-wise)
long long nuc_gnn_relu(long long vec) {
    GVec *v = (GVec *)(void *)vec;
    GVec *out = (GVec *)malloc(sizeof(GVec));
    out->len = v->len; out->cap = v->len;
    out->data = (long long *)malloc(out->cap * sizeof(long long));
    for (int i = 0; i < v->len; i++) {
        double x = _gi2f(v->data[i]);
        out->data[i] = _gf2i(x > 0 ? x : 0);
    }
    return (long long)out;
}
