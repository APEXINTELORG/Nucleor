// fast_corner_rt.c — FAST corner detector (Rosten & Drummond 2006).
// "Features from Accelerated Segment Test."
//
// For each candidate pixel p, examines a 16-pixel circle (Bresenham
// radius 3 around p). p is a corner iff there exist N consecutive
// pixels on the circle that are ALL brighter than I_p + threshold,
// or ALL darker than I_p - threshold. Standard "FAST-N" with N=9
// or N=12; this implementation uses N=9 (the default).
//
// FAST is faster than Harris (no gradient computation, just pixel
// comparisons) but more sensitive to image noise. Standard
// front-end for ORB feature descriptors.
//
// Use:
//   - Real-time visual-odometry feature seeds.
//   - ORB / oFAST / SLAM frontends.
//
// **Limitations** (Bresenham circle radius is fixed at 3 / scale-
// space FAST land in v0.6 if needed):
// - Single-scale. Pre-build a Gaussian pyramid via
//   `image_pyramid.nr` and run FAST per level for multi-scale.
// - Hard-coded N=9 segment length.
// - No 3×3 NMS in this version (caller can run NMS on the
//   reported corners using their `score` value).
//
// Compile: clang -c stdlib/runtime/fast_corner_rt.c -o target/fast_corner.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

// Bresenham radius-3 circle: 16 (dx, dy) offsets.
static const int CIRC_DX[16] = {  0,  1,  2,  3,  3,  3,  2,  1,  0, -1, -2, -3, -3, -3, -2, -1};
static const int CIRC_DY[16] = { -3, -3, -2, -1,  0,  1,  2,  3,  3,  3,  2,  1,  0, -1, -2, -3};

// Detect FAST-9 corners. Inputs:
//   img_ptr   : double[H*W] grayscale image, row-major.
//   threshold : intensity difference required to count "brighter"
//               or "darker".
//   nms       : 1 = apply 3×3 NMS on score; 0 = report all.
//   max_n     : output buffer capacity (in corners).
// Outputs:
//   out_xy_ptr   : double[2*max_n] interleaved (x, y).
//   out_score_ptr: double[max_n]   sum of |I_circle - I_center| over
//                                   the 16-pixel circle (proxy
//                                   "cornerness").
// Returns: count of corners written (≤ max_n).
long long nuc_fast_corners(long long img_ptr, long long W_, long long H_,
                            long long threshold_b, long long nms_,
                            long long max_n_,
                            long long out_xy_ptr, long long out_score_ptr)
{
    int W = (int)W_, H = (int)H_;
    int max_n = (int)max_n_;
    int do_nms = (int)nms_;
    const double *img = (const double *)(void *)(size_t)img_ptr;
    double *out_xy = (double *)(void *)(size_t)out_xy_ptr;
    double *out_score = (double *)(void *)(size_t)out_score_ptr;
    if (!img || !out_xy || !out_score || W < 7 || H < 7 || max_n < 1) return 0;
    double thr = _i2f(threshold_b);

    // Score map for optional NMS.
    double *score = NULL;
    if (do_nms) {
        score = (double *)calloc((size_t)W * H, sizeof(double));
        if (!score) return 0;
    }

    typedef struct { double s, x, y; } Cand;
    int cap = 1024, n = 0;
    Cand *cand = (Cand *)malloc(sizeof(Cand) * cap);
    if (!cand) { free(score); return 0; }

    // Border 3 to keep circle inside image.
    for (int y = 3; y < H - 3; y++) {
        for (int x = 3; x < W - 3; x++) {
            double Ip = img[y*W + x];
            // High-speed early-reject: pixels 0, 4, 8, 12 (N, E, S, W).
            // For N=9 we need at least 2 of these to agree on the
            // direction (since 9 consecutive on a 16-circle covers
            // roughly half the cardinal pixels).
            double v0 = img[(y - 3)*W + x];
            double v4 = img[y*W + (x + 3)];
            double v8 = img[(y + 3)*W + x];
            double v12 = img[y*W + (x - 3)];
            int hi = 0, lo = 0;
            if (v0 > Ip + thr) hi++;
            if (v4 > Ip + thr) hi++;
            if (v8 > Ip + thr) hi++;
            if (v12 > Ip + thr) hi++;
            if (v0 < Ip - thr) lo++;
            if (v4 < Ip - thr) lo++;
            if (v8 < Ip - thr) lo++;
            if (v12 < Ip - thr) lo++;
            if (hi < 2 && lo < 2) continue;
            // Full check: 16-pixel circle, look for ≥ 9 consecutive
            // (with wraparound). Walk 16+9 entries and track the
            // longest run satisfying brighter/darker.
            int classes[16];
            for (int i = 0; i < 16; i++) {
                double v = img[(y + CIRC_DY[i])*W + (x + CIRC_DX[i])];
                if (v > Ip + thr) classes[i] = 1;
                else if (v < Ip - thr) classes[i] = -1;
                else classes[i] = 0;
            }
            int max_run_hi = 0, max_run_lo = 0;
            int run_hi = 0, run_lo = 0;
            for (int i = 0; i < 16 + 9; i++) {
                int c = classes[i % 16];
                if (c == 1) { run_hi++; run_lo = 0; if (run_hi > max_run_hi) max_run_hi = run_hi; }
                else if (c == -1) { run_lo++; run_hi = 0; if (run_lo > max_run_lo) max_run_lo = run_lo; }
                else { run_hi = 0; run_lo = 0; }
            }
            if (max_run_hi < 9 && max_run_lo < 9) continue;
            // Score: sum of |circle - center|.
            double s = 0;
            for (int i = 0; i < 16; i++) {
                double v = img[(y + CIRC_DY[i])*W + (x + CIRC_DX[i])];
                s += fabs(v - Ip);
            }
            if (do_nms) score[y*W + x] = s;
            if (n >= cap) {
                cap *= 2;
                Cand *nc = (Cand *)realloc(cand, sizeof(Cand) * cap);
                if (!nc) { free(cand); free(score); return 0; }
                cand = nc;
            }
            cand[n].s = s; cand[n].x = (double)x; cand[n].y = (double)y;
            n++;
        }
    }

    // Optional NMS pass: a corner survives only if its score is the
    // 3×3 maximum.
    if (do_nms) {
        int filtered = 0;
        for (int i = 0; i < n; i++) {
            int x = (int)cand[i].x;
            int y = (int)cand[i].y;
            double v = cand[i].s;
            int is_peak = 1;
            for (int dy = -1; dy <= 1 && is_peak; dy++) {
                for (int dx = -1; dx <= 1 && is_peak; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    if (score[(y+dy)*W + (x+dx)] > v) is_peak = 0;
                }
            }
            if (is_peak) cand[filtered++] = cand[i];
        }
        n = filtered;
    }

    // Sort descending by score so caller can take top-K.
    for (int i = 1; i < n; i++) {
        Cand t = cand[i];
        int j = i - 1;
        while (j >= 0 && cand[j].s < t.s) { cand[j+1] = cand[j]; j--; }
        cand[j+1] = t;
    }
    int n_out = n < max_n ? n : max_n;
    for (int i = 0; i < n_out; i++) {
        out_xy[i*2+0] = cand[i].x;
        out_xy[i*2+1] = cand[i].y;
        out_score[i] = cand[i].s;
    }
    free(cand);
    if (score) free(score);
    return (long long)n_out;
}
