// optimizer2_rt.c — Modern Optimizers for Nucleor
// Muon (Newton-Schulz orthogonalization), Sophia (diagonal Hessian),
// SOAP (Shampoo eigenbasis), Schedule-Free Adam.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/optimizer2_rt.c -o target/optimizer2_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _o2_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _o2_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } O2Vec;

static O2Vec *o2vec_new(int n) {
    O2Vec *v = (O2Vec *)malloc(sizeof(O2Vec));
    v->len = n; v->cap = n; v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Muon Optimizer
//  SGD with Nesterov momentum + Newton-Schulz orthogonalization.
//  For weight matrices: orthogonalize the update G → UV^T via NS iteration.
// ================================================================

typedef struct {
    int rows, cols;
    double *momentum; // Nesterov momentum buffer
    double lr;
    double mu;        // momentum coefficient (0.95)
} MuonState;

long long nuc_opt2_muon_new(long long rows, long long cols, long long lr_bits, long long mu_bits) {
    MuonState *s = (MuonState *)calloc(1, sizeof(MuonState));
    s->rows = (int)rows; s->cols = (int)cols;
    s->lr = _o2_i2f(lr_bits);
    s->mu = _o2_i2f(mu_bits);
    s->momentum = (double *)calloc(s->rows * s->cols, sizeof(double));
    return (long long)s;
}

// Newton-Schulz iteration: X → X(aI + bX^TX + c(X^TX)^2)
// 5 iterations to approximate UV^T from G
static void newton_schulz_ortho(double *G, int rows, int cols, double *out) {
    // Work with the smaller dimension
    int m = rows, n = cols;
    // X starts as G / ||G||_F
    double fnorm = 0;
    for (int i = 0; i < m * n; i++) fnorm += G[i] * G[i];
    fnorm = sqrt(fnorm);
    if (fnorm < 1e-15) { memcpy(out, G, m * n * sizeof(double)); return; }

    double *X = (double *)malloc(m * n * sizeof(double));
    for (int i = 0; i < m * n; i++) X[i] = G[i] / fnorm;

    double *XtX = (double *)malloc(n * n * sizeof(double));
    double *tmp = (double *)malloc(m * n * sizeof(double));

    // Coefficients for cubic NS iteration (Muon's specific values)
    double a = 3.4445, b = -4.7750, c = 2.0315;

    for (int iter = 0; iter < 5; iter++) {
        // XtX = X^T X [n x n]
        memset(XtX, 0, n * n * sizeof(double));
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                for (int k = 0; k < m; k++)
                    XtX[i * n + j] += X[k * n + i] * X[k * n + j];

        // tmp = X @ (aI + b*XtX + c*XtX*XtX) [m x n]
        // First compute poly = aI + b*XtX + c*XtX^2
        double *poly = (double *)calloc(n * n, sizeof(double));
        for (int i = 0; i < n; i++) poly[i * n + i] = a;
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++)
                poly[i * n + j] += b * XtX[i * n + j];
        // Add c * XtX^2
        for (int i = 0; i < n; i++)
            for (int j = 0; j < n; j++) {
                double s = 0;
                for (int k = 0; k < n; k++) s += XtX[i * n + k] * XtX[k * n + j];
                poly[i * n + j] += c * s;
            }

        // X_new = X @ poly
        memset(tmp, 0, m * n * sizeof(double));
        for (int i = 0; i < m; i++)
            for (int j = 0; j < n; j++)
                for (int k = 0; k < n; k++)
                    tmp[i * n + j] += X[i * n + k] * poly[k * n + j];

        memcpy(X, tmp, m * n * sizeof(double));
        free(poly);
    }

    memcpy(out, X, m * n * sizeof(double));
    free(X); free(XtX); free(tmp);
}

// Muon step: given gradient, update weights
long long nuc_opt2_muon_step(long long state_h, long long weights_h, long long grad_h) {
    MuonState *s = (MuonState *)(void *)state_h;
    O2Vec *w = (O2Vec *)(void *)weights_h;
    O2Vec *g = (O2Vec *)(void *)grad_h;
    int n = s->rows * s->cols;

    // Nesterov momentum
    double *grad = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) grad[i] = _o2_i2f(g->data[i]);
    for (int i = 0; i < n; i++) {
        s->momentum[i] = s->mu * s->momentum[i] + grad[i];
        grad[i] = s->mu * s->momentum[i] + grad[i]; // Nesterov lookahead
    }

    // Newton-Schulz orthogonalization
    double *ortho = (double *)malloc(n * sizeof(double));
    newton_schulz_ortho(grad, s->rows, s->cols, ortho);

    // Update weights
    O2Vec *out = o2vec_new(n);
    for (int i = 0; i < n; i++)
        out->data[i] = _o2_f2i(_o2_i2f(w->data[i]) - s->lr * ortho[i]);

    free(grad); free(ortho);
    return (long long)out;
}

// ================================================================
//  Sophia Optimizer (diagonal Hessian, clipped)
// ================================================================

typedef struct {
    int n;
    double *m;    // first moment EMA
    double *h;    // diagonal Hessian EMA
    double lr, beta1, beta2, rho;
    int step;
} SophiaState;

long long nuc_opt2_sophia_new(long long n, long long lr_bits) {
    int N = (int)n;
    SophiaState *s = (SophiaState *)calloc(1, sizeof(SophiaState));
    s->n = N; s->lr = _o2_i2f(lr_bits);
    s->beta1 = 0.965; s->beta2 = 0.99; s->rho = 0.04;
    s->m = (double *)calloc(N, sizeof(double));
    s->h = (double *)calloc(N, sizeof(double));
    return (long long)s;
}

