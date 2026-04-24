// rods/ddp — Differential Dynamic Programming (Mayne 1966; Jacobson
// & Mayne 1970). Second-order extension of iLQR.
//
// Where iLQR drops the second-derivative tensors of the dynamics
// (Gauss-Newton style), DDP includes them in the Q-function update:
//
//   Q_xx = l_xx + Aᵀ V_xx A + Σ_k V_x[k] · f_xx[k]
//   Q_uu = l_uu + Bᵀ V_xx B + Σ_k V_x[k] · f_uu[k]
//   Q_ux =        Bᵀ V_xx A + Σ_k V_x[k] · f_ux[k]
//
// where f_xx, f_uu, f_ux are the dynamics Hessians w.r.t. (x,x),
// (u,u), and (u,x). DDP converges quadratically near the optimum
// (vs iLQR's superlinear) at the cost of computing those Hessians.
//
// Use when:
// - You're hot-starting near the optimum and want fast final
//   convergence (e.g., MPC inner loop after a warm start).
// - The dynamics are smooth and the Hessian terms are well-defined.
//
// Stick with iLQR (`stdlib/rods/ilqr.nr`) when:
// - State dimension is large (≥ ~10) — Hessian FD cost dominates.
// - Dynamics are stiff or non-smooth — Hessians are noisy.
//
// **Limitations** (analytical Hessians via a tensor callback land
// in v0.6 if needed for performance):
// - Numerical FD for dynamics Hessians (slow for large n_x).
// - Same diagonal cost-Hessian approximation as iLQR.
// - No box constraints on u (Tassa-style bound-projected DDP variant
//   lands in v0.6 if needed).
//
// See `stdlib/runtime/ddp_rt.c`.
#cfile "../runtime/ddp_rt.c"

extern fn nuc_ddp_optimize(
    n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64;

extern fn nuc_ddp_total_cost(
    n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64;

// Optimize a trajectory's control sequence in place using DDP. Same
// I/O contract as `ilqr_optimize` — `u_seq_ptr` is a caller-allocated
// `double[T * n_u]` buffer modified in place. Returns the number of
// DDP iterations actually performed (≤ max_iters).
fn ddp_optimize(n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64
{
    return nuc_ddp_optimize(n_x, n_u, T, x0_ptr, u_seq_ptr,
        max_iters, dynamics_fp, stage_cost_fp, terminal_cost_fp);
}

// Diagnostic: trajectory cost given a control sequence and the
// user's dynamics + cost callbacks.
fn ddp_total_cost(n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64
{
    return nuc_ddp_total_cost(n_x, n_u, T, x0_ptr, u_seq_ptr,
        dynamics_fp, stage_cost_fp, terminal_cost_fp);
}
