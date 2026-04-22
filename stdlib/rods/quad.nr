// =====================================================
// rods/quad — Numerical Integration (Quadrature)
// =====================================================
// Import: import "stdlib/rods/quad.nr"
// Provides: trapezoid, Simpson, Gauss-Legendre, adaptive,
//   2D, Monte Carlo. Function arguments are closure handles.
// =====================================================

#cfile "../runtime/quad_rt.c"

extern fn nuc_quad_trapezoid(f: i64, a: i64, b: i64, n: i64) -> i64;
extern fn nuc_quad_simpson(f: i64, a: i64, b: i64, n: i64) -> i64;
extern fn nuc_quad_gauss(f: i64, a: i64, b: i64, n: i64) -> i64;
extern fn nuc_quad_adaptive(f: i64, a: i64, b: i64, tol: i64) -> i64;
extern fn nuc_quad_2d(f: i64, ax: i64, bx: i64, ay: i64, by: i64, n: i64) -> i64;
extern fn nuc_quad_monte_carlo(f: i64, lo: i64, hi: i64, n: i64) -> i64;

fn quad_trapezoid(f: i64, a: i64, b: i64, n: i64) -> i64 { return nuc_quad_trapezoid(f, a, b, n); }
fn quad_simpson(f: i64, a: i64, b: i64, n: i64) -> i64 { return nuc_quad_simpson(f, a, b, n); }
fn quad_gauss(f: i64, a: i64, b: i64, n: i64) -> i64 { return nuc_quad_gauss(f, a, b, n); }
fn quad_adaptive(f: i64, a: i64, b: i64, tol: i64) -> i64 { return nuc_quad_adaptive(f, a, b, tol); }
fn quad_2d(f: i64, ax: i64, bx: i64, ay: i64, by: i64, n: i64) -> i64 { return nuc_quad_2d(f, ax, bx, ay, by, n); }
fn quad_monte_carlo(f: i64, lo: i64, hi: i64, n: i64) -> i64 { return nuc_quad_monte_carlo(f, lo, hi, n); }
