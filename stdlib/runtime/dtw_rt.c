// dtw_rt.c — Dynamic Time Warping (DTW) sequence-similarity
// distance for n-dimensional time series.
//
// Given two sequences `A ∈ ℝ^{M × dim}` and `B ∈ ℝ^{N × dim}`,
// computes the cost of the optimal alignment between them where
// each step of the alignment can match (i, j) by either advancing
// in A, in B, or both. This makes DTW tolerant of local time-axis
// stretches that confuse Euclidean point-to-point comparison.
//
// Algorithm (Sakoe & Chiba 1978):
//   Cost matrix d[i, j] = ‖A[i] − B[j]‖
//   Accumulated  D[0, 0] = d[0, 0]
//                D[0, j] = d[0, j] + D[0, j-1]
//                D[i, 0] = d[i, 0] + D[i-1, 0]
//                D[i, j] = d[i, j] + min(D[i-1, j], D[i, j-1], D[i-1, j-1])
//   DTW distance = D[M-1, N-1]
//
// Optional Sakoe-Chiba band (`|i − j·M/N| ≤ band`) restricts
// alignment slope and reduces work from `O(M·N)` to `O(band·max(M, N))`.
//
// Use cases:
//   - Trajectory tracking error under time-axis variability.
//   - Gesture / motion-template matching.
//   - Demonstration matching for learning-from-demo.
//
// **Limitations** (full DTW path / lower-bound functions / soft-DTW
// land in v0.6 if needed):
// - Distance only; no path backtrack here (simplest API). Add a
//   path variant later if needed for warping-curve visualization.
// - Euclidean distance metric only.
//
// Compile: clang -c stdlib/runtime/dtw_rt.c -o target/dtw.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static double _eucl(const double *a, const double *b, int dim) {
    double s = 0;
    for (int k = 0; k < dim; k++) {
        double d = a[k] - b[k];
        s += d * d;
    }
    return sqrt(s);
}

// Compute the DTW distance with no band restriction. O(M·N).
long long nuc_dtw_distance(long long a_ptr, long long M_, long long b_ptr,
                            long long N_, long long dim_)
{
    int M = (int)M_, N = (int)N_, dim = (int)dim_;
    if (M <= 0 || N <= 0 || dim <= 0) return _f2i(0.0);
    double *A = (double *)(void *)(size_t)a_ptr;
    double *B = (double *)(void *)(size_t)b_ptr;
    if (!A || !B) return _f2i(0.0);
    double *D = (double *)malloc(M * N * sizeof(double));
    D[0] = _eucl(A, B, dim);
    for (int j = 1; j < N; j++) D[j] = D[j-1] + _eucl(A, B + j*dim, dim);
    for (int i = 1; i < M; i++) D[i*N] = D[(i-1)*N] + _eucl(A + i*dim, B, dim);
    for (int i = 1; i < M; i++) {
        for (int j = 1; j < N; j++) {
            double d_ij = _eucl(A + i*dim, B + j*dim, dim);
            double a1 = D[(i-1)*N + j];
            double a2 = D[i*N + (j-1)];
            double a3 = D[(i-1)*N + (j-1)];
            double m = a1 < a2 ? a1 : a2;
            if (a3 < m) m = a3;
            D[i*N + j] = d_ij + m;
        }
    }
    double result = D[(M-1)*N + (N-1)];
    free(D);
    return _f2i(result);
}

// Same as above but restricted by a Sakoe-Chiba band: only cells
// `|i − j·M/N| ≤ band` are considered. Returns +∞ if no alignment
// exists within the band.
long long nuc_dtw_distance_band(long long a_ptr, long long M_, long long b_ptr,
                                 long long N_, long long dim_, long long band_)
{
    int M = (int)M_, N = (int)N_, dim = (int)dim_, band = (int)band_;
    if (M <= 0 || N <= 0 || dim <= 0) return _f2i(0.0);
    if (band < 1) band = 1;
    double *A = (double *)(void *)(size_t)a_ptr;
    double *B = (double *)(void *)(size_t)b_ptr;
    if (!A || !B) return _f2i(0.0);

    double *D = (double *)malloc(M * N * sizeof(double));
    for (int i = 0; i < M*N; i++) D[i] = INFINITY;
    D[0] = _eucl(A, B, dim);

    // Compute slope for the diagonal: i ≈ j · (M-1)/(N-1).
    double slope = (double)(M - 1) / (double)(N - 1 > 0 ? N - 1 : 1);
    for (int i = 0; i < M; i++) {
        double j_center = (double)i / slope;
        int j_lo = (int)(j_center - band); if (j_lo < 0) j_lo = 0;
        int j_hi = (int)(j_center + band); if (j_hi > N - 1) j_hi = N - 1;
        for (int j = j_lo; j <= j_hi; j++) {
            if (i == 0 && j == 0) continue;
            double d_ij = _eucl(A + i*dim, B + j*dim, dim);
            double best = INFINITY;
            if (i > 0)            { double v = D[(i-1)*N + j];     if (v < best) best = v; }
            if (j > 0)            { double v = D[i*N + (j-1)];     if (v < best) best = v; }
            if (i > 0 && j > 0)   { double v = D[(i-1)*N + (j-1)]; if (v < best) best = v; }
            D[i*N + j] = d_ij + best;
        }
    }
    double result = D[(M-1)*N + (N-1)];
    free(D);
    return _f2i(result);
}

// Average-DTW (DTW distance divided by alignment-path length M+N-1).
// Useful for comparing DTW values across sequences of different
// lengths.
long long nuc_dtw_distance_normalized(long long a_ptr, long long M_, long long b_ptr,
                                       long long N_, long long dim_)
{
    int M = (int)M_, N = (int)N_;
    long long d_b = nuc_dtw_distance(a_ptr, M_, b_ptr, N_, dim_);
    double d = _i2f(d_b);
    int path_len = M + N - 1;
    if (path_len < 1) path_len = 1;
    return _f2i(d / path_len);
}
