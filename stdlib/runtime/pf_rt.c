// pf_rt.c — Particle filter (sequential Monte Carlo) for nonlinear,
// non-Gaussian state estimation.
//
// Represents the posterior p(x | z_1:t) by a swarm of weighted
// particles {(x_i, w_i)}. At each step:
//
//   Predict: x_i ← f(x_i, u) + Q-sample noise
//   Update:  w_i ← w_i · p(z | h(x_i))    [user supplies likelihood]
//            normalize: Σ w_i = 1
//   Resample: if effective N drops below threshold, draw N new
//             particles with replacement using systematic
//             resampling (low variance + monotone scan).
//
// Foundation for:
// - Kidnapped-robot localization (multi-modal posterior over
//   the entire map until enough observations narrow it down).
// - Multi-target tracking with data association ambiguity.
// - Strongly nonlinear tracking where EKF / UKF fail.
// - Bayesian filtering on non-vector state spaces (orientation
//   manifolds, Lie groups) — particles can be any state type.
//
// **Limitations** (Rao-Blackwellized particle filter,
// auxiliary-variable PF, and adaptive particle count land in v0.6
// if needed):
// - Unweighted-prior initialization (no proposal distribution).
// - Systematic resampling only (no stratified / residual variants).
// - Caller supplies process noise as a diagonal stddev vector
//   (Gaussian assumption); for arbitrary noise, sample within the
//   user's dynamics callback.
//
// Compile: clang -c stdlib/runtime/pf_rt.c -o target/pf.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef long long (*dyn_fn_t)(long long x_ptr, long long u_ptr, long long x_next_ptr);
typedef long long (*likelihood_fn_t)(long long x_ptr, long long z_ptr);

typedef struct {
    int n_x, n_z;
    int n_particles;
    double *X;         // n_particles × n_x
    double *W;         // n_particles
    unsigned int rng;
} NPF;

// xorshift32 → uniform in [0, 1).
static double _pf_uniform(unsigned int *st) {
    unsigned int x = *st;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    *st = x;
    return (double)x / 4294967296.0;
}

// Box-Muller standard normal.
static double _pf_normal(unsigned int *st) {
    double u1 = _pf_uniform(st);
    double u2 = _pf_uniform(st);
    if (u1 < 1e-12) u1 = 1e-12;
    return sqrt(-2.0 * log(u1)) * cos(2.0 * 3.14159265358979 * u2);
}

long long nuc_pf_new(long long n_x, long long n_z, long long n_particles, long long seed) {
    if (n_x <= 0 || n_z <= 0 || n_particles <= 0) return 0;
    NPF *p = (NPF *)calloc(1, sizeof(NPF));
    p->n_x = (int)n_x; p->n_z = (int)n_z;
    p->n_particles = (int)n_particles;
    p->X = (double *)calloc(p->n_particles * p->n_x, sizeof(double));
    p->W = (double *)malloc(p->n_particles * sizeof(double));
    for (int i = 0; i < p->n_particles; i++) p->W[i] = 1.0 / p->n_particles;
    p->rng = (unsigned int)seed;
    if (p->rng == 0) p->rng = 0x9E3779B9u;
    return (long long)(size_t)p;
}

// Replace all particles with `x_array_ptr` (caller-allocated
// double[n_particles * n_x]). Equal weights (1/N) re-initialized.
void nuc_pf_set_initial(long long h, long long x_array_ptr) {
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return;
    double *X = (double *)(void *)(size_t)x_array_ptr;
    if (X) memcpy(p->X, X, p->n_particles * p->n_x * sizeof(double));
    for (int i = 0; i < p->n_particles; i++) p->W[i] = 1.0 / p->n_particles;
}

// Initialize particles uniformly in a box [lo, hi]^n_x. Useful for
// global-localization initialization.
long long nuc_pf_init_uniform(long long h, long long lo_ptr, long long hi_ptr) {
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return -1;
    double *lo = (double *)(void *)(size_t)lo_ptr;
    double *hi = (double *)(void *)(size_t)hi_ptr;
    if (!lo || !hi) return -1;
    for (int i = 0; i < p->n_particles; i++) {
        for (int j = 0; j < p->n_x; j++) {
            double u = _pf_uniform(&p->rng);
            p->X[i*p->n_x + j] = lo[j] + u * (hi[j] - lo[j]);
        }
        p->W[i] = 1.0 / p->n_particles;
    }
    return 0;
}

