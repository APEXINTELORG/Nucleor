// imgproc_rt.c — Basic image processing primitives on grayscale
// images (caller-allocated `double[H * W]`, row-major).
//
// All functions take input pointer, output pointer, width, height
// (and per-function parameters). Output buffer is the same size as
// input unless otherwise noted. Boundary handling: replicate
// (clamp) edge pixels.
//
// Provides:
//   - Sobel X / Y gradient
//   - Gradient magnitude `sqrt(Gx² + Gy²)`
//   - Box filter (mean of (2r+1)² window)
//   - Separable Gaussian blur
//   - Bilinear resize (in_W × in_H → out_W × out_H)
//
// Foundation for vision pipelines: edge detection, feature
// pre-processing, image pyramids for KLT / Lucas-Kanade tracking
// (which lands in v0.6 alongside the actual feature tracker).
//
// Pixels are doubles in arbitrary range — caller decides [0, 1],
// [0, 255], or anything else. The operators are linear so the
// range is preserved (modulo gradient operators which can produce
// negative values).
//
// **Limitations** (color / multi-channel / FFT-based filters /
// pyramids land in v0.6 if needed):
// - Grayscale only. For color, call once per channel.
// - Sobel operates on a 3×3 stencil — no Scharr or larger kernels.
// - Gaussian is separable but caller specifies kernel radius
//   directly; no auto-radius from sigma (use radius ≈ 3·σ).
//
// Compile: clang -c stdlib/runtime/imgproc_rt.c -o target/imgproc.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static inline int _clamp(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// === Sobel ===

void nuc_img_sobel_x(long long in_ptr, long long out_ptr, long long W_, long long H_) {
    int W = (int)W_, H = (int)H_;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return;
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            int xm = _clamp(x - 1, 0, W - 1);
            int xp = _clamp(x + 1, 0, W - 1);
            int ym = _clamp(y - 1, 0, H - 1);
            int yp = _clamp(y + 1, 0, H - 1);
            double gx = -1.0 * in[ym*W + xm] + 1.0 * in[ym*W + xp]
                      + -2.0 * in[y *W + xm] + 2.0 * in[y *W + xp]
                      + -1.0 * in[yp*W + xm] + 1.0 * in[yp*W + xp];
            out[y*W + x] = gx;
        }
    }
}

void nuc_img_sobel_y(long long in_ptr, long long out_ptr, long long W_, long long H_) {
    int W = (int)W_, H = (int)H_;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return;
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            int xm = _clamp(x - 1, 0, W - 1);
            int xp = _clamp(x + 1, 0, W - 1);
            int ym = _clamp(y - 1, 0, H - 1);
            int yp = _clamp(y + 1, 0, H - 1);
            double gy = -1.0 * in[ym*W + xm] + -2.0 * in[ym*W + x] + -1.0 * in[ym*W + xp]
                      +  1.0 * in[yp*W + xm] +  2.0 * in[yp*W + x] +  1.0 * in[yp*W + xp];
            out[y*W + x] = gy;
        }
    }
}

void nuc_img_gradient_magnitude(long long in_ptr, long long out_ptr,
                                 long long W_, long long H_)
{
    int W = (int)W_, H = (int)H_;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return;
    double *gx = (double *)malloc(W * H * sizeof(double));
    double *gy = (double *)malloc(W * H * sizeof(double));
    nuc_img_sobel_x(in_ptr, (long long)(size_t)gx, W_, H_);
    nuc_img_sobel_y(in_ptr, (long long)(size_t)gy, W_, H_);
    for (int i = 0; i < W * H; i++) out[i] = sqrt(gx[i]*gx[i] + gy[i]*gy[i]);
    free(gx); free(gy);
}

// === Box filter ===

void nuc_img_box_filter(long long in_ptr, long long out_ptr,
                         long long W_, long long H_, long long radius_)
{
    int W = (int)W_, H = (int)H_, r = (int)radius_;
    if (r < 0) r = 0;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return;
    int side = 2 * r + 1;
    double inv = 1.0 / (side * side);
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            double s = 0;
            for (int dy = -r; dy <= r; dy++) {
                int yi = _clamp(y + dy, 0, H - 1);
                for (int dx = -r; dx <= r; dx++) {
                    int xi = _clamp(x + dx, 0, W - 1);
                    s += in[yi*W + xi];
                }
            }
            out[y*W + x] = s * inv;
        }
    }
}

// === Gaussian blur (separable) ===

void nuc_img_blur_gaussian(long long in_ptr, long long out_ptr,
                            long long W_, long long H_,
                            long long sigma_b, long long radius_)
{
    int W = (int)W_, H = (int)H_, r = (int)radius_;
    if (r < 0) r = 0;
    double sigma; { long long sb = sigma_b; double d; memcpy(&d, &sb, 8); sigma = d; }
    if (sigma <= 0) sigma = 1.0;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return;

    int len = 2 * r + 1;
    double *kernel = (double *)malloc(len * sizeof(double));
    double sum = 0;
    for (int i = 0; i < len; i++) {
        double x = (double)(i - r);
        kernel[i] = exp(-(x*x) / (2.0 * sigma * sigma));
        sum += kernel[i];
    }
    for (int i = 0; i < len; i++) kernel[i] /= sum;

    double *tmp = (double *)malloc(W * H * sizeof(double));
    // Horizontal pass.
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            double s = 0;
            for (int k = 0; k < len; k++) {
                int xi = _clamp(x + k - r, 0, W - 1);
                s += kernel[k] * in[y*W + xi];
            }
            tmp[y*W + x] = s;
        }
    }
    // Vertical pass.
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            double s = 0;
            for (int k = 0; k < len; k++) {
                int yi = _clamp(y + k - r, 0, H - 1);
                s += kernel[k] * tmp[yi*W + x];
            }
            out[y*W + x] = s;
        }
    }
    free(tmp); free(kernel);
}

// === Bilinear resize ===

void nuc_img_resize_bilinear(long long in_ptr, long long in_W_, long long in_H_,
                              long long out_ptr, long long out_W_, long long out_H_)
{
    int in_W = (int)in_W_, in_H = (int)in_H_;
    int out_W = (int)out_W_, out_H = (int)out_H_;
    const double *in  = (const double *)(void *)(size_t)in_ptr;
    double       *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || in_W <= 0 || in_H <= 0 || out_W <= 0 || out_H <= 0) return;
    double sx = (double)(in_W - 1) / (double)((out_W > 1) ? (out_W - 1) : 1);
    double sy = (double)(in_H - 1) / (double)((out_H > 1) ? (out_H - 1) : 1);
    for (int y = 0; y < out_H; y++) {
        double fy = y * sy;
        int iy = (int)fy;
        double ty = fy - iy;
        if (iy >= in_H - 1) { iy = in_H - 2; ty = 1.0; }
        if (iy < 0)         { iy = 0;          ty = 0.0; }
        for (int x = 0; x < out_W; x++) {
            double fx = x * sx;
            int ix = (int)fx;
            double tx = fx - ix;
            if (ix >= in_W - 1) { ix = in_W - 2; tx = 1.0; }
            if (ix < 0)         { ix = 0;          tx = 0.0; }
            double v00 = in[(iy  )*in_W + ix  ];
            double v10 = in[(iy  )*in_W + ix+1];
            double v01 = in[(iy+1)*in_W + ix  ];
            double v11 = in[(iy+1)*in_W + ix+1];
            double v0 = v00 * (1.0 - tx) + v10 * tx;
            double v1 = v01 * (1.0 - tx) + v11 * tx;
            out[y*out_W + x] = v0 * (1.0 - ty) + v1 * ty;
        }
    }
}
