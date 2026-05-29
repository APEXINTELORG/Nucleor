// mppi_rt.c — Model Predictive Path Integral control (Williams,
// Aldrich & Theodorou 2016/2017).
//
// Sample-based MPC variant: at each control tick, sample `K`
// noisy control sequences, roll them out through the dynamics,
// score them by stage + terminal cost, weight them by `exp(−J/λ)`,
// and use the weighted average as the new nominal sequence. Output
// the first control of the nominal, then shift.
//
// No gradient required — works with arbitrary non-smooth
// dynamics and costs (binary obstacle indicator costs, friction
// stick-slip transitions, etc.) where iLQR / DDP would fail.
// Naturally embarrassingly parallel (each sample is independent),
// though this implementation runs sequentially.
//
// Algorithm per tick:
//
//   for k = 1..K:
//     ε_k[t] ~ N(0, Σ)     (per-component noise)
//     u_k[t] = u_seq[t] + ε_k[t]    (perturbed sequence)
//     roll out under dynamics → cost J_k
//   w_k = exp(−(J_k − J_min) / λ)
//   w_k /= Σ_j w_j
//   u_seq[t] ← Σ_k w_k · u_k[t]
//   output u_seq[0], shift by 1
//
// Tuning:
//   - K: number of samples per tick. 256–4096 typical. Higher = more
//     accurate weighted average; lower = faster but noisier.
//   - λ: temperature. Lower = more aggressive (favors best samples
//     more strongly); higher = smoother averaging.
//   - σ: noise std-dev per control dim. Set comparable to the
//     expected control magnitude.
//
// Limitations (importance-sampling tricks / GPU / smoothing
// land in v0.6 if needed):
// - Single-threaded sequential sampling; for serious use parallelize
//   externally.
// - Diagonal (per-dim) σ only.
// - No control bounds enforcement (clamp inside user's dynamics if
//   needed, or use `cilqr.nr` for hard bounds).
//
// Compile: clang -c stdlib/runtime/mppi_rt.c -o target/mppi.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*mppi_dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*mppi_cost_fn_t)(long long x_ptr, long long u_ptr);
typedef long long (*mppi_tcost_fn_t)(long long x_ptr);

typedef struct {
    int n_x, n_u, T, K;
    double lambda;
    double *sigma;       // n_u (per-dim std-dev)
    double *u_seq;       // T * n_u
    long long dyn_fp, sc_fp, tc_fp;
    int has_callbacks;
    unsigned long long rng;
    // Scratch buffers.
    double *u_pert;      // K * T * n_u
    double *J;           // K
    double *w;           // K
    double *x_scratch;   // (T + 1) * n_x
} NMPPI;

static unsigned long long _xs(NMPPI *p) {
    unsigned long long x = p->rng;
    x ^= x << 13; x ^= x >> 7; x ^= x << 17;
    if (x == 0) x = 0xdeadbeefdeadbeefULL;
    p->rng = x; return x;
}
static double _rng_unit(NMPPI *p) {
    return ((double)(_xs(p) >> 11)) * (1.0 / (double)(1ULL << 53));
}
static double _rng_norm(NMPPI *p) {
    double u1 = _rng_unit(p), u2 = _rng_unit(p);
    if (u1 < 1e-12) u1 = 1e-12;
    return sqrt(-2.0 * log(u1)) * cos(2.0 * M_PI * u2);
}

long long nuc_mppi_new(long long n_x_, long long n_u_, long long T_, long long K_,
                        long long lambda_b, long long seed_)
{
    int n_x = (int)n_x_, n_u = (int)n_u_, T = (int)T_, K = (int)K_;
    if (n_x <= 0 || n_u <= 0 || T <= 0 || K <= 0) return 0;
    NMPPI *p = (NMPPI *)calloc(1, sizeof(NMPPI));
    p->n_x = n_x; p->n_u = n_u; p->T = T; p->K = K;
    double lam = _i2f(lambda_b);
    p->lambda = (lam > 0) ? lam : 1.0;
    p->sigma = (double *)malloc(n_u * sizeof(double));
    for (int i = 0; i < n_u; i++) p->sigma[i] = 1.0;
    p->u_seq = (double *)calloc((size_t)T * n_u, sizeof(double));
    p->u_pert = (double *)malloc((size_t)K * T * n_u * sizeof(double));
    p->J = (double *)malloc(K * sizeof(double));
    p->w = (double *)malloc(K * sizeof(double));
    p->x_scratch = (double *)malloc((size_t)(T + 1) * n_x * sizeof(double));
    p->rng = (unsigned long long)seed_ * 6364136223846793005ULL + 1442695040888963407ULL;
    if (p->rng == 0) p->rng = 1;
    return (long long)(size_t)p;
}

