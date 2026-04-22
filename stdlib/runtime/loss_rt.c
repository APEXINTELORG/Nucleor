// loss_rt.c — Loss Functions for Nucleor
// Cross-entropy, KL divergence, MSE, focal, contrastive, InfoNCE, label smoothing.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/loss_rt.c -o target/loss_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ls_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ls_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } LSVec;

// ================================================================
//  Cross-Entropy Loss (with softmax fusion)
// ================================================================

long long nuc_loss_cross_entropy(long long logits_h, long long target) {
    LSVec *logits = (LSVec *)(void *)logits_h;
    int n = logits->len, t = (int)target;
    double max_val = _ls_i2f(logits->data[0]);
    for (int i = 1; i < n; i++) { double v = _ls_i2f(logits->data[i]); if (v > max_val) max_val = v; }
    double sum_exp = 0;
    for (int i = 0; i < n; i++) sum_exp += exp(_ls_i2f(logits->data[i]) - max_val);
    double loss = -((_ls_i2f(logits->data[t]) - max_val) - log(sum_exp));
    return _ls_f2i(loss);
}

// ================================================================
//  Cross-Entropy Gradient (returns Vec of gradients w.r.t. logits)
// ================================================================

long long nuc_loss_cross_entropy_grad(long long logits_h, long long target) {
    LSVec *logits = (LSVec *)(void *)logits_h;
    int n = logits->len, t = (int)target;
    double max_val = _ls_i2f(logits->data[0]);
    for (int i = 1; i < n; i++) { double v = _ls_i2f(logits->data[i]); if (v > max_val) max_val = v; }
    double sum_exp = 0;
    for (int i = 0; i < n; i++) sum_exp += exp(_ls_i2f(logits->data[i]) - max_val);

    LSVec *grad = (LSVec *)malloc(sizeof(LSVec));
    grad->len = n; grad->cap = n; grad->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++) {
        double p = exp(_ls_i2f(logits->data[i]) - max_val) / sum_exp;
        grad->data[i] = _ls_f2i(p - (i == t ? 1.0 : 0.0));
    }
    return (long long)grad;
}

// ================================================================
//  Label Smoothing Cross-Entropy
// ================================================================

long long nuc_loss_label_smooth_ce(long long logits_h, long long target, long long epsilon_bits) {
    LSVec *logits = (LSVec *)(void *)logits_h;
    int n = logits->len, t = (int)target;
    double eps = _ls_i2f(epsilon_bits);
    double max_val = _ls_i2f(logits->data[0]);
    for (int i = 1; i < n; i++) { double v = _ls_i2f(logits->data[i]); if (v > max_val) max_val = v; }
    double sum_exp = 0;
    for (int i = 0; i < n; i++) sum_exp += exp(_ls_i2f(logits->data[i]) - max_val);
    double log_sum = max_val + log(sum_exp);

    double loss = 0;
    for (int i = 0; i < n; i++) {
        double target_p = (i == t) ? (1.0 - eps) : eps / (n - 1);
        double log_p = _ls_i2f(logits->data[i]) - log_sum;
        loss -= target_p * log_p;
    }
    return _ls_f2i(loss);
}

// ================================================================
//  KL Divergence: KL(P || Q) = sum(P * log(P/Q))
// ================================================================

long long nuc_loss_kl_divergence(long long p_h, long long q_h) {
    LSVec *p = (LSVec *)(void *)p_h, *q = (LSVec *)(void *)q_h;
    int n = p->len < q->len ? p->len : q->len;
    double kl = 0;
    for (int i = 0; i < n; i++) {
        double pi = _ls_i2f(p->data[i]), qi = _ls_i2f(q->data[i]);
        if (pi > 1e-15 && qi > 1e-15) kl += pi * log(pi / qi);
    }
    return _ls_f2i(kl);
}

// ================================================================
//  MSE (Mean Squared Error)
// ================================================================

long long nuc_loss_mse(long long pred_h, long long target_h) {
    LSVec *pred = (LSVec *)(void *)pred_h, *target = (LSVec *)(void *)target_h;
    int n = pred->len < target->len ? pred->len : target->len;
    double sum = 0;
    for (int i = 0; i < n; i++) {
        double d = _ls_i2f(pred->data[i]) - _ls_i2f(target->data[i]);
        sum += d * d;
    }
    return _ls_f2i(sum / n);
}

