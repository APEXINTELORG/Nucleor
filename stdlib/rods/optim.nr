// =====================================================
// rods/optim — Optimization Algorithms
// =====================================================
// Import: import "stdlib/rods/optim.nr"
// Provides: gradient descent, Adam, Nelder-Mead simplex,
//   line search, genetic optimizer.
// =====================================================

#cfile "../runtime/optim_rt.c"

extern fn nuc_opt_gd(grad_f: i64, x0: i64, lr: i64, steps: i64) -> i64;
extern fn nuc_opt_adam(grad_f: i64, x0: i64, lr: i64, steps: i64) -> i64;
extern fn nuc_opt_simplex(f: i64, x0: i64, tol: i64) -> i64;
extern fn nuc_opt_line_search(f: i64, x: i64, dir: i64) -> i64;
extern fn nuc_opt_genetic(f: i64, bounds: i64, pop_size: i64, gens: i64) -> i64;

fn opt_gd(grad_f: i64, x0: i64, lr: i64, steps: i64) -> i64 { return nuc_opt_gd(grad_f, x0, lr, steps); }
fn opt_adam(grad_f: i64, x0: i64, lr: i64, steps: i64) -> i64 { return nuc_opt_adam(grad_f, x0, lr, steps); }
fn opt_simplex(f: i64, x0: i64, tol: i64) -> i64 { return nuc_opt_simplex(f, x0, tol); }
fn opt_line_search(f: i64, x: i64, dir: i64) -> i64 { return nuc_opt_line_search(f, x, dir); }
fn opt_genetic(f: i64, bounds: i64, pop_size: i64, gens: i64) -> i64 { return nuc_opt_genetic(f, bounds, pop_size, gens); }
