// rods/cilqr — Box-constrained iLQR (clamped forward pass).
//
// Same iterative-LQR algorithm as `ilqr.nr`, with one addition:
// each control update during the forward pass is **clamped** to a
// per-component box `[u_min, u_max]`. Standard pragmatic way to
// enforce control bounds without the heavier machinery of
// projected backward-pass active-set algorithms (Tassa-style box-
// DDP, planned for v0.6).
//
// Use this rod when:
// - Your actuators have hard limits (motor torque, thrust, etc.)
//   that the controller MUST respect.
// - You want a single one-shot rod call (vs. assembling a
//   constrained QP each iteration with `lcp.nr`).
//
// Use `ilqr.nr` when no bounds are needed (a few percent faster
// since the forward pass skips the clamp).
//
// Workflow:
//
//   import "stdlib/rods/cilqr.nr"
//
//   // u_min and u_max are double[n_u] caller-allocated arrays.
//   let n = cilqr_optimize_box(n_x, n_u, T,
//       x0_ptr, u_seq_ptr,
//       u_min_ptr, u_max_ptr,
//       max_iters,
//       dynamics_fp, stage_cost_fp, terminal_cost_fp);
//
// Same callback contract as `ilqr.nr` (see that rod's docs).
//
// **Limitations** (Tassa-style projected backward pass land in v0.6
// if needed):
// - Only the forward pass clamps; the backward-pass gain `K` is
//   unconstrained. When bounds are tightly active over many steps,
//   `K` can be aggressive and convergence slows.
// - Same numerical-FD / diagonal-Hessian limitations as `ilqr.nr`.
//
// See `stdlib/runtime/cilqr_rt.c`.
#cfile "../runtime/cilqr_rt.c"

extern fn nuc_cilqr_optimize_box(
    n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    u_min_ptr: i64, u_max_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64;

// Box-constrained iLQR optimizer. Clamps each forward-pass control
// to `[u_min[i], u_max[i]]`. The initial `u_seq` is also pre-clamped
// to the box on entry (so an out-of-bounds warm start is safe).
// Returns the number of iLQR iterations actually performed
// (≤ max_iters).
fn cilqr_optimize_box(n_x: i64, n_u: i64, T: i64,
    x0_ptr: i64, u_seq_ptr: i64,
    u_min_ptr: i64, u_max_ptr: i64,
    max_iters: i64,
    dynamics_fp: i64,
    stage_cost_fp: i64,
    terminal_cost_fp: i64) -> i64
{
    return nuc_cilqr_optimize_box(n_x, n_u, T, x0_ptr, u_seq_ptr,
        u_min_ptr, u_max_ptr, max_iters,
        dynamics_fp, stage_cost_fp, terminal_cost_fp);
}
