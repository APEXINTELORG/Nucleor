// canny_rt.c — Canny edge detector (Canny 1986).
//
// 4-stage pipeline:
//   1. Compute Sobel gradients Gx, Gy and magnitude G.
//   2. Non-maximum suppression: keep G(x,y) only if it's the
//      max along the gradient direction (compared with the two
//      pixels in the orthogonal direction).
//   3. Double threshold: pixels >= high_thr are "strong",
//      pixels in [low_thr, high_thr) are "weak", below low_thr
//      are suppressed.
//   4. Hysteresis: weak pixels survive iff they are 8-connected
//      to a strong pixel (transitively).
//
// Output is a binary edge map (0 / 255 in the input domain).
//
// Use:
//   - Contour finding for Hough line / circle detection.
//   - Object boundary extraction.
//   - Pre-processing for OCR / barcode / shape matching.
//
// **Limitations** (sub-pixel edge localization / scale-space
// edges land in v0.6 if needed):
// - 4-direction NMS (0°, 45°, 90°, 135°). Sub-pixel
//   interpolation along the gradient direction not yet wired.
// - Single-scale.
//
// Compile: clang -c stdlib/runtime/canny_rt.c -o target/canny.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

static int _clamp_i(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Run the full Canny pipeline. Output `edges_out` is double[H*W]
// with 0 or 255 values (binary edge map).
long long nuc_canny(long long img_ptr, long long W_, long long H_,
                     long long low_b, long long high_b,
                     long long edges_out_ptr)
{
    int W = (int)W_, H = (int)H_;
    const double *img = (const double *)(void *)(size_t)img_ptr;
    double *edges = (double *)(void *)(size_t)edges_out_ptr;
    if (!img || !edges || W < 3 || H < 3) return 0;
    double low = _i2f(low_b);
    double high = _i2f(high_b);
    if (low > high) { double t = low; low = high; high = t; }

    long long N = (long long)W * H;
    double *gx = (double *)calloc((size_t)N, sizeof(double));
    double *gy = (double *)calloc((size_t)N, sizeof(double));
    double *mag = (double *)calloc((size_t)N, sizeof(double));
    double *nms = (double *)calloc((size_t)N, sizeof(double));
    if (!gx || !gy || !mag || !nms) { free(gx); free(gy); free(mag); free(nms); return 0; }

    // Stage 1: Sobel.
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            int xm = _clamp_i(x - 1, 0, W - 1);
            int xp = _clamp_i(x + 1, 0, W - 1);
            int ym = _clamp_i(y - 1, 0, H - 1);
            int yp = _clamp_i(y + 1, 0, H - 1);
            double a = img[ym*W + xm], b = img[ym*W + x ], c = img[ym*W + xp];
            double d = img[y *W + xm];                        double f = img[y *W + xp];
            double g = img[yp*W + xm], h = img[yp*W + x ], i = img[yp*W + xp];
            double Gx = (c + 2.0*f + i) - (a + 2.0*d + g);
            double Gy = (g + 2.0*h + i) - (a + 2.0*b + c);
            int idx = y*W + x;
            gx[idx] = Gx;
            gy[idx] = Gy;
            mag[idx] = sqrt(Gx*Gx + Gy*Gy);
        }
    }

    // Stage 2: non-maximum suppression.
    for (int y = 1; y < H - 1; y++) {
        for (int x = 1; x < W - 1; x++) {
            int idx = y*W + x;
            double m = mag[idx];
            if (m == 0) { nms[idx] = 0; continue; }
            // Quantize gradient direction to 0/45/90/135.
            double angle = atan2(gy[idx], gx[idx]) * (180.0 / 3.141592653589793);
            if (angle < 0) angle += 180.0;
            double n1, n2;
            if (angle < 22.5 || angle >= 157.5) {
                n1 = mag[y*W + (x - 1)]; n2 = mag[y*W + (x + 1)];
            } else if (angle < 67.5) {
                n1 = mag[(y - 1)*W + (x + 1)]; n2 = mag[(y + 1)*W + (x - 1)];
            } else if (angle < 112.5) {
                n1 = mag[(y - 1)*W + x]; n2 = mag[(y + 1)*W + x];
            } else {
                n1 = mag[(y - 1)*W + (x - 1)]; n2 = mag[(y + 1)*W + (x + 1)];
            }
            if (m >= n1 && m >= n2) nms[idx] = m;
            else nms[idx] = 0;
        }
    }

    // Stage 3: double threshold (re-use edges as int8-ish marker).
    // 0 = suppressed, 1 = weak, 2 = strong.
    char *cls = (char *)calloc((size_t)N, sizeof(char));
    if (!cls) { free(gx); free(gy); free(mag); free(nms); return 0; }
    for (long long i = 0; i < N; i++) {
        double v = nms[i];
        if (v >= high) cls[i] = 2;
        else if (v >= low) cls[i] = 1;
        else cls[i] = 0;
    }

    // Stage 4: hysteresis. BFS-style flood: every weak pixel
    // 8-connected to a strong pixel (transitively) becomes strong.
    int *stack = (int *)malloc(sizeof(int) * (size_t)N);
    if (!stack) { free(cls); free(gx); free(gy); free(mag); free(nms); return 0; }
    int sp = 0;
    for (long long i = 0; i < N; i++) if (cls[i] == 2) stack[sp++] = (int)i;
    while (sp > 0) {
        int idx = stack[--sp];
        int x = idx % W, y = idx / W;
        for (int dy = -1; dy <= 1; dy++) {
            int yy = y + dy;
            if (yy < 0 || yy >= H) continue;
            for (int dx = -1; dx <= 1; dx++) {
                int xx = x + dx;
                if (xx < 0 || xx >= W) continue;
                int nidx = yy*W + xx;
                if (cls[nidx] == 1) {
                    cls[nidx] = 2;
                    stack[sp++] = nidx;
                }
            }
        }
    }
    for (long long i = 0; i < N; i++) edges[i] = (cls[i] == 2) ? 255.0 : 0.0;

    free(stack); free(cls);
    free(gx); free(gy); free(mag); free(nms);
    return 1;
}
