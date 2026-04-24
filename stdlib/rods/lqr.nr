// rods/lqr — Discrete infinite-horizon LQR via Riccati iteration.
//
// Given a linear time-invariant system
//   x_{k+1} = A · x_k + B · u_k
// and a quadratic cost
//   J = Σ_k (x_kᵀ Q x_k + u_kᵀ R u_k)
//
// the optimal feedback law is the static gain
//   u_k = −K · x_k
// where K = (R + Bᵀ P B)⁻¹ Bᵀ P A and P solves the discrete
// algebraic Riccati equation
//
//   P = Aᵀ P A − Aᵀ P B (R + Bᵀ P B)⁻¹ Bᵀ P A + Q
//
// Solved here by direct Riccati recursion. Convergent for stabili-
// zable (A, B) with detectable Q^{1/2}.
//
// Complement to `ilqr.nr` and `ddp.nr` (both finite-horizon
// nonlinear). Use LQR when the system is well-modeled by a linear
// time-invariant approximation around an operating point and a
// fixed feedback gain is acceptable.
//
// Workflow:
//
//   import "stdlib/rods/lqr.nr"
//
//   let h = lqr_new(n_x, n_u);
//   for i in 0..n_x { for j in 0..n_x {
//       lqr_set_A(h, i, j, A_ij_b);
//       lqr_set_Q(h, i, j, Q_ij_b);
//   }}
//   for i in 0..n_x { for j in 0..n_u {
//       lqr_set_B(h, i, j, B_ij_b);
//   }}
//   for i in 0..n_u { for j in 0..n_u {
//       lqr_set_R(h, i, j, R_ij_b);
//   }}
//   lqr_solve(h, max_iters, tol_b);
//
//   // Read computed gain K  (size n_u × n_x):
//   for i in 0..n_u { for j in 0..n_x {
//       let k_ij_b = lqr_K(h, i, j);
//   }}
//
//   // Compute feedback control u = -K·x for current state x:
//   //   x_ptr is double[n_x], u_out_ptr is double[n_u]
//   lqr_compute_u(h, x_ptr, u_out_ptr);
//
//   lqr_free(h);
//
// **Limitations** (continuous-time CARE / output-feedback LQR /
// time-varying LQR land in v0.6 if needed):
// - Discrete time only.
// - State-feedback only (full-state measurement assumed).
// - Direct Riccati iteration; for ill-conditioned systems Schur or
//   doubling methods converge faster.
//
// See `stdlib/runtime/lqr_rt.c`.
#cfile "../runtime/lqr_rt.c"

extern fn nuc_lqr_new(n_x: i64, n_u: i64) -> i64;
extern fn nuc_lqr_set_A(h: i64, i: i64, j: i64, v: i64);
extern fn nuc_lqr_set_B(h: i64, i: i64, j: i64, v: i64);
extern fn nuc_lqr_set_Q(h: i64, i: i64, j: i64, v: i64);
extern fn nuc_lqr_set_R(h: i64, i: i64, j: i64, v: i64);
extern fn nuc_lqr_solve(h: i64, max_iters: i64, tol_b: i64) -> i64;
extern fn nuc_lqr_K(h: i64, i: i64, j: i64) -> i64;
extern fn nuc_lqr_P(h: i64, i: i64, j: i64) -> i64;
extern fn nuc_lqr_compute_u(h: i64, x_ptr: i64, u_out_ptr: i64);
extern fn nuc_lqr_free(h: i64);

fn lqr_new(n_x: i64, n_u: i64) -> i64 { return nuc_lqr_new(n_x, n_u); }
fn lqr_set_A(h: i64, i: i64, j: i64, v: i64) { nuc_lqr_set_A(h, i, j, v); }
fn lqr_set_B(h: i64, i: i64, j: i64, v: i64) { nuc_lqr_set_B(h, i, j, v); }
fn lqr_set_Q(h: i64, i: i64, j: i64, v: i64) { nuc_lqr_set_Q(h, i, j, v); }
fn lqr_set_R(h: i64, i: i64, j: i64, v: i64) { nuc_lqr_set_R(h, i, j, v); }

// Iterate the Riccati recursion until ‖P_{k+1} − P_k‖_max < tol or
// max_iters reached. Returns the number of iterations performed.
// Computes the feedback gain K at the end.
fn lqr_solve(h: i64, max_iters: i64, tol_b: i64) -> i64 {
    return nuc_lqr_solve(h, max_iters, tol_b);
}

// Read entry K[i, j] (n_u × n_x) of the optimal feedback gain.
fn lqr_K(h: i64, i: i64, j: i64) -> i64 { return nuc_lqr_K(h, i, j); }
// Read entry P[i, j] (n_x × n_x) of the Riccati solution.
fn lqr_P(h: i64, i: i64, j: i64) -> i64 { return nuc_lqr_P(h, i, j); }

// Compute u = −K · x writing into a caller-allocated double[n_u].
fn lqr_compute_u(h: i64, x_ptr: i64, u_out_ptr: i64) {
    nuc_lqr_compute_u(h, x_ptr, u_out_ptr);
}

fn lqr_free(h: i64) { nuc_lqr_free(h); }
