// rods/lcp — Box LCP solver via Projected Gauss-Seidel (PGS).
//
// Solves the box linear complementarity problem:
//
//   find λ ∈ [lo, hi]  such that  w = M·λ + q  satisfies
//
//     w_i ≥ 0  whenever  λ_i = lo_i
//     w_i ≤ 0  whenever  λ_i = hi_i
//     w_i = 0  whenever  lo_i < λ_i < hi_i
//
// This is the iteration that underlies MuJoCo, Bullet, ODE, and
// most other rigid-body contact solvers.
//
// Use cases:
// - **Unilateral contact**: λ ∈ [0, ∞) gives the standard
//   non-penetration constraint (the default bounds set by
//   `lcp_pgs_new`).
// - **Coulomb friction**: a 2-direction box `[−μ·λ_n, μ·λ_n]` per
//   contact, after pyramidal linearization of the friction cone.
// - **Joint limits**: λ ∈ [−∞, ∞] with extra bounds.
// - **Generic bilateral constraint**: λ ∈ [−∞, ∞] gives a normal
//   linear solve (PGS for symmetric positive-definite systems).
//
// Workflow:
//
//   import "stdlib/rods/lcp.nr"
//
//   let h = lcp_pgs_new(n);
//
//   // Set M (n × n).
//   for i in 0..n  { for j in 0..n {
//       lcp_pgs_set_M(h, i, j, M_ij_b);
//   }}
//
//   // Set q (n).
//   for i in 0..n  { lcp_pgs_set_q(h, i, q_i_b); }
//
//   // Optional: per-variable bounds (defaults to [0, +inf)).
//   lcp_pgs_set_bounds(h, i, lo_b, hi_b);
//
//   // Optional: warm-start.
//   lcp_pgs_set_initial(h, i, lambda0_b);
//
//   let iters = lcp_pgs_solve(h, max_iters, tol_b);
//
//   // Read solution.
//   for i in 0..n { let lam_b = lcp_pgs_get(h, i); ... }
//
//   // Final complementarity residual (≤ tol on success).
//   let res_b = lcp_pgs_residual(h);
//
//   lcp_pgs_free(h);
//
// **Limitations** (Lemke's algorithm / interior-point methods land
// in v0.6 if needed for ill-conditioned systems):
// - PGS is iterative; for ill-conditioned M (very stiff contacts +
//   no soft regularization) convergence may be slow.
// - Generic LCP — caller assembles M and q from contact Jacobians,
//   mass matrix, free velocity, friction pyramid linearization, etc.
//
// See `stdlib/runtime/lcp_rt.c`.
#cfile "../runtime/lcp_rt.c"

extern fn nuc_lcp_pgs_new(n: i64) -> i64;
extern fn nuc_lcp_pgs_set_M(h: i64, i: i64, j: i64, v_b: i64);
extern fn nuc_lcp_pgs_set_q(h: i64, i: i64, v_b: i64);
extern fn nuc_lcp_pgs_set_bounds(h: i64, i: i64, lo_b: i64, hi_b: i64);
extern fn nuc_lcp_pgs_set_initial(h: i64, i: i64, v_b: i64);
extern fn nuc_lcp_pgs_solve(h: i64, max_iters: i64, tol_b: i64) -> i64;
extern fn nuc_lcp_pgs_get(h: i64, i: i64) -> i64;
extern fn nuc_lcp_pgs_residual(h: i64) -> i64;
extern fn nuc_lcp_pgs_free(h: i64);

// Create an empty PGS LCP solver of dimension n. M defaults to all
// zeros, q to all zeros, bounds to [0, +∞), λ to all zeros.
fn lcp_pgs_new(n: i64) -> i64 { return nuc_lcp_pgs_new(n); }

// Set entry M[i, j].
fn lcp_pgs_set_M(h: i64, i: i64, j: i64, v_b: i64) {
    nuc_lcp_pgs_set_M(h, i, j, v_b);
}

// Set entry q[i].
fn lcp_pgs_set_q(h: i64, i: i64, v_b: i64) {
    nuc_lcp_pgs_set_q(h, i, v_b);
}

// Set per-variable bounds [lo, hi]. Default is [0, +∞). Use a very
// large positive number for hi (or pass +∞ via bit-cast) for
// unilateral contacts; use a symmetric finite box for friction
// pyramid components.
fn lcp_pgs_set_bounds(h: i64, i: i64, lo_b: i64, hi_b: i64) {
    nuc_lcp_pgs_set_bounds(h, i, lo_b, hi_b);
}

// Warm-start λ_i. The runtime clamps to [lo, hi].
fn lcp_pgs_set_initial(h: i64, i: i64, v_b: i64) {
    nuc_lcp_pgs_set_initial(h, i, v_b);
}

// Run PGS until either max_iters reached or per-iter max change in
// any λ_i drops below tol. Returns the number of iterations
// actually performed.
fn lcp_pgs_solve(h: i64, max_iters: i64, tol_b: i64) -> i64 {
    return nuc_lcp_pgs_solve(h, max_iters, tol_b);
}

// Read solution component λ_i.
fn lcp_pgs_get(h: i64, i: i64) -> i64 { return nuc_lcp_pgs_get(h, i); }

// Final complementarity-residual norm (max over i of the
// "directional" violation, ≤ tol on convergence).
fn lcp_pgs_residual(h: i64) -> i64 { return nuc_lcp_pgs_residual(h); }

fn lcp_pgs_free(h: i64) { nuc_lcp_pgs_free(h); }
