// rods/pgs3 — 3D pose graph SLAM optimizer (SE(3) Gauss-Newton).
//
// Three-dimensional generalization of `stdlib/rods/pgs.nr`. Each
// pose is an SE(3) element: a translation in ℝ³ + a rotation in
// SO(3) stored as a unit quaternion (w, x, y, z). Edges encode
// relative-pose measurements with diagonal information weights —
// 3 translational + 3 rotational weights per edge.
//
// Workflow:
//
//   import "stdlib/rods/pgs3.nr"
//
//   let g = pgs3_new(n_nodes);
//
//   // Set initial pose estimates (caller-allocated double[3] for t,
//   // double[4] for q).
//   for i in 0..n_nodes {
//       pgs3_set_node(g, i, t_ptr_i, q_ptr_i);
//   }
//
//   // Add relative-pose measurement edges.
//   //   dt_ptr  — double[3] translation measurement (j in i's frame)
//   //   dq_ptr  — double[4] quaternion measurement
//   //   info_ptr — double[6] diagonal info weights
//   //              [info_tx, info_ty, info_tz, info_rx, info_ry, info_rz]
//   for each edge (i, j) {
//       pgs3_add_edge(g, i, j, dt_ptr, dq_ptr, info_ptr);
//   }
//
//   pgs3_optimize(g, max_iters, tol_b);
//
//   // Read back optimized poses.
//   for i in 0..n_nodes {
//       pgs3_get_node(g, i, t_out_ptr, q_out_ptr);
//   }
//
// Node 0 is gauge-fixed (never moves) to break the global rigid-
// motion ambiguity. Updates use right-multiplied SO(3) exponential:
//   t_i ← t_i + δ_t,   R_i ← R_i · exp(δ_θ).
//
// **Limitations** (closed-form Jacobians, sparse Cholesky, robust
// kernels land in v0.6 if needed):
// - Numerical FD Jacobians (12 residual evaluations per edge per iter);
//   fine for hundreds of edges.
// - Dense Gauss-Jordan linear solve: O(dof³) where dof = 6·(N − 1).
// - Diagonal information weights only (full 6×6 information lands
//   in v0.6 if needed).
// - L₂ cost only — no robust kernels (Huber, Cauchy).
//
// See `stdlib/runtime/pgs3_rt.c`.
#cfile "../runtime/pgs3_rt.c"

extern fn nuc_pgs3_new(n_nodes: i64) -> i64;
extern fn nuc_pgs3_set_node(h: i64, i: i64, t_ptr: i64, q_ptr: i64);
extern fn nuc_pgs3_get_node(h: i64, i: i64, t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_pgs3_add_edge(h: i64, i: i64, j: i64,
    dt_ptr: i64, dq_ptr: i64, info_ptr: i64) -> i64;
extern fn nuc_pgs3_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64;
extern fn nuc_pgs3_total_cost(h: i64) -> i64;
extern fn nuc_pgs3_free(h: i64);

// Create an empty 3D pose graph with n_nodes pose variables.
// Initial poses default to identity (t = 0, q = (1, 0, 0, 0));
// use pgs3_set_node to fill in initial estimates.
fn pgs3_new(n_nodes: i64) -> i64 { return nuc_pgs3_new(n_nodes); }

// Set the initial pose for node `i`. `t_ptr` is `double[3]`
// (translation), `q_ptr` is `double[4]` (unit quaternion in
// scalar-first form: w, x, y, z). Quaternion is normalized
// internally.
fn pgs3_set_node(h: i64, i: i64, t_ptr: i64, q_ptr: i64) {
    nuc_pgs3_set_node(h, i, t_ptr, q_ptr);
}

// Read back the optimized pose for node `i`. `t_out_ptr` is
// caller-allocated `double[3]`, `q_out_ptr` is caller-allocated
// `double[4]`.
fn pgs3_get_node(h: i64, i: i64, t_out_ptr: i64, q_out_ptr: i64) {
    nuc_pgs3_get_node(h, i, t_out_ptr, q_out_ptr);
}

// Add a relative-pose constraint edge from node i to node j. The
// measurement says that node j's pose, expressed in node i's frame,
// is approximately (t_meas, R_meas) where R_meas is the rotation
// encoded in `dq_ptr` (a unit quaternion).
//
// `info_ptr` is `double[6]`: per-DOF diagonal information weights
//   [info_tx, info_ty, info_tz, info_rx, info_ry, info_rz].
fn pgs3_add_edge(h: i64, i: i64, j: i64,
    dt_ptr: i64, dq_ptr: i64, info_ptr: i64) -> i64
{
    return nuc_pgs3_add_edge(h, i, j, dt_ptr, dq_ptr, info_ptr);
}

// Run SE(3) Gauss-Newton iterations. Node 0 is gauge-fixed (never
// moves). Returns the number of iterations actually performed.
fn pgs3_optimize(h: i64, max_iters: i64, tol_b: i64) -> i64 {
    return nuc_pgs3_optimize(h, max_iters, tol_b);
}

// Total residual cost (sum of squared edge errors weighted by
// diagonal information). Useful for verifying that Gauss-Newton
// actually reduced the cost.
fn pgs3_total_cost(h: i64) -> i64 { return nuc_pgs3_total_cost(h); }

fn pgs3_free(h: i64) { nuc_pgs3_free(h); }
