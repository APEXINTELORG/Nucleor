// hough_circle_rt.c — Hough transform for circle detection.
//
// Companion to `hough_rt.c` (lines). Each 2-D edge point votes
// for every circle of radius R that could pass through it,
// parameterized by center `(cx, cy)`:
//
//   For point (x, y) and candidate radius R, all centers lie on
//   the circle `(cx − x)² + (cy − y)² = R²`. Discretize candidate
//   radii to bins R_k ∈ [R_min, R_max], step dR; for each (x, y)
//   and each R_k, vote for every (cx, cy) on the candidate ring.
//
// Accumulator is `n_cx × n_cy × n_R` integer grid. Peaks above a
// threshold give the (cx, cy, R) triples of the detected circles.
//
// Returns the top-`max_circles` peaks as `(cx, cy, R, votes)`.
//
// Use cases:
//   - Detecting wheels / pillars in robotic perception.
//   - Coin / disc detection in CAD-like images.
//   - Pupil / iris detection in eye tracking.
//
// **Limitations** (gradient-direction voting / sub-pixel peak
// refinement / fast 21HT pre-screening land in v0.6 if needed):
// - Each (x, y) contributes uniformly along the candidate ring
//   for each radius — no edge-orientation pruning. For dense
//   point clouds this is O(N · R · 360°). Caller can subsample.
// - Grid-quantized peak locations only.
// - 2-D circles only.
//
// Compile: clang -c stdlib/runtime/hough_circle_rt.c -o target/hough_circle.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// Build the accumulator and return the top circles.
//
// Inputs:
//   pts_xy_ptr : double[2*N] interleaved (x, y) edge points.
//   n_pts      : N
//   cx_min, cx_max, n_cx : center-x grid (n_cx bins)
//   cy_min, cy_max, n_cy : center-y grid
//   R_min,  R_max,  n_R  : radius grid (n_R bins)
//   n_theta              : number of angles to sample on each ring
//                          (typical 360 for 1° resolution)
//   threshold            : minimum vote count for a peak
//   max_circles          : max number of circles to return
//   out_circles_ptr      : double[4*max_circles] result, packed
//                          (cx, cy, R, votes)
//
// Returns: actual number of circles written (≤ max_circles).
long long nuc_hough_circles_2d(long long pts_xy_ptr, long long n_pts_,
    long long cx_min_b, long long cx_max_b, long long n_cx_,
    long long cy_min_b, long long cy_max_b, long long n_cy_,
    long long R_min_b,  long long R_max_b,  long long n_R_,
    long long n_theta_,
    long long threshold_,
    long long max_circles_,
    long long out_circles_ptr)
{
    int N = (int)n_pts_;
    int n_cx = (int)n_cx_, n_cy = (int)n_cy_, n_R = (int)n_R_;
    int n_theta = (int)n_theta_;
    int threshold = (int)threshold_;
    int max_circles = (int)max_circles_;
    const double *pts = (const double *)(void *)(size_t)pts_xy_ptr;
    double *out = (double *)(void *)(size_t)out_circles_ptr;
    if (!pts || !out || N < 1 || n_cx < 1 || n_cy < 1 || n_R < 1 ||
        n_theta < 4 || max_circles < 1) return 0;

    double cx_min = _i2f(cx_min_b), cx_max = _i2f(cx_max_b);
    double cy_min = _i2f(cy_min_b), cy_max = _i2f(cy_max_b);
    double R_min = _i2f(R_min_b),  R_max = _i2f(R_max_b);
    double dcx = (cx_max - cx_min) / n_cx;
    double dcy = (cy_max - cy_min) / n_cy;
    double dR  = (R_max  - R_min)  / n_R;
    if (dcx <= 0 || dcy <= 0 || dR <= 0) return 0;

    long long total = (long long)n_cx * n_cy * n_R;
    int *acc = (int *)calloc(total, sizeof(int));
    if (!acc) return 0;

    // Precompute ring sample directions.
    double *cos_t = (double *)malloc(sizeof(double) * n_theta);
    double *sin_t = (double *)malloc(sizeof(double) * n_theta);
    if (!cos_t || !sin_t) { free(cos_t); free(sin_t); free(acc); return 0; }
    for (int i = 0; i < n_theta; i++) {
        double th = 2.0 * M_PI * i / n_theta;
        cos_t[i] = cos(th);
        sin_t[i] = sin(th);
    }

    for (int p = 0; p < N; p++) {
        double px = pts[p*2+0], py = pts[p*2+1];
        for (int rk = 0; rk < n_R; rk++) {
            double R = R_min + (rk + 0.5) * dR;
            for (int t = 0; t < n_theta; t++) {
                double cx_w = px - R * cos_t[t];
                double cy_w = py - R * sin_t[t];
                int ix = (int)floor((cx_w - cx_min) / dcx);
                int iy = (int)floor((cy_w - cy_min) / dcy);
                if (ix < 0 || ix >= n_cx || iy < 0 || iy >= n_cy) continue;
                acc[((long long)rk * n_cy + iy) * n_cx + ix]++;
            }
        }
    }

    // 3x3x3 NMS in (cx, cy) plane per radius slice + threshold.
    // Collect all qualifying peaks then sort descending and write
    // up to max_circles to the output.
    typedef struct { int votes; double cx, cy, R; } Cand;
    int cap = 1024, ncand = 0;
    Cand *cand = (Cand *)malloc(sizeof(Cand) * cap);
    if (!cand) { free(cos_t); free(sin_t); free(acc); return 0; }

    // 3×3×3 NMS in (cx, cy, R) with lex-order tie-breaking:
    // among plateau cells of equal votes, only the lex-smallest
    // index (dR, dy, dx) triple wins.
    for (int rk = 0; rk < n_R; rk++) {
        for (int iy = 0; iy < n_cy; iy++) {
            for (int ix = 0; ix < n_cx; ix++) {
                int v = acc[((long long)rk * n_cy + iy) * n_cx + ix];
                if (v < threshold) continue;
                int is_peak = 1;
                for (int dR = -1; dR <= 1 && is_peak; dR++) {
                    int rr = rk + dR;
                    if (rr < 0 || rr >= n_R) continue;
                    for (int dy = -1; dy <= 1 && is_peak; dy++) {
                        int yy = iy + dy;
                        if (yy < 0 || yy >= n_cy) continue;
                        for (int dx = -1; dx <= 1 && is_peak; dx++) {
                            int xx = ix + dx;
                            if (xx < 0 || xx >= n_cx) continue;
                            if (dR == 0 && dy == 0 && dx == 0) continue;
                            int neighbor = acc[((long long)rr * n_cy + yy) * n_cx + xx];
                            // Lex-order tie-break: earlier indices win.
                            int is_earlier = (dR < 0) ||
                                (dR == 0 && dy < 0) ||
                                (dR == 0 && dy == 0 && dx < 0);
                            if (is_earlier) {
                                if (neighbor >= v) is_peak = 0;
                            } else {
                                if (neighbor > v) is_peak = 0;
                            }
                        }
                    }
                }
                if (!is_peak) continue;
                if (ncand >= cap) {
                    cap *= 2;
                    Cand *nc = (Cand *)realloc(cand, sizeof(Cand) * cap);
                    if (!nc) { free(cand); free(cos_t); free(sin_t); free(acc); return 0; }
                    cand = nc;
                }
                cand[ncand].votes = v;
                cand[ncand].cx = cx_min + (ix + 0.5) * dcx;
                cand[ncand].cy = cy_min + (iy + 0.5) * dcy;
                cand[ncand].R  = R_min  + (rk + 0.5) * dR;
                ncand++;
            }
        }
    }

    // Insertion sort descending by votes (small N typically).
    for (int i = 1; i < ncand; i++) {
        Cand t = cand[i];
        int j = i - 1;
        while (j >= 0 && cand[j].votes < t.votes) {
            cand[j+1] = cand[j];
            j--;
        }
        cand[j+1] = t;
    }
    int n_out = ncand < max_circles ? ncand : max_circles;
    for (int i = 0; i < n_out; i++) {
        out[i*4+0] = cand[i].cx;
        out[i*4+1] = cand[i].cy;
        out[i*4+2] = cand[i].R;
        out[i*4+3] = (double)cand[i].votes;
    }

    free(cand); free(cos_t); free(sin_t); free(acc);
    return (long long)n_out;
}