void nuc_mppi_set_callbacks(long long h, long long dyn_fp, long long sc_fp, long long tc_fp) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p) return;
    p->dyn_fp = dyn_fp; p->sc_fp = sc_fp; p->tc_fp = tc_fp;
    p->has_callbacks = 1;
}

void nuc_mppi_set_sigma(long long h, long long dim_, long long sigma_b) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p) return;
    int d = (int)dim_;
    if (d < 0 || d >= p->n_u) return;
    double s = _i2f(sigma_b);
    if (s > 0) p->sigma[d] = s;
}

void nuc_mppi_warm_start(long long h, long long u_seq_ptr) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p) return;
    double *src = (double *)(void *)(size_t)u_seq_ptr;
    if (!src) return;
    memcpy(p->u_seq, src, (size_t)(p->T) * p->n_u * sizeof(double));
}

void nuc_mppi_reset(long long h) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p) return;
    memset(p->u_seq, 0, (size_t)(p->T) * p->n_u * sizeof(double));
}

// One MPPI tick. Reads x from x_ptr (double[n_x]); writes u_0 to
// u_out_ptr (double[n_u]); shifts internal sequence by 1.
long long nuc_mppi_step(long long h, long long x_ptr, long long u_out_ptr) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p || !p->has_callbacks) return -1;
    double *u_out = (double *)(void *)(size_t)u_out_ptr;
    double *x_in  = (double *)(void *)(size_t)x_ptr;
    if (!u_out || !x_in) return -1;

    mppi_dyn_fn_t f   = (mppi_dyn_fn_t)(void *)(size_t)p->dyn_fp;
    mppi_cost_fn_t l  = (mppi_cost_fn_t)(void *)(size_t)p->sc_fp;
    mppi_tcost_fn_t lf= (mppi_tcost_fn_t)(void *)(size_t)p->tc_fp;
    int n_x = p->n_x, n_u = p->n_u, T = p->T, K = p->K;

    // Sample K rollouts.
    double J_min = INFINITY;
    for (int k = 0; k < K; k++) {
        // Build perturbed sequence and roll out.
        double *u_k = p->u_pert + k * T * n_u;
        memcpy(p->x_scratch, x_in, n_x * sizeof(double));
        double cost = 0;
        for (int t = 0; t < T; t++) {
            double *u_kt = u_k + t * n_u;
            // u_kt[i] = u_seq[t][i] + sigma[i] * N(0, 1)
            for (int i = 0; i < n_u; i++) {
                u_kt[i] = p->u_seq[t * n_u + i] + p->sigma[i] * _rng_norm(p);
            }
            double *xt = p->x_scratch + t * n_x;
            cost += _i2f(l((long long)(size_t)xt, (long long)(size_t)u_kt));
            f((long long)(size_t)xt, (long long)(size_t)u_kt,
              (long long)(size_t)(p->x_scratch + (t + 1) * n_x));
        }
        cost += _i2f(lf((long long)(size_t)(p->x_scratch + T * n_x)));
        p->J[k] = cost;
        if (cost < J_min) J_min = cost;
    }
    // Compute weights.
    double Z = 0;
    for (int k = 0; k < K; k++) {
        p->w[k] = exp(-(p->J[k] - J_min) / p->lambda);
        Z += p->w[k];
    }
    if (Z <= 0) Z = 1.0;
    for (int k = 0; k < K; k++) p->w[k] /= Z;

    // Update nominal sequence: u_seq[t][i] = Σ_k w_k · u_k[t][i].
    for (int t = 0; t < T; t++) {
        for (int i = 0; i < n_u; i++) {
            double s = 0;
            for (int k = 0; k < K; k++) {
                s += p->w[k] * p->u_pert[k * T * n_u + t * n_u + i];
            }
            p->u_seq[t * n_u + i] = s;
        }
    }

    // Output u_seq[0].
    memcpy(u_out, p->u_seq, n_u * sizeof(double));
    // Shift sequence (drop u_0; keep u_{T-1} at the new tail).
    for (int t = 0; t < T - 1; t++) {
        memcpy(p->u_seq + t * n_u, p->u_seq + (t + 1) * n_u, n_u * sizeof(double));
    }
    return 0;
}

long long nuc_mppi_get_control(long long h, long long t_, long long dim_) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p || t_ < 0 || t_ >= p->T || dim_ < 0 || dim_ >= p->n_u) return _f2i(0.0);
    return _f2i(p->u_seq[(int)t_ * p->n_u + (int)dim_]);
}

void nuc_mppi_free(long long h) {
    NMPPI *p = (NMPPI *)(void *)(size_t)h;
    if (!p) return;
    if (p->sigma) free(p->sigma);
    if (p->u_seq) free(p->u_seq);
    if (p->u_pert) free(p->u_pert);
    if (p->J) free(p->J);
    if (p->w) free(p->w);
    if (p->x_scratch) free(p->x_scratch);
    free(p);
}
