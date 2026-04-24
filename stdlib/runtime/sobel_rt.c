// sobel_rt.c — Sobel edge gradient.
//
// Computes per-pixel x-gradient (Gx), y-gradient (Gy), and
// gradient magnitude `G = sqrt(Gx² + Gy²)` using the standard
// Sobel 3×3 kernels:
//
//   Gx = [-1 0 +1     Gy = [-1 -2 -1
//         -2 0 +2           0  0  0
//         -1 0 +1]         +1 +2 +1]
//
// Sobel weights are designed so that horizontal + vertical
// gradients have approximately the same magnitude on a 45° edge.
// Use:
//   - Edge-strength image for downstream Canny / Hough.
//   - Texture analysis.
//   - Visual-attention salience maps.
//
// API:
//   nuc_sobel(img_ptr, W, H, gx_out, gy_out, mag_out)
//      Writes 3 W×H float images. Pass any output as 0 (NULL) to
//      skip writing it (e.g., only compute magnitude).
//
// **Limitations** (Scharr 3×3 kernels / 5×5 Sobel / sub-pixel
// gradient direction land in v0.6 if needed):
// - Standard Sobel only (no Scharr).
// - Replicate boundary handling (edges of the image are
//   evaluated against the nearest valid pixel).
//
// Compile: clang -c stdlib/runtime/sobel_rt.c -o target/sobel.obj -O2

#include <string.h>
#include <math.h>

static int _clamp_i(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

long long nuc_sobel(long long img_ptr, long long W_, long long H_,
                     long long gx_out_ptr, long long gy_out_ptr,
                     long long mag_out_ptr)
{
    int W = (int)W_, H = (int)H_;
    const double *img = (const double *)(void *)(size_t)img_ptr;
    double *gx_out = (double *)(void *)(size_t)gx_out_ptr;
    double *gy_out = (double *)(void *)(size_t)gy_out_ptr;
    double *mag_out = (double *)(void *)(size_t)mag_out_ptr;
    if (!img || W < 3 || H < 3) return 0;
    if (!gx_out && !gy_out && !mag_out) return 0;

    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            int xm = _clamp_i(x - 1, 0, W - 1);
            int xp = _clamp_i(x + 1, 0, W - 1);
            int ym = _clamp_i(y - 1, 0, H - 1);
            int yp = _clamp_i(y + 1, 0, H - 1);
            double a = img[ym*W + xm], b = img[ym*W + x ], c = img[ym*W + xp];
            double d = img[y *W + xm];                        double f = img[y *W + xp];
            double g = img[yp*W + xm], h = img[yp*W + x ], i = img[yp*W + xp];
            double gx = (c + 2.0*f + i) - (a + 2.0*d + g);
            double gy = (g + 2.0*h + i) - (a + 2.0*b + c);
            int idx = y*W + x;
            if (gx_out) gx_out[idx] = gx;
            if (gy_out) gy_out[idx] = gy;
            if (mag_out) mag_out[idx] = sqrt(gx*gx + gy*gy);
        }
    }
    return 1;
}
