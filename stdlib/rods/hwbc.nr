// rods/hwbc — Hierarchical (strict-priority) whole-body controller
// via Siciliano-Slotine null-space projection (Siciliano & Slotine
// 1991).
//
// Where `wbc.nr` solves a single weighted QP that gives all tasks
// soft priorities, this rod processes tasks in **strict** priority
// order: each subsequent task is constrained to the null space of
// all higher-priority Jacobians. Lower-priority tasks can never
// undo or compromise a higher-priority task — only refine within
// the residual freedom.
//
// Algorithm per control tick:
//
//   q̇₀ = 0,  N₀ = I_n
//   for i = 1..K (priority order, 1 = highest):
//     J̃_i = J_i · N_{i-1}                 // effective Jacobian
//     Δq̇ = J̃_i⁺ · (ẋ_i_des − J_i · q̇_{i-1})
//     q̇_i = q̇_{i-1} + Δq̇
//     N_i = N_{i-1} − J̃_i⁺ · J̃_i        // null-space projector
//   return q̇_K
//
// Pseudoinverse uses damped least squares for numerical stability:
//   A⁺ = Aᵀ · (A · Aᵀ + λ · I)⁻¹
//
// Use this rod when you need ABSOLUTE task ordering (e.g. balance
// must NEVER be sacrificed for reach). Use `wbc.nr` (weighted QP)
// when soft tradeoffs are acceptable.
//
// Workflow:
//
//   import "stdlib/rods/hwbc.nr"
//
//   let h = hwbc_new(n_dof, damping_b);
//
//   // Each control tick — add tasks in PRIORITY ORDER (highest first):
//   hwbc_clear_tasks(h);
//   let id_balance = hwbc_add_task(h, J_bal_ptr,  x_bal_ptr,  3);
//   let id_reach   = hwbc_add_task(h, J_reach_ptr, x_reach_ptr, 6);
//   let id_post    = hwbc_add_task(h, J_post_ptr, x_post_ptr, n_dof);
//   hwbc_solve(h);
//
//   for i in 0..n_dof { let q = hwbc_get_qdot(h, i); ... }
//   let res_post = hwbc_task_residual(h, id_post);  // diagnostics
//
// **Limitations** (constrained QP per task / box constraints / SVD-
// based null space land in v0.6 if needed):
// - Damped pseudoinverse only; SVD-based truncation handles rank-
//   deficient task stacks more robustly.
// - No box constraints on q̇.
// - Dense matrices throughout — fine for n_dof ≤ ~30.
//
// See `stdlib/runtime/hwbc_rt.c`.
#cfile "../runtime/hwbc_rt.c"

extern fn nuc_hwbc_new(n_dof: i64, damping_b: i64) -> i64;
extern fn nuc_hwbc_set_damping(h: i64, damping_b: i64);
extern fn nuc_hwbc_clear_tasks(h: i64);
extern fn nuc_hwbc_add_task(h: i64, J_ptr: i64, x_des_ptr: i64, n_rows: i64) -> i64;
extern fn nuc_hwbc_solve(h: i64) -> i64;
extern fn nuc_hwbc_get_qdot(h: i64, i: i64) -> i64;
extern fn nuc_hwbc_task_residual(h: i64, task_id: i64) -> i64;
extern fn nuc_hwbc_free(h: i64);

// Create a hierarchical WBC for a robot with `n_dof` joints.
// `damping_b` is the Tikhonov damping for each task's pseudoinverse
// (default 1e-3 if non-positive). Higher = more numerical stability
// but tasks satisfied less aggressively.
fn hwbc_new(n_dof: i64, damping_b: i64) -> i64 {
    return nuc_hwbc_new(n_dof, damping_b);
}

fn hwbc_set_damping(h: i64, damping_b: i64) { nuc_hwbc_set_damping(h, damping_b); }

// Reset the task stack — call once per control tick before adding
// the current iteration's tasks.
fn hwbc_clear_tasks(h: i64) { nuc_hwbc_clear_tasks(h); }

// Add a task. Tasks are ordered by call sequence — first added has
// the HIGHEST priority. `J_ptr` is `double[n_rows * n_dof]` (row-
// major Jacobian); `x_des_ptr` is `double[n_rows]` (desired output
// rate). Both are copied internally.
fn hwbc_add_task(h: i64, J_ptr: i64, x_des_ptr: i64, n_rows: i64) -> i64 {
    return nuc_hwbc_add_task(h, J_ptr, x_des_ptr, n_rows);
}

// Run the hierarchy. Returns 1 on success, 0 if any task's
// damped-LS solve was singular (extremely degenerate; raise damping).
fn hwbc_solve(h: i64) -> i64 { return nuc_hwbc_solve(h); }

// Read solution component q̇_i.
fn hwbc_get_qdot(h: i64, i: i64) -> i64 { return nuc_hwbc_get_qdot(h, i); }

// Per-task residual norm ‖J_i q̇ − ẋ_i‖₂ (after `hwbc_solve`).
// Higher-priority tasks should have residuals close to 0; lower-
// priority residuals can be larger if the task is unreachable
// within the higher-priority null space.
fn hwbc_task_residual(h: i64, task_id: i64) -> i64 {
    return nuc_hwbc_task_residual(h, task_id);
}

fn hwbc_free(h: i64) { nuc_hwbc_free(h); }
