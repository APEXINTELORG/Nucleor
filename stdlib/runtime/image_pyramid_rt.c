// image_pyramid_rt.c — Gaussian image pyramid construction.
//
// Standard reduce/expand operations on 8-bit grayscale (or `double`)
// images used for multi-scale feature tracking (coarse-to-fine LK,
// multi-scale Harris corners, feature-matching descriptors).
//
// Reduce: halves each dimension via Gaussian blur + subsample by 2.
// Expand: doubles each dimension via upsample + Gaussian blur (×4).
//
// The 5-tap separable Gaussian kernel is Burt & Adelson's 1983
// pyramid filter: `[1 4 6 4 1] / 16`.
//
// Use:
//   - Coarse-to-fine Lucas-Kanade tracking (run `klt.nr` at each
//     level, starting from level L_max; warp the result and refine).
//   - Multi-scale Harris / ORB detection.
//   - Scale-invariant template matching.
//
// **Limitations** (SIFT scale-space DoG / orientation assignment /
// SIMD 16-byte stride land in v0.6 if needed):
// - Input image is `double[H][W]` row-major in [0, 255]. Internally
//   we operate in double so repeated reduce/expand stays stable.
// - Boundary handling: replicate (clamp index).
// - Reduce target size = ceil(W/2), ceil(H/2).
//
// Compile: clang -c stdlib/runtime/image_pyramid_rt.c -o target/image_pyramid.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

static double _clamp01(double v) {
    if (v < 0) return 0;
    if (v > 255) return 255;
    return v;
}

static int _clamp_i(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Row-wise 1-D separable 5-tap Gaussian blur then downsample by 2.
// in: double[H*W], out: double[outH*outW], outW=ceil(W/2), outH=ceil(H/2).
long long nuc_pyramid_reduce(long long in_ptr, long long W_, long long H_,
                              long long out_ptr)
{
    int W = (int)W_, H = (int)H_;
    int outW = (W + 1) / 2, outH = (H + 1) / 2;
    const double *in = (const double *)(void *)(size_t)in_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || W <= 0 || H <= 0) return 0;

    // Kernel [1 4 6 4 1] / 16.
    double k[5] = {1.0/16, 4.0/16, 6.0/16, 4.0/16, 1.0/16};

    // Intermediate: blur horizontally into tmp[H][W], then blur
    // vertically and subsample.
    double *tmp = (double *)malloc(sizeof(double) * H * W);
    if (!tmp) return 0;

    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            double s = 0;
            for (int dx = -2; dx <= 2; dx++) {
                int xx = _clamp_i(x + dx, 0, W - 1);
                s += k[dx + 2] * in[y * W + xx];
            }
            tmp[y * W + x] = s;
        }
    }

    for (int oy = 0; oy < outH; oy++) {
        int y = oy * 2;
        for (int ox = 0; ox < outW; ox++) {
            int x = ox * 2;
            double s = 0;
            for (int dy = -2; dy <= 2; dy++) {
                int yy = _clamp_i(y + dy, 0, H - 1);
                s += k[dy + 2] * tmp[yy * W + x];
            }
            out[oy * outW + ox] = s;
        }
    }

    free(tmp);
    return 1;
}

// Upsample by 2 via zero-insertion + Gaussian blur (×4 to compensate
// for the zeros). Out dimensions: outW, outH given by caller.
// Typical: outW = 2*W, outH = 2*H (or the dimensions of the level
// above in the pyramid).
long long nuc_pyramid_expand(long long in_ptr, long long W_, long long H_,
                              long long outW_, long long outH_, long long out_ptr)
{
    int W = (int)W_, H = (int)H_;
    int outW = (int)outW_, outH = (int)outH_;
    const double *in = (const double *)(void *)(size_t)in_ptr;
    double *out = (double *)(void *)(size_t)out_ptr;
    if (!in || !out || outW <= 0 || outH <= 0) return 0;

    // Kernel [1 4 6 4 1] / 16 * 2 → [1 4 6 4 1] / 8 for expand
    // (×2 per axis, ×4 total to preserve mean).
    double k[5] = {1.0/8, 4.0/8, 6.0/8, 4.0/8, 1.0/8};

    // Zero-insert into tmp of size outH * outW.
    double *tmp = (double *)calloc(outH * outW, sizeof(double));
    if (!tmp) return 0;

    for (int y = 0; y < H; y++) {
        int oy = y * 2;
        if (oy >= outH) break;
        for (int x = 0; x < W; x++) {
            int ox = x * 2;
            if (ox >= outW) break;
            tmp[oy * outW + ox] = in[y * W + x];
        }
    }

    // Horizontal blur in temp_h (outH * outW).
    double *th = (double *)malloc(sizeof(double) * outH * outW);
    if (!th) { free(tmp); return 0; }
    for (int y = 0; y < outH; y++) {
        for (int x = 0; x < outW; x++) {
            double s = 0;
            for (int dx = -2; dx <= 2; dx++) {
                int xx = _clamp_i(x + dx, 0, outW - 1);
                s += k[dx + 2] * tmp[y * outW + xx];
            }
            th[y * outW + x] = s;
        }
    }
    // Vertical blur into out.
    for (int y = 0; y < outH; y++) {
        for (int x = 0; x < outW; x++) {
            double s = 0;
            for (int dy = -2; dy <= 2; dy++) {
                int yy = _clamp_i(y + dy, 0, outH - 1);
                s += k[dy + 2] * th[yy * outW + x];
            }
            out[y * outW + x] = s;
        }
    }

    free(th);
    free(tmp);
    return 1;
}
