// =====================================================
// rods/bspline — B-Splines and KAN
// =====================================================
// Import: import "stdlib/rods/bspline.nr"
// Provides: B-spline evaluation, basis functions, derivatives,
//   uniform knot vector generation, KAN (Kolmogorov-Arnold)
//   forward pass.
// =====================================================

#cfile "../runtime/bspline_rt.c"

extern fn nuc_bspline_eval(knots: i64, ctrl: i64, order: i64, x: i64) -> i64;
extern fn nuc_bspline_basis_all(knots: i64, n_basis: i64, order: i64, x: i64) -> i64;
extern fn nuc_bspline_deriv(knots: i64, ctrl: i64, order: i64, x: i64) -> i64;
extern fn nuc_bspline_uniform_knots(n_basis: i64, order: i64, a: i64, b: i64) -> i64;
extern fn nuc_bspline_kan_forward(inputs: i64, weights: i64, knots: i64, batch: i64, in_dim: i64, out_dim: i64, n_basis: i64, order: i64) -> i64;

fn bspline_eval(knots: i64, ctrl: i64, order: i64, x: i64) -> i64 { return nuc_bspline_eval(knots, ctrl, order, x); }
fn bspline_basis_all(knots: i64, n_basis: i64, order: i64, x: i64) -> i64 { return nuc_bspline_basis_all(knots, n_basis, order, x); }
fn bspline_deriv(knots: i64, ctrl: i64, order: i64, x: i64) -> i64 { return nuc_bspline_deriv(knots, ctrl, order, x); }
fn bspline_uniform_knots(n_basis: i64, order: i64, a: i64, b: i64) -> i64 { return nuc_bspline_uniform_knots(n_basis, order, a, b); }
fn bspline_kan_forward(inputs: i64, weights: i64, knots: i64, batch: i64, in_dim: i64, out_dim: i64, n_basis: i64, order: i64) -> i64 {
    return nuc_bspline_kan_forward(inputs, weights, knots, batch, in_dim, out_dim, n_basis, order);
}
