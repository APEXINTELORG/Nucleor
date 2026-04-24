// rods/ilqr — Iterative Linear Quadratic Regulator (iLQR, Tassa
// et al. 2012). Locally-optimal nonlinear trajectory optimizer
// that's the workhorse inner loop of model predictive control
// (MPC) and direct shooting trajectory optimization.
//
// User supplies the dynamics, stage cost, and terminal cost as
// function-pointer callbacks. iLQR iteratively quadratizes the
// problem around the current trajectory, solves the LQR sub-
// problem backward (Riccati recursion), and forward-rolls with a
// line search until the cost decreases.
//
// Use cases:
// - **Direct shooting trajectory optimization**: optimize a robot's
//   joint torques over a horizon to minimize a cost (e.g., reach
//   a goal pose with minimum control effort).
// - **MPC inner loop**: at each control step, solve a finite-horizon
//   iLQR problem from the current state to get the next control
//   action, then apply only the first control and re-solve.
//
// Workflow:
//   let n_iters = ilqr_optimize(n_x, n_u, T,
//       x0_ptr, u_seq_ptr,        // u_seq is double[T*n_u], modified in place
//       max_iters,
//       dynamics_fp,              // (x, u, x_next) -> i64
//       stage_cost_fp,            // (x, u) -> bit-cast f64 cost
//       terminal_cost_fp);        // (x_T) -> bit-cast f64 cost
//
//   let final_cost = ilqr_total_cost(n_x, n_u, T,
//       x0_ptr, u_seq_ptr, dynamics_fp, stage_cost_fp, terminal_cost_fp);
//
// **Limitations** (analytical-gradient and constraint-handling
// upgrades land in v0.6 if needed):
// - Numerical finite differences for all gradients/Hessians.
//   Slow for large problems but simple to use.
// - Diagonal Hessian approximation (Gauss-Newton style); ignores
//   off-diagonal cost coupling.
// - No box constraints on u (would need projected line search
//   or DDP variant).
//
// See `stdlib/runtime/ilqr_rt.c`.
#cfile "../runtime/ilqr_rt.c"

extern fn nuc_ilqr_optimize(
    n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64;

extern fn nuc_ilqr_total_cost(
    n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64;

// Optimize a trajectory's control sequence in place. `u_seq_ptr`
// is a `double[T * n_u]` caller-allocated buffer; the function
// modifies it. Returns the number of iLQR iterations actually
// performed (≤ max_iters).
//
// `dynamics_fp` is `fn(x_ptr, u_ptr, x_next_ptr) -> i64`; it
// reads x and u from the given pointers and writes the next state
// to x_next_ptr.
//
// `stage_cost_fp` is `fn(x_ptr, u_ptr) -> i64`; returns the per-
// step cost as bit-cast f64.
//
// `terminal_cost_fp` is `fn(x_ptr) -> i64`; returns the terminal
// cost as bit-cast f64.
fn ilqr_optimize(n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64
{
    return nuc_ilqr_optimize(n_x, n_u, T, x0_ptr, u_seq_ptr,
        max_iters, dynamics_fp, stage_cost_fp, terminal_cost_fp);
}

// Diagnostic: total trajectory cost given a control sequence and
// the user's dynamics + cost callbacks.
fn ilqr_total_cost(n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64
{
    return nuc_ilqr_total_cost(n_x, n_u, T, x0_ptr, u_seq_ptr,
        dynamics_fp, stage_cost_fp, terminal_cost_fp);
}
