// rods/pgs — 2D pose graph SLAM optimizer (Gauss-Newton).
//
// Standard SLAM back-end: minimize the sum of squared edge errors
// over a graph of relative-pose constraints between robot poses.
// Foundation for SLAM systems where:
// - The front-end (e.g., scan-matching with `icp.nr`, visual
//   odometry, IMU dead-reckoning) produces relative-pose
//   measurements between poses.
// - Loop closures introduce additional edges between non-adjacent
//   poses, fixing accumulated drift.
//
// Workflow:
//   let g = pgs_new(n_nodes);
//   for i in 0..n_nodes { pgs_set_node(g, i, x_i, y_i, theta_i); }
//   for each edge (i, j) with measurement (dx, dy, dtheta) and
//                 information (Ω_xx, Ω_yy, Ω_θθ) {
//     pgs_add_edge(g, i, j, dx_b, dy_b, dtheta_b,
//                  info_xx_b, info_yy_b, info_tt_b);
//   }
//   pgs_optimize(g, max_iters, tol_b);   // Gauss-Newton
//
//   // Read back the optimized poses.
//   let x_h = vec3_new();   // double[3] for x, y, theta out
//   for i in 0..n_nodes {
//     pgs_get_node(g, i, x_ptr, y_ptr, theta_ptr);
//   }
//
// Node 0 is gauge-fixed (never moves) to break the global rigid-
// motion ambiguity. All other nodes are optimization variables.
//
// Limitations (3D pose graphs / sparse Cholesky / robust
// kernels land in v0.6 if needed):
// - 2D only.
// - Dense linear solve via Gauss-Jordan: O(n³) per iter. Fine for
//   ≤ 200 nodes; for large graphs, sparse Cholesky required.
// - L₂ cost only — no robust kernels (Huber, Cauchy) for outlier
//   rejection.
//
// See `stdlib/runtime/pgs_rt.c`.
#cfile "../runtime/pgs_rt.c"

extern fn nuc_pgs_new(n_nodes: i64) -> i64;
extern fn nuc_pgs_set_node(h: i64, i: i64,
    x_b: i64, y_b: i64, theta_b: i64);
extern fn nuc_pgs_get_node(h: i64, i: i64,
    x_out_ptr: i64, y_out_ptr: i64, theta_out_ptr: i64);
extern fn nuc_pgs_add_edge(h: i64, i: i64, j: i64,
    dx_b: i64, dy_b: i64, dtheta_b: i64,
    info_xx_b: i64, info_yy_b: i64, info_tt_b: i64) -> i64;
extern fn nuc_pgs_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64;
extern fn nuc_pgs_optimize_huber(h: i64, max_iters: i64, tol_b: i64, delta_b: i64) -> i64;
extern fn nuc_pgs_optimize_cauchy(h: i64, max_iters: i64, tol_b: i64, c_b: i64) -> i64;
extern fn nuc_pgs_total_cost(h: i64) -> i64;
extern fn nuc_pgs_free(h: i64);

// Create an empty 2D pose graph with n_nodes pose variables.
// Initial node values default to (0, 0, 0); use pgs_set_node to
// fill in initial estimates.
fn pgs_new(n_nodes: i64) -> i64 { return nuc_pgs_new(n_nodes); }

fn pgs_set_node(h: i64, i: i64, x_b: i64, y_b: i64, theta_b: i64) {
    nuc_pgs_set_node(h, i, x_b, y_b, theta_b);
}

// Read back optimized pose for node `i`. The three output pointers
// are caller-allocated `double` (single-element) buffers.
fn pgs_get_node(h: i64, i: i64,
    x_out_ptr: i64, y_out_ptr: i64, theta_out_ptr: i64)
{
    nuc_pgs_get_node(h, i, x_out_ptr, y_out_ptr, theta_out_ptr);
}

// Add a relative-pose constraint edge from node i to node j: the
// measurement says that node j's pose, expressed in node i's
// frame, is approximately (dx, dy, dtheta) with diagonal
// information matrix (info_xx, info_yy, info_tt).
fn pgs_add_edge(h: i64, i: i64, j: i64,
    dx_b: i64, dy_b: i64, dtheta_b: i64,
    info_xx_b: i64, info_yy_b: i64, info_tt_b: i64) -> i64
{
    return nuc_pgs_add_edge(h, i, j, dx_b, dy_b, dtheta_b,
        info_xx_b, info_yy_b, info_tt_b);
}

// Run Gauss-Newton iterations. Node 0 is gauge-fixed. Returns the
// number of iterations actually performed.
fn pgs_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64 {
    return nuc_pgs_optimize(h, max_iters, tol_b);
}

// Huber-robust variant (v0.2.277). Same Gauss-Newton iteration as
// `pgs_optimize`, with each edge's contribution down-weighted by
// the Huber loss so that bad loop-closures (typical SLAM outliers)
// can't dominate the optimization. `delta_b` is the Huber threshold
// (typical 0.5–2.0; tune to ~3σ of the noise model). Pass 0 to
// disable Huber and reduce to vanilla L2.
fn pgs_optimize_huber(h: i64, max_iters: i64, tol_b: i64, delta_b: i64) -> i64 {
    return nuc_pgs_optimize_huber(h, max_iters, tol_b, delta_b);
}

// Cauchy/Lorentzian redescending kernel (v0.2.278). Stronger
// outlier rejection than Huber — the weight `w = 1 / (1 + r²/c²)`
// is < 1 for ALL non-zero residuals (truly redescending), so
// outliers are rejected even if their residual happens to drop
// below the Huber threshold during IRLS convergence. Trade-off:
// inlier estimates are slightly biased. Useful when:
// - Outlier residuals don't drop below the Huber threshold during
//   IRLS convergence (Huber then reverts to L2).
// - Maximum robustness wanted, mild bias acceptable.
//
// `c_b` is the Cauchy scale parameter (typical 0.5–2.0; tune to ~σ).
// Pass 0 to disable.
fn pgs_optimize_cauchy(h: i64, max_iters: i64, tol_b: i64, c_b: i64) -> i64 {
    return nuc_pgs_optimize_cauchy(h, max_iters, tol_b, c_b);
}

// Total residual cost (sum of squared edge errors weighted by
// information). Useful for verifying that Gauss-Newton actually
// reduced the cost.
fn pgs_total_cost(h: i64) -> i64 { return nuc_pgs_total_cost(h); }

fn pgs_free(h: i64) { nuc_pgs_free(h); }
