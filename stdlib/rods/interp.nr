// =====================================================
// rods/interp — Interpolation and Approximation
// =====================================================
// Import: import "stdlib/rods/interp.nr"
// Provides: linear, cubic spline, Lagrange, Chebyshev (fit + eval),
//   2D bilinear, RBF (radial basis function).
// =====================================================

#cfile "../runtime/interp_rt.c"

extern fn nuc_interp_linear(xs: i64, ys: i64, x: i64) -> i64;
extern fn nuc_interp_cubic_spline(xs: i64, ys: i64, x: i64) -> i64;
extern fn nuc_interp_lagrange(xs: i64, ys: i64, x: i64) -> i64;
extern fn nuc_interp_chebyshev(f: i64, n: i64, a: i64, b: i64) -> i64;
extern fn nuc_interp_eval_chebyshev(coeffs: i64, x: i64, a: i64, b: i64) -> i64;
extern fn nuc_interp_2d_bilinear(grid: i64, Nx: i64, Ny: i64, x: i64, y: i64) -> i64;
extern fn nuc_interp_rbf(centers: i64, weights: i64, x: i64, sigma: i64) -> i64;

fn interp_linear(xs: i64, ys: i64, x: i64) -> i64 { return nuc_interp_linear(xs, ys, x); }
fn interp_cubic_spline(xs: i64, ys: i64, x: i64) -> i64 { return nuc_interp_cubic_spline(xs, ys, x); }
fn interp_lagrange(xs: i64, ys: i64, x: i64) -> i64 { return nuc_interp_lagrange(xs, ys, x); }
fn interp_chebyshev_fit(f: i64, n: i64, a: i64, b: i64) -> i64 { return nuc_interp_chebyshev(f, n, a, b); }
fn interp_chebyshev_eval(coeffs: i64, x: i64, a: i64, b: i64) -> i64 { return nuc_interp_eval_chebyshev(coeffs, x, a, b); }
fn interp_2d_bilinear(grid: i64, Nx: i64, Ny: i64, x: i64, y: i64) -> i64 { return nuc_interp_2d_bilinear(grid, Nx, Ny, x, y); }
fn interp_rbf(centers: i64, weights: i64, x: i64, sigma: i64) -> i64 { return nuc_interp_rbf(centers, weights, x, sigma); }