// Predict: propagate each particle through f(x, u), then add
// Gaussian noise with the given diagonal stddev (n_x doubles).
// Pass noise_std = 0 (NULL) to skip noise injection.
long long nuc_pf_predict(long long h, long long u_ptr,
    long long dynamics_fp, long long noise_std_ptr)
{
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return -1;
    dyn_fn_t f = (dyn_fn_t)(void *)(size_t)dynamics_fp;
    if (!f) return -1;
    double *noise_std = (double *)(void *)(size_t)noise_std_ptr;
    double *x_new = (double *)malloc(p->n_x * sizeof(double));
    for (int i = 0; i < p->n_particles; i++) {
        f((long long)(size_t)(p->X + i*p->n_x), u_ptr,
          (long long)(size_t)x_new);
        if (noise_std) {
            for (int j = 0; j < p->n_x; j++) {
                x_new[j] += noise_std[j] * _pf_normal(&p->rng);
            }
        }
        memcpy(p->X + i*p->n_x, x_new, p->n_x * sizeof(double));
    }
    free(x_new);
    return 0;
}

// Effective particle count: 1 / Σ w_i².
static double _eff_n(NPF *p) {
    double s = 0;
    for (int i = 0; i < p->n_particles; i++) s += p->W[i] * p->W[i];
    if (s < 1e-18) return (double)p->n_particles;
    return 1.0 / s;
}

// Systematic resampling: low-variance, deterministic single-pass.
static void _systematic_resample(NPF *p) {
    int N = p->n_particles;
    double *cdf = (double *)malloc(N * sizeof(double));
    cdf[0] = p->W[0];
    for (int i = 1; i < N; i++) cdf[i] = cdf[i-1] + p->W[i];
    double *X_new = (double *)malloc(N * p->n_x * sizeof(double));
    double u0 = _pf_uniform(&p->rng) / N;
    int j = 0;
    for (int i = 0; i < N; i++) {
        double u = u0 + (double)i / N;
        while (j < N - 1 && u > cdf[j]) j++;
        memcpy(X_new + i*p->n_x, p->X + j*p->n_x, p->n_x * sizeof(double));
    }
    memcpy(p->X, X_new, N * p->n_x * sizeof(double));
    for (int i = 0; i < N; i++) p->W[i] = 1.0 / N;
    free(cdf); free(X_new);
}

// Update: weight each particle by user's likelihood callback,
// renormalize, resample if effective N drops below threshold.
//
// `likelihood_fp`: fn(x_ptr, z_ptr) -> i64 (bit-cast f64 likelihood,
// non-negative). Tip: return the un-normalized likelihood (e.g.,
// exp(-||z - h(x)||² / (2σ²))) — normalization happens here.
//
// `eff_threshold_b` is the effective-N threshold (as a fraction of
// total N) below which to resample. Typical 0.5.
long long nuc_pf_update(long long h, long long z_ptr,
    long long likelihood_fp, long long eff_threshold_b)
{
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return -1;
    likelihood_fn_t lk = (likelihood_fn_t)(void *)(size_t)likelihood_fp;
    if (!lk) return -1;
    double frac = _i2f(eff_threshold_b);
    if (frac <= 0 || frac > 1) frac = 0.5;

    double sum_w = 0;
    for (int i = 0; i < p->n_particles; i++) {
        double lw = _i2f(lk((long long)(size_t)(p->X + i*p->n_x), z_ptr));
        if (lw < 0) lw = 0;
        p->W[i] *= lw;
        sum_w += p->W[i];
    }
    if (sum_w < 1e-300) {
        // All weights collapsed — reset to uniform.
        for (int i = 0; i < p->n_particles; i++) p->W[i] = 1.0 / p->n_particles;
    } else {
        for (int i = 0; i < p->n_particles; i++) p->W[i] /= sum_w;
    }
    if (_eff_n(p) < frac * p->n_particles) {
        _systematic_resample(p);
    }
    return 0;
}

// Read the weighted-mean state estimate.
void nuc_pf_get_mean(long long h, long long x_out_ptr) {
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return;
    double *out = (double *)(void *)(size_t)x_out_ptr;
    if (!out) return;
    for (int j = 0; j < p->n_x; j++) out[j] = 0;
    for (int i = 0; i < p->n_particles; i++) {
        for (int j = 0; j < p->n_x; j++) {
            out[j] += p->W[i] * p->X[i*p->n_x + j];
        }
    }
}

// Read individual particle (i in [0, n_particles)).
void nuc_pf_get_particle(long long h, long long i, long long x_out_ptr) {
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_particles) return;
    double *out = (double *)(void *)(size_t)x_out_ptr;
    if (out) memcpy(out, p->X + i*p->n_x, p->n_x * sizeof(double));
}

long long nuc_pf_particle_count(long long h) {
    NPF *p = (NPF *)(void *)(size_t)h;
    return p ? (long long)p->n_particles : 0;
}

void nuc_pf_free(long long h) {
    NPF *p = (NPF *)(void *)(size_t)h;
    if (!p) return;
    if (p->X) free(p->X);
    if (p->W) free(p->W);
    free(p);
}
