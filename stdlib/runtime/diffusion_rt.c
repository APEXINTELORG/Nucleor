// diffusion_rt.c — Diffusion Models and Flow Matching for Nucleor
// Noise schedules, timestep embedding, adaptive layer norm, CFG, rectified flow.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/diffusion_rt.c -o target/diffusion_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _df_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _df_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } DFVec;

static DFVec *dfvec_new(int n) {
    DFVec *v = (DFVec *)malloc(sizeof(DFVec));
    v->len = n; v->cap = n; v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  DDPM Noise Schedule (linear beta schedule)
// ================================================================

long long nuc_diff_linear_schedule(long long n_steps, long long beta_start_bits, long long beta_end_bits) {
    int T = (int)n_steps;
    double b0 = _df_i2f(beta_start_bits), b1 = _df_i2f(beta_end_bits);

    // Returns flat Vec: [betas..., alphas..., alpha_bars..., sqrt_alpha_bars..., sqrt_one_minus_alpha_bars...]
    DFVec *sched = dfvec_new(T * 5);

    double alpha_bar = 1.0;
    for (int t = 0; t < T; t++) {
        double beta = b0 + (b1 - b0) * t / (T - 1);
        double alpha = 1.0 - beta;
        alpha_bar *= alpha;

        sched->data[t] = _df_f2i(beta);
        sched->data[T + t] = _df_f2i(alpha);
        sched->data[2 * T + t] = _df_f2i(alpha_bar);
        sched->data[3 * T + t] = _df_f2i(sqrt(alpha_bar));
        sched->data[4 * T + t] = _df_f2i(sqrt(1.0 - alpha_bar));
    }
    return (long long)sched;
}

// Cosine schedule (improved, from "Improved Denoising Diffusion")
long long nuc_diff_cosine_schedule(long long n_steps) {
    int T = (int)n_steps;
    DFVec *sched = dfvec_new(T * 5);
    double s = 0.008;

    double prev_bar = 1.0;
    for (int t = 0; t < T; t++) {
        double f_t = cos(((t + 1.0) / T + s) / (1 + s) * M_PI * 0.5);
        double f_0 = cos((s) / (1 + s) * M_PI * 0.5);
        double alpha_bar = (f_t * f_t) / (f_0 * f_0);
        if (alpha_bar < 1e-10) alpha_bar = 1e-10;
        double beta = 1.0 - alpha_bar / prev_bar;
        if (beta > 0.999) beta = 0.999;
        if (beta < 1e-6) beta = 1e-6;
        double alpha = 1.0 - beta;
        prev_bar = alpha_bar;

        sched->data[t] = _df_f2i(beta);
        sched->data[T + t] = _df_f2i(alpha);
        sched->data[2 * T + t] = _df_f2i(alpha_bar);
        sched->data[3 * T + t] = _df_f2i(sqrt(alpha_bar));
        sched->data[4 * T + t] = _df_f2i(sqrt(1.0 - alpha_bar));
    }
    return (long long)sched;
}

// ================================================================
//  Forward Diffusion: x_t = sqrt(alpha_bar_t) * x_0 + sqrt(1-alpha_bar_t) * noise
// ================================================================

long long nuc_diff_forward(long long x0_h, long long noise_h,
                            long long sqrt_ab_bits, long long sqrt_one_minus_ab_bits) {
    DFVec *x0 = (DFVec *)(void *)x0_h;
    DFVec *noise = (DFVec *)(void *)noise_h;
    double sab = _df_i2f(sqrt_ab_bits);
    double soab = _df_i2f(sqrt_one_minus_ab_bits);
    int n = x0->len < noise->len ? x0->len : noise->len;

    DFVec *xt = dfvec_new(n);
    for (int i = 0; i < n; i++)
        xt->data[i] = _df_f2i(sab * _df_i2f(x0->data[i]) + soab * _df_i2f(noise->data[i]));
    return (long long)xt;
}

// ================================================================
//  Rectified Flow Interpolation: x_t = t * x_1 + (1-t) * x_0
//  Velocity target: v = x_1 - x_0
// ================================================================

long long nuc_diff_rectified_flow_interp(long long x0_h, long long x1_h, long long t_bits) {
    DFVec *x0 = (DFVec *)(void *)x0_h, *x1 = (DFVec *)(void *)x1_h;
    double t = _df_i2f(t_bits);
    int n = x0->len < x1->len ? x0->len : x1->len;

    DFVec *xt = dfvec_new(n);
    for (int i = 0; i < n; i++)
        xt->data[i] = _df_f2i(t * _df_i2f(x1->data[i]) + (1 - t) * _df_i2f(x0->data[i]));
    return (long long)xt;
}

long long nuc_diff_rectified_flow_target(long long x0_h, long long x1_h) {
    DFVec *x0 = (DFVec *)(void *)x0_h, *x1 = (DFVec *)(void *)x1_h;
    int n = x0->len < x1->len ? x0->len : x1->len;
    DFVec *v = dfvec_new(n);
    for (int i = 0; i < n; i++)
        v->data[i] = _df_f2i(_df_i2f(x1->data[i]) - _df_i2f(x0->data[i]));
    return (long long)v;
}

// ================================================================
//  Euler ODE Step for Sampling: x_{t-dt} = x_t + dt * v(x_t, t)
// ================================================================

long long nuc_diff_euler_step(long long xt_h, long long velocity_h, long long dt_bits) {
    DFVec *xt = (DFVec *)(void *)xt_h;
    DFVec *v = (DFVec *)(void *)velocity_h;
    double dt = _df_i2f(dt_bits);
    int n = xt->len < v->len ? xt->len : v->len;

    DFVec *out = dfvec_new(n);
    for (int i = 0; i < n; i++)
        out->data[i] = _df_f2i(_df_i2f(xt->data[i]) + dt * _df_i2f(v->data[i]));
    return (long long)out;
}

// ================================================================
//  Timestep Embedding (sinusoidal, for conditioning)
// ================================================================

long long nuc_diff_timestep_embed(long long t, long long dim) {
    int d = (int)dim;
    DFVec *emb = dfvec_new(d);
    double ts = (double)t;
    for (int i = 0; i < d / 2; i++) {
        double freq = exp(-log(10000.0) * 2.0 * i / d);
        emb->data[2 * i] = _df_f2i(sin(ts * freq));
        emb->data[2 * i + 1] = _df_f2i(cos(ts * freq));
    }
    return (long long)emb;
}

// ================================================================
//  Adaptive Layer Norm (AdaLN): norm(x) * (1 + scale) + shift
//  scale and shift are functions of the timestep embedding
// ================================================================

long long nuc_diff_adaln(long long x_h, long long scale_h, long long shift_h) {
    DFVec *x = (DFVec *)(void *)x_h;
    DFVec *scale = (DFVec *)(void *)scale_h;
    DFVec *shift = (DFVec *)(void *)shift_h;
    int n = x->len;

    // RMSNorm first
    double sum_sq = 0;
    for (int i = 0; i < n; i++) { double v = _df_i2f(x->data[i]); sum_sq += v * v; }
    double inv_rms = 1.0 / sqrt(sum_sq / n + 1e-6);

    DFVec *out = dfvec_new(n);
    for (int i = 0; i < n; i++) {
        double normed = _df_i2f(x->data[i]) * inv_rms;
        double s = (scale && i < scale->len) ? _df_i2f(scale->data[i]) : 0;
        double sh = (shift && i < shift->len) ? _df_i2f(shift->data[i]) : 0;
        out->data[i] = _df_f2i(normed * (1 + s) + sh);
    }
    return (long long)out;
}

// ================================================================
//  Classifier-Free Guidance
//  output = uncond + guidance_scale * (cond - uncond)
// ================================================================

long long nuc_diff_cfg(long long cond_h, long long uncond_h, long long scale_bits) {
    DFVec *cond = (DFVec *)(void *)cond_h;
    DFVec *uncond = (DFVec *)(void *)uncond_h;
    double scale = _df_i2f(scale_bits);
    int n = cond->len < uncond->len ? cond->len : uncond->len;

    DFVec *out = dfvec_new(n);
    for (int i = 0; i < n; i++) {
        double c = _df_i2f(cond->data[i]), u = _df_i2f(uncond->data[i]);
        out->data[i] = _df_f2i(u + scale * (c - u));
    }
    return (long long)out;
}

// ================================================================
//  DDPM Reverse Step: x_{t-1} from x_t and predicted noise
// ================================================================

long long nuc_diff_ddpm_reverse_step(long long xt_h, long long pred_noise_h,
                                       long long beta_bits, long long alpha_bits,
                                       long long alpha_bar_bits, long long noise_h) {
    DFVec *xt = (DFVec *)(void *)xt_h;
    DFVec *eps = (DFVec *)(void *)pred_noise_h;
    DFVec *z = (DFVec *)(void *)noise_h;
    double beta = _df_i2f(beta_bits);
    double alpha = _df_i2f(alpha_bits);
    double ab = _df_i2f(alpha_bar_bits);
    int n = xt->len;

    double coeff1 = 1.0 / sqrt(alpha);
    double coeff2 = beta / sqrt(1.0 - ab);
    double sigma = sqrt(beta);

    DFVec *out = dfvec_new(n);
    for (int i = 0; i < n; i++) {
        double mean = coeff1 * (_df_i2f(xt->data[i]) - coeff2 * _df_i2f(eps->data[i]));
        double noise = (z && i < z->len) ? _df_i2f(z->data[i]) : 0;
        out->data[i] = _df_f2i(mean + sigma * noise);
    }
    return (long long)out;
}
