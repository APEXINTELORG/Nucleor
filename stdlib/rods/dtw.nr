// rods/dtw — Dynamic Time Warping (Sakoe & Chiba 1978) for
// n-dimensional time series.
//
// Computes the minimum-cost alignment between two sequences where
// each step can match `(i, j)` by either advancing in A, in B, or
// both. This makes DTW tolerant of local time-axis stretches that
// confuse Euclidean point-to-point comparison — useful for
// trajectory tracking error, gesture / motion-template matching,
// and learning-from-demonstration matching.
//
// Sequences are caller-allocated row-major buffers:
//   A: `double[M * dim]`  (M timesteps × dim coords per timestep)
//   B: `double[N * dim]`
//
// Workflow:
//
//   import "stdlib/rods/dtw.nr"
//
//   // Distance only, full O(M·N) DP:
//   let d_b = dtw_distance(a_ptr, M, b_ptr, N, dim);
//
//   // Sakoe-Chiba band restricts the alignment slope (faster + can
//   // reject "too warped" matches):
//   let d_b = dtw_distance_band(a_ptr, M, b_ptr, N, dim, band);
//
//   // Normalized by alignment path length (M + N − 1):
//   let avg_b = dtw_distance_normalized(a_ptr, M, b_ptr, N, dim);
//
// **Limitations** (warping path backtrack / lower-bound functions /
// soft-DTW land in v0.6 if needed):
// - Distance only; no path backtrack.
// - Euclidean point distance only.
//
// See `stdlib/runtime/dtw_rt.c`.
#cfile "../runtime/dtw_rt.c"

extern fn nuc_dtw_distance(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64) -> i64;
extern fn nuc_dtw_distance_band(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64, band: i64) -> i64;
extern fn nuc_dtw_distance_normalized(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64) -> i64;

// Full DTW distance, no band restriction.
fn dtw_distance(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64) -> i64 {
    return nuc_dtw_distance(a_ptr, M, b_ptr, N, dim);
}

// DTW distance restricted by a Sakoe-Chiba band of width `band`
// cells. Returns +∞ if no alignment fits within the band.
fn dtw_distance_band(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64, band: i64) -> i64 {
    return nuc_dtw_distance_band(a_ptr, M, b_ptr, N, dim, band);
}

// DTW distance divided by alignment path length `M + N − 1`.
fn dtw_distance_normalized(a_ptr: i64, M: i64, b_ptr: i64, N: i64, dim: i64) -> i64 {
    return nuc_dtw_distance_normalized(a_ptr, M, b_ptr, N, dim);
}
