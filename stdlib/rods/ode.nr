// =====================================================
// rods/ode — Ordinary Differential Equation Solvers
// =====================================================
// Import: import "stdlib/rods/ode.nr"
// Provides: explicit Euler, fixed-step RK4, adaptive RK45,
//   symplectic (Hamiltonian-preserving), event detection.
// =====================================================

#cfile "../runtime/ode_rt.c"

extern fn nuc_ode_euler(f_ptr: i64, y0: i64, t0: i64, t1: i64, h: i64) -> i64;
extern fn nuc_ode_rk4(f_ptr: i64, y0: i64, t0: i64, t1: i64, h: i64) -> i64;
extern fn nuc_ode_rk45(f_ptr: i64, y0: i64, t0: i64, t1: i64, tol: i64) -> i64;
extern fn nuc_ode_symplectic(grad_V_ptr: i64, q0: i64, p0: i64, t1: i64, h: i64) -> i64;
extern fn nuc_ode_event(f_ptr: i64, y0: i64, event_ptr: i64, t_max: i64) -> i64;

fn ode_euler(f: i64, y0: i64, t0: i64, t1: i64, h: i64) -> i64 { return nuc_ode_euler(f, y0, t0, t1, h); }
fn ode_rk4(f: i64, y0: i64, t0: i64, t1: i64, h: i64) -> i64 { return nuc_ode_rk4(f, y0, t0, t1, h); }
fn ode_rk45(f: i64, y0: i64, t0: i64, t1: i64, tol: i64) -> i64 { return nuc_ode_rk45(f, y0, t0, t1, tol); }
fn ode_symplectic(grad_V: i64, q0: i64, p0: i64, t1: i64, h: i64) -> i64 { return nuc_ode_symplectic(grad_V, q0, p0, t1, h); }
fn ode_event(f: i64, y0: i64, event: i64, t_max: i64) -> i64 { return nuc_ode_event(f, y0, event, t_max); }
