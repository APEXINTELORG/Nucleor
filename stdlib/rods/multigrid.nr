// =====================================================
// rods/multigrid — Multigrid PDE Solver
// =====================================================
// Import: import "stdlib/rods/multigrid.nr"
// Provides: 2D multigrid Poisson solve + residual norm.
// =====================================================

#cfile "../runtime/multigrid_rt.c"

extern fn nuc_mg_solve_2d(rhs: i64, sol: i64, N: i64, tol: i64) -> i64;
extern fn nuc_mg_residual(sol: i64, rhs: i64, N: i64) -> i64;

fn mg_solve_2d(rhs: i64, sol: i64, N: i64, tol: i64) -> i64 { return nuc_mg_solve_2d(rhs, sol, N, tol); }
fn mg_residual(sol: i64, rhs: i64, N: i64) -> i64 { return nuc_mg_residual(sol, rhs, N); }