// ================================================================
//  Huber Loss (smooth L1)
// ================================================================

long long nuc_loss_huber(long long pred_h, long long target_h, long long delta_bits) {
    LSVec *pred = (LSVec *)(void *)pred_h, *target = (LSVec *)(void *)target_h;
    double delta = _ls_i2f(delta_bits);
    int n = pred->len < target->len ? pred->len : target->len;
    double sum = 0;
    for (int i = 0; i < n; i++) {
        double d = fabs(_ls_i2f(pred->data[i]) - _ls_i2f(target->data[i]));
        sum += (d <= delta) ? 0.5 * d * d : delta * (d - 0.5 * delta);
    }
    return _ls_f2i(sum / n);
}

// ================================================================
//  Focal Loss (for class imbalance)
//  FL(p) = -alpha * (1-p)^gamma * log(p)
// ================================================================

long long nuc_loss_focal(long long logits_h, long long target,
                          long long alpha_bits, long long gamma_bits) {
    LSVec *logits = (LSVec *)(void *)logits_h;
    int n = logits->len, t = (int)target;
    double alpha = _ls_i2f(alpha_bits), gamma = _ls_i2f(gamma_bits);

    double max_val = _ls_i2f(logits->data[0]);
    for (int i = 1; i < n; i++) { double v = _ls_i2f(logits->data[i]); if (v > max_val) max_val = v; }
    double sum_exp = 0;
    for (int i = 0; i < n; i++) sum_exp += exp(_ls_i2f(logits->data[i]) - max_val);
    double pt = exp(_ls_i2f(logits->data[t]) - max_val) / sum_exp;

    double loss = -alpha * pow(1.0 - pt, gamma) * log(pt + 1e-10);
    return _ls_f2i(loss);
}

// ================================================================
//  InfoNCE / Contrastive Loss
//  sim_matrix: [batch, batch] cosine similarities
//  Positive pairs are on the diagonal.
// ================================================================

long long nuc_loss_infonce(long long sim_matrix_h, long long batch_size, long long temperature_bits) {
    LSVec *sim = (LSVec *)(void *)sim_matrix_h;
    int bs = (int)batch_size;
    double temp = _ls_i2f(temperature_bits);
    if (temp <= 0) temp = 0.07;

    double total_loss = 0;
    for (int i = 0; i < bs; i++) {
        double max_s = -1e30;
        for (int j = 0; j < bs; j++) {
            double s = _ls_i2f(sim->data[i * bs + j]) / temp;
            if (s > max_s) max_s = s;
        }
        double log_sum = 0;
        for (int j = 0; j < bs; j++)
            log_sum += exp(_ls_i2f(sim->data[i * bs + j]) / temp - max_s);
        double positive = _ls_i2f(sim->data[i * bs + i]) / temp;
        total_loss += -(positive - max_s - log(log_sum));
    }
    return _ls_f2i(total_loss / bs);
}

// ================================================================
//  Cosine Similarity Matrix (for contrastive learning)
// ================================================================

long long nuc_loss_cosine_sim_matrix(long long a_h, long long b_h, long long n, long long dim) {
    LSVec *a = (LSVec *)(void *)a_h, *b = (LSVec *)(void *)b_h;
    int N = (int)n, D = (int)dim;
    LSVec *sim = (LSVec *)malloc(sizeof(LSVec));
    sim->len = N * N; sim->cap = sim->len;
    sim->data = (long long *)malloc(sim->len * sizeof(long long));

    for (int i = 0; i < N; i++) {
        double na = 0;
        for (int k = 0; k < D; k++) { double v = _ls_i2f(a->data[i * D + k]); na += v * v; }
        na = sqrt(na);
        for (int j = 0; j < N; j++) {
            double dot = 0, nb = 0;
            for (int k = 0; k < D; k++) {
                double ai = _ls_i2f(a->data[i * D + k]);
                double bj = _ls_i2f(b->data[j * D + k]);
                dot += ai * bj;
                nb += bj * bj;
            }
            nb = sqrt(nb);
            sim->data[i * N + j] = _ls_f2i((na > 1e-10 && nb > 1e-10) ? dot / (na * nb) : 0);
        }
    }
    return (long long)sim;
}