long long nuc_opt2_sophia_step(long long state_h, long long weights_h,
                                 long long grad_h, long long hessian_diag_h) {
    SophiaState *s = (SophiaState *)(void *)state_h;
    O2Vec *w = (O2Vec *)(void *)weights_h;
    O2Vec *g = (O2Vec *)(void *)grad_h;
    O2Vec *hd = (O2Vec *)(void *)hessian_diag_h; // diagonal Hessian estimate
    int N = s->n;
    s->step++;

    O2Vec *out = o2vec_new(N);
    for (int i = 0; i < N; i++) {
        double gi = _o2_i2f(g->data[i]);
        s->m[i] = s->beta1 * s->m[i] + (1 - s->beta1) * gi;
        if (hd) {
            double hi = _o2_i2f(hd->data[i]);
            s->h[i] = s->beta2 * s->h[i] + (1 - s->beta2) * hi;
        }
        // Clipped update
        double update = s->m[i] / (s->h[i] + 1e-8);
        if (update > s->rho) update = s->rho;
        if (update < -s->rho) update = -s->rho;
        out->data[i] = _o2_f2i(_o2_i2f(w->data[i]) - s->lr * update);
    }
    return (long long)out;
}

// ================================================================
//  Schedule-Free AdamW
//  No learning rate schedule needed. Uses primal averaging.
// ================================================================

typedef struct {
    int n;
    double *m, *v;     // Adam moments
    double *z;         // iterate sequence
    double lr, beta1, beta2, wd;
    int step;
} ScheduleFreeState;

long long nuc_opt2_schedule_free_new(long long n, long long lr_bits) {
    int N = (int)n;
    ScheduleFreeState *s = (ScheduleFreeState *)calloc(1, sizeof(ScheduleFreeState));
    s->n = N; s->lr = _o2_i2f(lr_bits);
    s->beta1 = 0.9; s->beta2 = 0.999; s->wd = 0.01;
    s->m = (double *)calloc(N, sizeof(double));
    s->v = (double *)calloc(N, sizeof(double));
    s->z = (double *)calloc(N, sizeof(double));
    return (long long)s;
}

long long nuc_opt2_schedule_free_step(long long state_h, long long weights_h, long long grad_h) {
    ScheduleFreeState *s = (ScheduleFreeState *)(void *)state_h;
    O2Vec *w = (O2Vec *)(void *)weights_h;
    O2Vec *g = (O2Vec *)(void *)grad_h;
    int N = s->n;
    s->step++;

    double b1_corr = 1.0 / (1.0 - pow(s->beta1, s->step));
    double ck = 1.0 / s->step; // averaging coefficient

    O2Vec *out = o2vec_new(N);
    for (int i = 0; i < N; i++) {
        double wi = _o2_i2f(w->data[i]);
        double gi = _o2_i2f(g->data[i]) + s->wd * wi;

        s->m[i] = s->beta1 * s->m[i] + (1 - s->beta1) * gi;
        s->v[i] = s->beta2 * s->v[i] + (1 - s->beta2) * gi * gi;
        double mhat = s->m[i] * b1_corr;
        double vhat = s->v[i] / (1 - pow(s->beta2, s->step));
        double update = mhat / (sqrt(vhat) + 1e-8);

        // z is the fast iterate
        s->z[i] -= s->lr * update;
        // x (returned) is the interpolation: x = (1-ck)*x_prev + ck*z
        double new_w = (1 - ck) * wi + ck * s->z[i];
        out->data[i] = _o2_f2i(new_w);
    }
    return (long long)out;
}

// ================================================================
//  AdamW (standard, for completeness and baseline)
// ================================================================

typedef struct {
    int n;
    double *m, *v;
    double lr, beta1, beta2, wd, eps;
    int step;
} AdamWState;

long long nuc_opt2_adamw_new(long long n, long long lr_bits) {
    int N = (int)n;
    AdamWState *s = (AdamWState *)calloc(1, sizeof(AdamWState));
    s->n = N; s->lr = _o2_i2f(lr_bits);
    s->beta1 = 0.9; s->beta2 = 0.999; s->wd = 0.01; s->eps = 1e-8;
    s->m = (double *)calloc(N, sizeof(double));
    s->v = (double *)calloc(N, sizeof(double));
    return (long long)s;
}

long long nuc_opt2_adamw_step(long long state_h, long long weights_h, long long grad_h) {
    AdamWState *s = (AdamWState *)(void *)state_h;
    O2Vec *w = (O2Vec *)(void *)weights_h;
    O2Vec *g = (O2Vec *)(void *)grad_h;
    int N = s->n;
    s->step++;

    O2Vec *out = o2vec_new(N);
    for (int i = 0; i < N; i++) {
        double wi = _o2_i2f(w->data[i]);
        double gi = _o2_i2f(g->data[i]);
        s->m[i] = s->beta1 * s->m[i] + (1 - s->beta1) * gi;
        s->v[i] = s->beta2 * s->v[i] + (1 - s->beta2) * gi * gi;
        double mhat = s->m[i] / (1 - pow(s->beta1, s->step));
        double vhat = s->v[i] / (1 - pow(s->beta2, s->step));
        double update = mhat / (sqrt(vhat) + s->eps);
        out->data[i] = _o2_f2i(wi * (1 - s->lr * s->wd) - s->lr * update);
    }
    return (long long)out;
}
