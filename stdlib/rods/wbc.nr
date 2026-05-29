// rods/wbc — Whole-body / multi-task controller (weighted QP).
//
// At each control tick, the robot has n joints with current
// configuration q ∈ ℝⁿ. The controller picks a joint-velocity
// command q̇ ∈ ℝⁿ that simultaneously realizes a stack of tasks
// — each task wanting some end-effector / body / CoM output to
// move at a desired rate.
//
// Each task is defined by:
//   - an output Jacobian J_i ∈ ℝ^(m_i × n)
//   - a desired output rate ẋ_i ∈ ℝ^(m_i)
//   - a relative weight w_i > 0
//
// Weighted-QP cost:
//
//   minimize  Σ_i w_i · ‖J_i · q̇ − ẋ_i‖²  +  α · ‖q̇‖²
//
// The α regularizer (Tikhonov) handles redundancy and rank
// deficiency without extra machinery — rotation around redundant
// joints is naturally pulled toward zero. Closed form:
//
//   q̇ = (Σ_i w_i J_iᵀ J_i + α I)⁻¹ · (Σ_i w_i J_iᵀ ẋ_i)
//
// Workflow:
//
//   import "stdlib/rods/wbc.nr"
//
//   let h = wbc_new(n_dof, alpha_b);
//
//   // Each control tick:
//   wbc_clear_tasks(h);
//   //   add tasks: J is row-major double[m * n_dof], x_des is double[m]
//   let id_com = wbc_add_task(h, J_com_ptr, x_des_com_ptr, 3, w_com_b);
//   let id_eef = wbc_add_task(h, J_eef_ptr, x_des_eef_ptr, 6, w_eef_b);
//   let id_post = wbc_add_task(h, J_post_ptr, x_des_post_ptr, n_dof, w_post_b);
//
//   wbc_solve(h);
//
//   // Read out joint-velocity command:
//   for i in 0..n_dof {
//       let qdot_i_b = wbc_get_qdot(h, i);
//   }
//
//   // Diagnostics: per-task residual norm.
//   let res_eef_b = wbc_task_residual(h, id_eef);
//
// Use cases: humanoid balance + reach (CoM task + hand position +
// posture regularizer), mobile-manipulator coordination (base
// motion + arm pose), redundant-arm IK with multiple objectives.
//
// Limitations (strict-priority hierarchy / box constraints /
// torque-level control land in v0.6 if needed):
// - Weighted QP gives soft priorities — large weights nudge
//   tasks first but do not guarantee strict precedence. For
//   absolute task ordering, use the Siciliano-Slotine null-space
//   projection method (planned for v0.6).
// - No joint velocity / acceleration / torque box constraints.
//   Adding them turns the problem into a constrained QP — use
//   `lcp.nr` for the constrained-QP-as-LCP reduction in the meantime.
// - Velocity-level command only.
//
// See `stdlib/runtime/wbc_rt.c`.
#cfile "../runtime/wbc_rt.c"

extern fn nuc_wbc_new(n_dof: i64, alpha_b: i64) -> i64;
extern fn nuc_wbc_set_regularization(h: i64, alpha_b: i64);
extern fn nuc_wbc_clear_tasks(h: i64);
extern fn nuc_wbc_add_task(h: i64, J_ptr: i64, x_des_ptr: i64,
    n_rows: i64, weight_b: i64) -> i64;
extern fn nuc_wbc_solve(h: i64) -> i64;
extern fn nuc_wbc_get_qdot(h: i64, i: i64) -> i64;
extern fn nuc_wbc_task_residual(h: i64, task_id: i64) -> i64;
extern fn nuc_wbc_free(h: i64);

// Create a WBC for a robot with n_dof joints. `alpha_b` is the
// Tikhonov regularizer (default 1e-4 if non-positive).
fn wbc_new(n_dof: i64, alpha_b: i64) -> i64 {
    return nuc_wbc_new(n_dof, alpha_b);
}

// Override the regularizer.
fn wbc_set_regularization(h: i64, alpha_b: i64) {
    nuc_wbc_set_regularization(h, alpha_b);
}

// Reset the task stack — call once per control tick before adding
// the current iteration's tasks.
fn wbc_clear_tasks(h: i64) { nuc_wbc_clear_tasks(h); }

// Add a task. `J_ptr` is `double[n_rows * n_dof]` (row-major
// Jacobian); `x_des_ptr` is `double[n_rows]` (desired output rate);
// `weight_b` is a positive scalar. Both J and x_des are copied
// internally — the caller's buffers can be reused.
fn wbc_add_task(h: i64, J_ptr: i64, x_des_ptr: i64,
    n_rows: i64, weight_b: i64) -> i64
{
    return nuc_wbc_add_task(h, J_ptr, x_des_ptr, n_rows, weight_b);
}

// Solve the weighted QP. Returns 1 on success, 0 on linear-solve
// failure (typically only if α = 0 AND every task has rank-deficient
// J — pick a non-zero α).
fn wbc_solve(h: i64) -> i64 { return nuc_wbc_solve(h); }

// Read solution component q̇_i.
fn wbc_get_qdot(h: i64, i: i64) -> i64 { return nuc_wbc_get_qdot(h, i); }

// Per-task residual norm ‖J_i q̇ − ẋ_i‖₂ (after `wbc_solve`).
fn wbc_task_residual(h: i64, task_id: i64) -> i64 {
    return nuc_wbc_task_residual(h, task_id);
}

fn wbc_free(h: i64) { nuc_wbc_free(h); }
