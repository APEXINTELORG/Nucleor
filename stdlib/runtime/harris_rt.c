// harris_rt.c — Harris corner detector (Harris & Stephens 1988).
//
// For each pixel in a grayscale image, computes the response
//
//   M = [ Σ Ix²    Σ Ix·Iy ]
//       [ Σ Ix·Iy  Σ Iy²   ]
//
// where the sums are over a small window around the pixel, and
// the Harris response is
//
//   R = det(M) - k · trace(M)²
//     = (Ix²·Iy² - (Ix·Iy)²) - k · (Ix² + Iy²)²
//
// Pixels with R above a threshold AND R is a 3×3 local maximum are
// reported as corners. Returns the top-K corners sorted by response.
//
// Standard "tuning" choice: k = 0.04. Larger k → fewer / sharper
// corners; smaller k → more / softer corners.
//
// Use:
//   - Visual-odometry feature seeds.
//   - Calibration target detection.
//   - Front-end for KLT (`klt_rt.c`).
//
// Limitations (Shi-Tomasi response / sub-pixel refinement /
// scale-space corner detection (multi-scale Harris) land in v0.6
// if needed):
// - Single-scale only (caller can pre-build a Gaussian pyramid
//   with `image_pyramid.nr` and run Harris per level).
// - Window is a fixed 3×3 box (no Gaussian weighting).
// - Image gradients via central differences (3-tap [-1, 0, 1]
//   per axis).
//
// Compile: clang -c stdlib/runtime/harris_rt.c -o target/harris.obj -O2

#include <string.h>
#include <math.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

static int _clamp_i(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// Detect corners. Inputs:
//   img_ptr   : double[H*W] grayscale image, row-major.
//   k_b       : Harris constant (typical 0.04).
//   threshold : minimum response value to count as a corner.
//   max_n     : output buffer capacity (in corners).
// Outputs:
//   out_xy_ptr  : double[2*max_n] interleaved (x, y).
//   out_resp_ptr: double[max_n]   per-corner Harris response.
// Returns: count of corners written (≤ max_n).
long long nuc_harris_corners(long long img_ptr, long long W_, long long H_,
                              long long k_b, long long threshold_b,
                              long long max_n_,
                              long long out_xy_ptr, long long out_resp_ptr)
{
    int W = (int)W_, H = (int)H_;
    int max_n = (int)max_n_;
    const double *img = (const double *)(void *)(size_t)img_ptr;
    double *out_xy = (double *)(void *)(size_t)out_xy_ptr;
    double *out_resp = (double *)(void *)(size_t)out_resp_ptr;
    if (!img || !out_xy || !out_resp || W < 3 || H < 3 || max_n < 1) return 0;
    double k = _i2f(k_b);
    double thr = _i2f(threshold_b);

    // Compute Ix, Iy via central differences on the interior.
    double *Ix = (double *)calloc((size_t)W * H, sizeof(double));
    double *Iy = (double *)calloc((size_t)W * H, sizeof(double));
    if (!Ix || !Iy) { free(Ix); free(Iy); return 0; }
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++) {
            int xm = _clamp_i(x - 1, 0, W - 1);
            int xp = _clamp_i(x + 1, 0, W - 1);
            int ym = _clamp_i(y - 1, 0, H - 1);
            int yp = _clamp_i(y + 1, 0, H - 1);
            Ix[y*W + x] = 0.5 * (img[y*W + xp] - img[y*W + xm]);
            Iy[y*W + x] = 0.5 * (img[yp*W + x] - img[ym*W + x]);
        }
    }

    // Harris response per pixel: 3×3 box-summed structure tensor.
    double *R = (double *)calloc((size_t)W * H, sizeof(double));
    if (!R) { free(Ix); free(Iy); return 0; }
    for (int y = 1; y < H - 1; y++) {
        for (int x = 1; x < W - 1; x++) {
            double sxx = 0, sxy = 0, syy = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    double ix = Ix[(y+dy)*W + (x+dx)];
                    double iy = Iy[(y+dy)*W + (x+dx)];
                    sxx += ix * ix;
                    sxy += ix * iy;
                    syy += iy * iy;
                }
            }
            double det = sxx * syy - sxy * sxy;
            double trc = sxx + syy;
            R[y*W + x] = det - k * trc * trc;
        }
    }

    // 3×3 NMS + threshold; collect candidates, sort by response, take top.
    typedef struct { double resp, x, y; } Cand;
    int cap = 1024, n = 0;
    Cand *cand = (Cand *)malloc(sizeof(Cand) * cap);
    if (!cand) { free(R); free(Ix); free(Iy); return 0; }
    for (int y = 1; y < H - 1; y++) {
        for (int x = 1; x < W - 1; x++) {
            double v = R[y*W + x];
            if (v < thr) continue;
            int is_peak = 1;
            for (int dy = -1; dy <= 1 && is_peak; dy++) {
                for (int dx = -1; dx <= 1 && is_peak; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    if (R[(y+dy)*W + (x+dx)] > v) is_peak = 0;
                }
            }
            if (!is_peak) continue;
            if (n >= cap) {
                cap *= 2;
                Cand *nc = (Cand *)realloc(cand, sizeof(Cand) * cap);
                if (!nc) { free(cand); free(R); free(Ix); free(Iy); return 0; }
                cand = nc;
            }
            cand[n].resp = v;
            cand[n].x = (double)x;
            cand[n].y = (double)y;
            n++;
        }
    }
    // Insertion sort descending by resp (typical n is small after NMS).
    for (int i = 1; i < n; i++) {
        Cand t = cand[i];
        int j = i - 1;
        while (j >= 0 && cand[j].resp < t.resp) {
            cand[j+1] = cand[j];
            j--;
        }
        cand[j+1] = t;
    }
    int n_out = n < max_n ? n : max_n;
    for (int i = 0; i < n_out; i++) {
        out_xy[i*2+0] = cand[i].x;
        out_xy[i*2+1] = cand[i].y;
        out_resp[i] = cand[i].resp;
    }
    free(cand); free(R); free(Ix); free(Iy);
    return (long long)n_out;
}
