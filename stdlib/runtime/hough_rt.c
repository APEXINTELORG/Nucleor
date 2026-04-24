// hough_rt.c — Hough transform for line detection from 2D points.
//
// Standard image-processing / laser-scan primitive: each input
// point votes for the family of lines passing through it,
// parameterized by `(ρ, θ)`:
//
//   ρ = x cos θ + y sin θ           with θ ∈ [0, π), ρ ∈ [−ρ_max, ρ_max]
//
// The accumulator is an `n_rho × n_theta` integer grid; peaks
// correspond to lines with many supporting points.
//
// `nuc_hough_lines_2d` is a one-call wrapper that builds the
// accumulator, finds the top-`max_lines` peaks above `threshold`,
// and writes their `(ρ, θ)` parameters.
//
// Use cases:
//   - Laser-scan landmark extraction (walls / corridors).
//   - Structured-environment SLAM front-end.
//   - Extraction of dominant lines from a 2-D feature map.
//
// **Limitations** (probabilistic Hough / circle-Hough / sub-pixel
// peak refinement land in v0.6 if needed):
// - Each point contributes 1 vote per θ-bin (no edge-strength
//   weighting). For weighted voting, replicate input points by
//   their weights or extend the API.
// - Grid-quantized peak locations only (no sub-bin refinement).
// - 2D lines only. Hough circles / 3D lines are separate algorithms.
//
// Compile: clang -c stdlib/runtime/hough_rt.c -o target/hough.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// One-call: build accumulator, extract top-k peaks above threshold.
// Returns the number of lines found (≤ max_lines).
//
//   pts_ptr:    double[n_pts * 2] (xy)
//   n_rho:      number of ρ bins (e.g. 200)
//   n_theta:    number of θ bins (e.g. 180)
//   rho_max_b:  max |ρ| value (e.g. world half-diagonal)
//   threshold:  minimum vote count for a peak to be reported
//   max_lines:  cap on output count
//   out_rho_ptr, out_theta_ptr: caller-allocated double[max_lines]
long long nuc_hough_lines_2d(long long pts_ptr, long long n_pts_,
                              long long n_rho_, long long n_theta_,
                              long long rho_max_b, long long threshold_,
                              long long max_lines_,
                              long long out_rho_ptr, long long out_theta_ptr)
{
    int n_pts   = (int)n_pts_;
    int n_rho   = (int)n_rho_;
    int n_theta = (int)n_theta_;
    int threshold = (int)threshold_;
    int max_lines = (int)max_lines_;
    if (n_pts <= 0 || n_rho < 2 || n_theta < 2 || max_lines <= 0) return 0;
    const double *pts = (const double *)(void *)(size_t)pts_ptr;
    double *out_rho = (double *)(void *)(size_t)out_rho_ptr;
    double *out_theta = (double *)(void *)(size_t)out_theta_ptr;
    if (!pts || !out_rho || !out_theta) return 0;
    double rho_max = _i2f(rho_max_b);
    if (rho_max <= 0) return 0;

    // Precompute sin/cos for all theta bins.
    double *sint = (double *)malloc(n_theta * sizeof(double));
    double *cost = (double *)malloc(n_theta * sizeof(double));
    for (int j = 0; j < n_theta; j++) {
        double t = j * M_PI / n_theta;
        sint[j] = sin(t);
        cost[j] = cos(t);
    }
    double rho_step = (2.0 * rho_max) / n_rho;
    int *acc = (int *)calloc(n_rho * n_theta, sizeof(int));

    // Vote.
    for (int i = 0; i < n_pts; i++) {
        double x = pts[i*2 + 0];
        double y = pts[i*2 + 1];
        for (int j = 0; j < n_theta; j++) {
            double rho = x * cost[j] + y * sint[j];
            int rb = (int)((rho + rho_max) / rho_step);
            if (rb < 0 || rb >= n_rho) continue;
            acc[rb * n_theta + j]++;
        }
    }

    // Extract top peaks above threshold via non-maximum suppression
    // in a 3×3 neighborhood. Greedy: scan, find local max, record.
    long long count = 0;
    for (int rb = 0; rb < n_rho; rb++) {
        for (int j = 0; j < n_theta; j++) {
            int v = acc[rb * n_theta + j];
            if (v < threshold) continue;
            // 3×3 NMS (with periodic θ).
            int is_max = 1;
            for (int dr = -1; dr <= 1 && is_max; dr++) {
                for (int dj = -1; dj <= 1 && is_max; dj++) {
                    if (dr == 0 && dj == 0) continue;
                    int rr = rb + dr;
                    if (rr < 0 || rr >= n_rho) continue;
                    int jj = ((j + dj) % n_theta + n_theta) % n_theta;
                    int vn = acc[rr * n_theta + jj];
                    if (vn > v) is_max = 0;
                }
            }
            if (!is_max) continue;
            if (count >= max_lines) goto done;
            out_rho[count]   = -rho_max + (rb + 0.5) * rho_step;
            out_theta[count] = (j + 0.5) * M_PI / n_theta;
            count++;
        }
    }
done:
    free(sint); free(cost); free(acc);
    return count;
}
