// attention2_rt.c — Modern Attention Mechanisms for Nucleor
// FlashAttention-style tiled attention with online softmax, GQA, MLA,
// sliding window, differential attention.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/attention2_rt.c -o target/attention2_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _a2_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _a2_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } A2Vec;

static A2Vec *a2vec_new(int n) {
    A2Vec *v = (A2Vec *)malloc(sizeof(A2Vec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Online Softmax State (for tiled attention)
// ================================================================

typedef struct {
    double *row_max;  // running max per query row
    double *row_sum;  // running sum of exp per row
    double *output;   // accumulated output
} OnlineSoftmaxState;

// ================================================================
//  FlashAttention-style Tiled Attention
//  Q: [seq_q, d], K: [seq_k, d], V: [seq_k, d]
//  Computes attention with O(seq_q * d) memory instead of O(seq_q * seq_k)
// ================================================================

long long nuc_attn_flash(long long Q_h, long long K_h, long long V_h,
                          long long seq_q, long long seq_k, long long d,
                          long long block_size) {
    A2Vec *Q = (A2Vec *)(void *)Q_h;
    A2Vec *K = (A2Vec *)(void *)K_h;
    A2Vec *V = (A2Vec *)(void *)V_h;
    int sq = (int)seq_q, sk = (int)seq_k, dim = (int)d, bs = (int)block_size;
    if (bs < 1) bs = 32;
    double scale = 1.0 / sqrt((double)dim);

    double *O = (double *)calloc(sq * dim, sizeof(double));
    double *row_max = (double *)malloc(sq * sizeof(double));
    double *row_sum = (double *)calloc(sq, sizeof(double));
    for (int i = 0; i < sq; i++) row_max[i] = -1e30;

    // Iterate over KV blocks
    for (int j0 = 0; j0 < sk; j0 += bs) {
        int j_end = j0 + bs; if (j_end > sk) j_end = sk;
        int bk = j_end - j0;

        // For each Q block
        for (int i0 = 0; i0 < sq; i0 += bs) {
            int i_end = i0 + bs; if (i_end > sq) i_end = sq;

            for (int i = i0; i < i_end; i++) {
                double prev_max = row_max[i];
                double block_max = -1e30;

                // Compute scores for this Q row against this K block
                double *scores = (double *)malloc(bk * sizeof(double));
                for (int j = 0; j < bk; j++) {
                    double dot = 0;
                    for (int k = 0; k < dim; k++)
                        dot += _a2_i2f(Q->data[i * dim + k]) * _a2_i2f(K->data[(j0 + j) * dim + k]);
                    scores[j] = dot * scale;
                    if (scores[j] > block_max) block_max = scores[j];
                }

                // Online softmax update
                double new_max = prev_max > block_max ? prev_max : block_max;
                double rescale = exp(prev_max - new_max);
                double block_sum = 0;

                for (int j = 0; j < bk; j++) {
                    double p = exp(scores[j] - new_max);
                    block_sum += p;
                    // Accumulate weighted V
                    for (int k = 0; k < dim; k++)
                        O[i * dim + k] = O[i * dim + k] * (j == 0 && j0 == 0 ? 0 : 1) + 0; // handled below
                }

                // Proper rescale: O = O * (old_sum * rescale / new_sum) + new_block / new_sum
                double old_sum_rescaled = row_sum[i] * rescale;
                double new_total = old_sum_rescaled + block_sum;

                // Rescale existing output
                if (old_sum_rescaled > 0) {
                    double r = old_sum_rescaled / new_total;
                    for (int k = 0; k < dim; k++) O[i * dim + k] *= r;
                }

                // Add new block contribution
                double inv_total = 1.0 / new_total;
                for (int j = 0; j < bk; j++) {
                    double p = exp(scores[j] - new_max) * inv_total;
                    for (int k = 0; k < dim; k++)
                        O[i * dim + k] += p * _a2_i2f(V->data[(j0 + j) * dim + k]);
                }

                row_max[i] = new_max;
                row_sum[i] = new_total;
                free(scores);
            }
        }
    }

    A2Vec *result = a2vec_new(sq * dim);
    for (int i = 0; i < sq * dim; i++) result->data[i] = _a2_f2i(O[i]);
    free(O); free(row_max); free(row_sum);
    return (long long)result;
}

// ================================================================
//  Grouped Query Attention (GQA)
//  n_q_heads Q heads share n_kv_heads KV heads
// ================================================================

long long nuc_attn_gqa(long long Q_h, long long K_h, long long V_h,
                        long long seq_q, long long seq_k, long long head_dim,
                        long long n_q_heads, long long n_kv_heads) {
    A2Vec *Q = (A2Vec *)(void *)Q_h; // [seq_q, n_q_heads * head_dim]
    A2Vec *K = (A2Vec *)(void *)K_h; // [seq_k, n_kv_heads * head_dim]
    A2Vec *V = (A2Vec *)(void *)V_h;
    int sq = (int)seq_q, sk = (int)seq_k, hd = (int)head_dim;
    int nq = (int)n_q_heads, nkv = (int)n_kv_heads;
    int group_size = nq / nkv;
    double scale = 1.0 / sqrt((double)hd);

    A2Vec *out = a2vec_new(sq * nq * hd);

    for (int h = 0; h < nq; h++) {
        int kv_h = h / group_size; // which KV head to use

        for (int i = 0; i < sq; i++) {
            // Compute attention scores
            double max_s = -1e30;
            double *scores = (double *)malloc(sk * sizeof(double));
            for (int j = 0; j < sk; j++) {
                double dot = 0;
                for (int k = 0; k < hd; k++)
                    dot += _a2_i2f(Q->data[i * nq * hd + h * hd + k]) *
                           _a2_i2f(K->data[j * nkv * hd + kv_h * hd + k]);
                scores[j] = dot * scale;
                if (scores[j] > max_s) max_s = scores[j];
            }

            double sum_exp = 0;
            for (int j = 0; j < sk; j++) { scores[j] = exp(scores[j] - max_s); sum_exp += scores[j]; }
            for (int j = 0; j < sk; j++) scores[j] /= sum_exp;

            for (int k = 0; k < hd; k++) {
                double val = 0;
                for (int j = 0; j < sk; j++)
                    val += scores[j] * _a2_i2f(V->data[j * nkv * hd + kv_h * hd + k]);
                out->data[i * nq * hd + h * hd + k] = _a2_f2i(val);
            }
            free(scores);
        }
    }
    return (long long)out;
}

// ================================================================
//  Multi-Head Latent Attention (MLA) — DeepSeek-V2 style
//  Compresses KV into low-rank latent, caches latent instead of full KV
// ================================================================

long long nuc_attn_mla_compress(long long hidden_h, long long W_down_h,
                                  long long d_model, long long d_latent) {
    A2Vec *h = (A2Vec *)(void *)hidden_h;
    A2Vec *Wd = (A2Vec *)(void *)W_down_h; // [d_latent, d_model]
    int dm = (int)d_model, dl = (int)d_latent;
    int seq = h->len / dm;

    A2Vec *latent = a2vec_new(seq * dl);
    for (int t = 0; t < seq; t++) {
        for (int i = 0; i < dl; i++) {
            double sum = 0;
            for (int j = 0; j < dm; j++)
                sum += _a2_i2f(Wd->data[i * dm + j]) * _a2_i2f(h->data[t * dm + j]);
            latent->data[t * dl + i] = _a2_f2i(sum);
        }
    }
    return (long long)latent;
}

long long nuc_attn_mla_decompress(long long latent_h, long long W_up_h,
                                    long long d_latent, long long d_out) {
    A2Vec *lat = (A2Vec *)(void *)latent_h;
    A2Vec *Wu = (A2Vec *)(void *)W_up_h; // [d_out, d_latent]
    int dl = (int)d_latent, dout = (int)d_out;
    int seq = lat->len / dl;

    A2Vec *out = a2vec_new(seq * dout);
    for (int t = 0; t < seq; t++) {
        for (int i = 0; i < dout; i++) {
            double sum = 0;
            for (int j = 0; j < dl; j++)
                sum += _a2_i2f(Wu->data[i * dl + j]) * _a2_i2f(lat->data[t * dl + j]);
            out->data[t * dout + i] = _a2_f2i(sum);
        }
    }
    return (long long)out;
}

// ================================================================
//  Sliding Window Attention
// ================================================================

long long nuc_attn_sliding_window(long long Q_h, long long K_h, long long V_h,
                                    long long seq_len, long long d, long long window_size) {
    A2Vec *Q = (A2Vec *)(void *)Q_h;
    A2Vec *K = (A2Vec *)(void *)K_h;
    A2Vec *V = (A2Vec *)(void *)V_h;
    int sl = (int)seq_len, dim = (int)d, W = (int)window_size;
    double scale = 1.0 / sqrt((double)dim);

    A2Vec *out = a2vec_new(sl * dim);

    for (int i = 0; i < sl; i++) {
        int j_start = (i - W + 1 > 0) ? i - W + 1 : 0;
        int j_end = i + 1; // causal
        int n_keys = j_end - j_start;

        double max_s = -1e30;
        double *scores = (double *)malloc(n_keys * sizeof(double));
        for (int jj = 0; jj < n_keys; jj++) {
            int j = j_start + jj;
            double dot = 0;
            for (int k = 0; k < dim; k++)
                dot += _a2_i2f(Q->data[i * dim + k]) * _a2_i2f(K->data[j * dim + k]);
            scores[jj] = dot * scale;
            if (scores[jj] > max_s) max_s = scores[jj];
        }

        double sum_exp = 0;
        for (int jj = 0; jj < n_keys; jj++) { scores[jj] = exp(scores[jj] - max_s); sum_exp += scores[jj]; }
        for (int jj = 0; jj < n_keys; jj++) scores[jj] /= sum_exp;

        for (int k = 0; k < dim; k++) {
            double val = 0;
            for (int jj = 0; jj < n_keys; jj++)
                val += scores[jj] * _a2_i2f(V->data[(j_start + jj) * dim + k]);
            out->data[i * dim + k] = _a2_f2i(val);
        }
        free(scores);
    }
    return (long long)out;
}

// ================================================================
//  Differential Attention (Microsoft ICLR 2025)
//  attn = softmax(Q1*K1^T) - lambda * softmax(Q2*K2^T)
// ================================================================

long long nuc_attn_differential(long long Q_h, long long K_h, long long V_h,
                                  long long seq_len, long long d, long long lambda_bits) {
    A2Vec *Q = (A2Vec *)(void *)Q_h; // [seq, d] where first d/2 = Q1, second d/2 = Q2
    A2Vec *K = (A2Vec *)(void *)K_h;
    A2Vec *V = (A2Vec *)(void *)V_h;
    int sl = (int)seq_len, dim = (int)d;
    int half_d = dim / 2;
    double lambda = _a2_i2f(lambda_bits);
    double scale = 1.0 / sqrt((double)half_d);

    A2Vec *out = a2vec_new(sl * half_d);

    for (int i = 0; i < sl; i++) {
        double *a1 = (double *)malloc(sl * sizeof(double));
        double *a2 = (double *)malloc(sl * sizeof(double));

        // Compute two attention maps
        double max1 = -1e30, max2 = -1e30;
        for (int j = 0; j <= i; j++) { // causal
            double d1 = 0, d2 = 0;
            for (int k = 0; k < half_d; k++) {
                d1 += _a2_i2f(Q->data[i * dim + k]) * _a2_i2f(K->data[j * dim + k]);
                d2 += _a2_i2f(Q->data[i * dim + half_d + k]) * _a2_i2f(K->data[j * dim + half_d + k]);
            }
            a1[j] = d1 * scale; a2[j] = d2 * scale;
            if (a1[j] > max1) max1 = a1[j];
            if (a2[j] > max2) max2 = a2[j];
        }

        double s1 = 0, s2 = 0;
        for (int j = 0; j <= i; j++) {
            a1[j] = exp(a1[j] - max1); s1 += a1[j];
            a2[j] = exp(a2[j] - max2); s2 += a2[j];
        }
        for (int j = 0; j <= i; j++) { a1[j] /= s1; a2[j] /= s2; }

        // Differential: a1 - lambda * a2
        for (int k = 0; k < half_d; k++) {
            double val = 0;
            for (int j = 0; j <= i; j++)
                val += (a1[j] - lambda * a2[j]) * _a2_i2f(V->data[j * half_d + k]);
            out->data[i * half_d + k] = _a2_f2i(val);
        }
        free(a1); free(a2);
    }
    return (long long)out;
}
