// conv_rt.c — Convolutional Neural Network Layers for Nucleor
// Conv2D forward/backward, MaxPool, AvgPool, BatchNorm, Dropout.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/conv_rt.c -o target/conv_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _cv_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _cv_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } CVVec;

static CVVec *cvvec_new(int n) {
    CVVec *v = (CVVec *)malloc(sizeof(CVVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

// ================================================================
//  Conv2D Forward
//  input:  flat [C_in, H, W]
//  kernel: flat [C_out, C_in, kH, kW]
//  output: flat [C_out, H_out, W_out]
// ================================================================

long long nuc_conv2d(long long input_h, long long kernel_h,
                      long long C_in, long long C_out,
                      long long H, long long W, long long kH, long long kW,
                      long long stride, long long pad) {
    CVVec *input = (CVVec *)(void *)input_h;
    CVVec *kernel = (CVVec *)(void *)kernel_h;
    int ci = (int)C_in, co = (int)C_out;
    int h = (int)H, w = (int)W, kh = (int)kH, kw = (int)kW;
    int s = (int)stride, p = (int)pad;

    int h_out = (h + 2 * p - kh) / s + 1;
    int w_out = (w + 2 * p - kw) / s + 1;

    CVVec *out = cvvec_new(co * h_out * w_out);

    for (int oc = 0; oc < co; oc++) {
        for (int oh = 0; oh < h_out; oh++) {
            for (int ow = 0; ow < w_out; ow++) {
                double sum = 0;
                for (int ic = 0; ic < ci; ic++) {
                    for (int fh = 0; fh < kh; fh++) {
                        for (int fw = 0; fw < kw; fw++) {
                            int ih = oh * s - p + fh;
                            int iw = ow * s - p + fw;
                            if (ih < 0 || ih >= h || iw < 0 || iw >= w) continue;
                            double inp = _cv_i2f(input->data[ic * h * w + ih * w + iw]);
                            double ker = _cv_i2f(kernel->data[oc * ci * kh * kw + ic * kh * kw + fh * kw + fw]);
                            sum += inp * ker;
                        }
                    }
                }
                out->data[oc * h_out * w_out + oh * w_out + ow] = _cv_f2i(sum);
            }
        }
    }
    return (long long)out;
}

// ================================================================
//  Conv2D Backward
//  Returns grad_input [C_in, H, W] and grad_kernel [C_out, C_in, kH, kW]
// ================================================================

typedef struct { long long grad_input; long long grad_kernel; } ConvGrad;

long long nuc_conv2d_backward(long long grad_out_h, long long input_h, long long kernel_h,
                               long long C_in, long long C_out,
                               long long H, long long W, long long kH, long long kW,
                               long long stride, long long pad) {
    CVVec *grad_out = (CVVec *)(void *)grad_out_h;
    CVVec *input = (CVVec *)(void *)input_h;
    CVVec *kernel = (CVVec *)(void *)kernel_h;
    int ci = (int)C_in, co = (int)C_out;
    int h = (int)H, w = (int)W, kh = (int)kH, kw = (int)kW;
    int s = (int)stride, p = (int)pad;
    int h_out = (h + 2 * p - kh) / s + 1;
    int w_out = (w + 2 * p - kw) / s + 1;

    CVVec *gi = cvvec_new(ci * h * w);
    CVVec *gk = cvvec_new(co * ci * kh * kw);

    for (int oc = 0; oc < co; oc++) {
        for (int oh = 0; oh < h_out; oh++) {
            for (int ow = 0; ow < w_out; ow++) {
                double go = _cv_i2f(grad_out->data[oc * h_out * w_out + oh * w_out + ow]);
                for (int ic = 0; ic < ci; ic++) {
                    for (int fh = 0; fh < kh; fh++) {
                        for (int fw = 0; fw < kw; fw++) {
                            int ih = oh * s - p + fh;
                            int iw = ow * s - p + fw;
                            if (ih < 0 || ih >= h || iw < 0 || iw >= w) continue;
                            // grad_input
                            double ker = _cv_i2f(kernel->data[oc * ci * kh * kw + ic * kh * kw + fh * kw + fw]);
                            int gi_idx = ic * h * w + ih * w + iw;
                            gi->data[gi_idx] = _cv_f2i(_cv_i2f(gi->data[gi_idx]) + go * ker);
                            // grad_kernel
                            double inp = _cv_i2f(input->data[ic * h * w + ih * w + iw]);
                            int gk_idx = oc * ci * kh * kw + ic * kh * kw + fh * kw + fw;
                            gk->data[gk_idx] = _cv_f2i(_cv_i2f(gk->data[gk_idx]) + go * inp);
                        }
                    }
                }
            }
        }
    }

    ConvGrad *res = (ConvGrad *)malloc(sizeof(ConvGrad));
    res->grad_input = (long long)gi;
    res->grad_kernel = (long long)gk;
    return (long long)res;
}

long long nuc_conv2d_grad_input(long long h) { return ((ConvGrad *)(void *)h)->grad_input; }
long long nuc_conv2d_grad_kernel(long long h) { return ((ConvGrad *)(void *)h)->grad_kernel; }

// ================================================================
//  Max Pool 2D
// ================================================================

long long nuc_maxpool2d(long long input_h, long long C, long long H, long long W,
                         long long pool_size, long long stride_val) {
    CVVec *input = (CVVec *)(void *)input_h;
    int c = (int)C, h = (int)H, w = (int)W;
    int ps = (int)pool_size, s = (int)stride_val;
    int h_out = (h - ps) / s + 1;
    int w_out = (w - ps) / s + 1;

    CVVec *out = cvvec_new(c * h_out * w_out);

    for (int ch = 0; ch < c; ch++) {
        for (int oh = 0; oh < h_out; oh++) {
            for (int ow = 0; ow < w_out; ow++) {
                double max_val = -1e30;
                for (int ph = 0; ph < ps; ph++) {
                    for (int pw = 0; pw < ps; pw++) {
                        int ih = oh * s + ph, iw = ow * s + pw;
                        double v = _cv_i2f(input->data[ch * h * w + ih * w + iw]);
                        if (v > max_val) max_val = v;
                    }
                }
                out->data[ch * h_out * w_out + oh * w_out + ow] = _cv_f2i(max_val);
            }
        }
    }
    return (long long)out;
}

// ================================================================
//  Average Pool 2D
// ================================================================

long long nuc_avgpool2d(long long input_h, long long C, long long H, long long W,
                         long long pool_size, long long stride_val) {
    CVVec *input = (CVVec *)(void *)input_h;
    int c = (int)C, h = (int)H, w = (int)W;
    int ps = (int)pool_size, s = (int)stride_val;
    int h_out = (h - ps) / s + 1;
    int w_out = (w - ps) / s + 1;
    double inv_ps2 = 1.0 / (ps * ps);

    CVVec *out = cvvec_new(c * h_out * w_out);

    for (int ch = 0; ch < c; ch++) {
        for (int oh = 0; oh < h_out; oh++) {
            for (int ow = 0; ow < w_out; ow++) {
                double sum = 0;
                for (int ph = 0; ph < ps; ph++)
                    for (int pw = 0; pw < ps; pw++)
                        sum += _cv_i2f(input->data[ch * h * w + (oh * s + ph) * w + ow * s + pw]);
                out->data[ch * h_out * w_out + oh * w_out + ow] = _cv_f2i(sum * inv_ps2);
            }
        }
    }
    return (long long)out;
}

// ================================================================
//  Batch Normalization
// ================================================================

long long nuc_batchnorm(long long xh, long long gamma_h, long long beta_h,
                         long long mean_h, long long var_h, long long n) {
    CVVec *x = (CVVec *)(void *)xh;
    CVVec *gamma = (CVVec *)(void *)gamma_h;
    CVVec *beta = (CVVec *)(void *)beta_h;
    CVVec *mean = (CVVec *)(void *)mean_h;
    CVVec *var = (CVVec *)(void *)var_h;
    int N = (int)n;

    CVVec *out = cvvec_new(x->len);
    for (int i = 0; i < x->len; i++) {
        int ch = i % N;
        double xn = (_cv_i2f(x->data[i]) - _cv_i2f(mean->data[ch])) / sqrt(_cv_i2f(var->data[ch]) + 1e-5);
        out->data[i] = _cv_f2i(xn * _cv_i2f(gamma->data[ch]) + _cv_i2f(beta->data[ch]));
    }
    return (long long)out;
}

// ================================================================
//  Dropout (training mode)
// ================================================================

long long nuc_dropout(long long xh, long long rate_bits, long long training) {
    CVVec *x = (CVVec *)(void *)xh;
    double rate = _cv_i2f(rate_bits);
    if (!training) { // passthrough in eval mode
        CVVec *out = cvvec_new(x->len);
        memcpy(out->data, x->data, x->len * sizeof(long long));
        return (long long)out;
    }

    unsigned int rng = 99999;
    double scale = 1.0 / (1.0 - rate);
    CVVec *out = cvvec_new(x->len);
    for (int i = 0; i < x->len; i++) {
        rng = rng * 1103515245 + 12345;
        double u = ((double)((rng >> 16) & 0x7FFF)) / 32767.0;
        out->data[i] = (u < rate) ? 0 : _cv_f2i(_cv_i2f(x->data[i]) * scale);
    }
    return (long long)out;
}
