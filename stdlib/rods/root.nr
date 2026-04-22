// =====================================================
// rods/root — Root Finding for Nonlinear Equations
// =====================================================
// Import: import "stdlib/rods/root.nr"
// Provides: bisection, Newton's method, secant, Brent,
//   and multi-dimensional Newton for systems.
// =====================================================

#cfile "../runtime/root_rt.c"

extern fn nuc_root_bisection(f: i64, a: i64, b: i64, tol: i64) -> i64;
extern fn nuc_root_newton(f: i64, df: i64, x0: i64, tol: i64) -> i64;
extern fn nuc_root_secant(f: i64, x0: i64, x1: i64, tol: i64) -> i64;
extern fn nuc_root_brent(f: i64, a: i64, b: i64, tol: i64) -> i64;
extern fn nuc_root_system(F: i64, J: i64, x0: i64, tol: i64) -> i64;

fn root_bisection(f: i64, a: i64, b: i64, tol: i64) -> i64 { return nuc_root_bisection(f, a, b, tol); }
fn root_newton(f: i64, df: i64, x0: i64, tol: i64) -> i64 { return nuc_root_newton(f, df, x0, tol); }
fn root_secant(f: i64, x0: i64, x1: i64, tol: i64) -> i64 { return nuc_root_secant(f, x0, x1, tol); }
fn root_brent(f: i64, a: i64, b: i64, tol: i64) -> i64 { return nuc_root_brent(f, a, b, tol); }
fn root_system(F: i64, J: i64, x0: i64, tol: i64) -> i64 { return nuc_root_system(F, J, x0, tol); }
