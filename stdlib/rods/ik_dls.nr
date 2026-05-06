// rods/ik_dls — Damped Least Squares inverse kinematics.
//
// Given a forward-kinematics chain (`fk_chain.nr`) and a target
// end-effector POSITION (xyz), iteratively adjust joint variables
// to minimize the position error. Uses the standard damped
// Jacobian pseudoinverse method (Wampler 1986, Buss 2009).
//
// The Jacobian is computed numerically via finite differences on
// the FK chain — no hand-coded analytical derivatives needed,
// works with any joint topology that fk_chain supports.
//
// Returns the number of iterations performed (≤ max_iters).
// Vars are updated in place: caller passes the current
// configuration in, gets the (improved) configuration out.
//
// Solver surfaces:
// - `ik_dls_solve`: position-only 3 x n DLS.
// - `ik_dls_solve_nullspace`: position-only task-priority posture.
// - `ik_dls_solve_6d`: position + orientation 6 x n DLS.
// - `ik_dls_solve_6d_nullspace`: 6D task with projected posture.
//
// See `stdlib/runtime/ik_dls_rt.c`.
#cfile "../runtime/ik_dls_rt.c"

// ik_dls_rt.c calls back into the FK chain runtime (`nuc_fk_chain_*`
// symbols). Importing fk_chain.nr chains its #cfile so both
// translation units get compiled + linked together.
import "stdlib/rods/fk_chain.nr"

extern fn nuc_ik_dls_solve(
    ch: i64, vars_ptr: i64,
    tx_bits: i64, ty_bits: i64, tz_bits: i64,
    max_iters: i64,
    tolerance_bits: i64,
    damping_bits: i64) -> i64;

// Set per-joint min/max bounds. Applied during every IK iteration
// via simple clamping. Default (if not set) is ±2π. Bounds persist
// across multiple solve calls on the same chain handle.
extern fn nuc_ik_set_joint_limit(ch: i64, joint_idx: i64, lo_b: i64, hi_b: i64);

// Returns the smallest |det(J·Jᵀ + λ²I)| observed during the most
// recent solve. A small value (~1e-9 or below) indicates the chain
// approached a singular configuration — small joint changes don't
// move the end-effector (or vice-versa). Use to back off, try a
// different goal, or switch to a damped strategy. Reset at the
// start of each solve; read after the solve returns.
extern fn nuc_ik_get_last_singularity_metric() -> i64;

// Yoshikawa manipulability metric (v0.2.208) — √det(J·Jᵀ) at the
// given (chain, vars) configuration. Geometrically, the volume of
// the reachable end-effector velocity ellipsoid given unit joint
// velocities. Larger = more dexterous; 0 = singular. Computed from
// the position-only Jacobian (3 × n_joints) via finite differences,
// just like the IK solver, so an FK update is implied; the chain's
// pose is left at the queried configuration for follow-up accessors.
extern fn nuc_ik_manipulability(ch: i64, vars_ptr: i64) -> i64;

// Task-priority IK with nullspace posture preference (v0.2.210).
// For redundant manipulators (n_joints > 3 in the position-only
// case), the IK solution is underdetermined. This solver fills
// the redundancy by pulling the joint configuration toward
// `q_pref` while still hitting the position target exactly:
//
//   q̇ = J⁺·e_pos + (I − J⁺·J)·w·(q_pref − q)
//
// `q_pref_ptr` is a `double[n_joints]` handle; pass 0 to disable
// the secondary task and behave like `nuc_ik_dls_solve`.
//
// `secondary_weight_bits` scales the secondary task; 0 disables it,
// 1.0 is "as aggressive as the primary update". 0.1-0.5 typical.
//
// Common patterns:
// - **Joint-limit avoidance**: q_pref = midpoint of each joint's
//   range, weight by 1/range².
// - **Solution-branch selection**: q_pref = previous solve's
//   output (continuity across waypoints).
extern fn nuc_ik_dls_solve_nullspace(
    ch: i64, vars_ptr: i64,
    tx_bits: i64, ty_bits: i64, tz_bits: i64,
    q_pref_ptr: i64, secondary_weight_bits: i64,
    max_iters: i64, tolerance_bits: i64, damping_bits: i64) -> i64;

// 6-DOF IK (v0.2.194): position + orientation. The angular error
// is computed as the quaternion log-map of (target * current^-1),
// giving a 3-vector axis-angle correction. Jacobian is 6×n.
//
// `weight_orient` scales orientation error vs position error
// (1.0 = equal weight; <1.0 prioritize position; >1.0 prioritize
// orientation). Useful for rebalancing when the position units
// (meters) and angular units (radians) have different
// numerical magnitudes.
extern fn nuc_ik_dls_solve_6d(
    ch: i64, vars_ptr: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tqw_b: i64, tqx_b: i64, tqy_b: i64, tqz_b: i64,
    max_iters: i64,
    tolerance_b: i64,
    damping_b: i64,
    weight_orient_b: i64) -> i64;

// 6-DOF IK with nullspace posture preference (ROBO-4 Phase 1).
// Same 6D pose target as `nuc_ik_dls_solve_6d`, plus a
// `double[n_joints]` preferred posture and secondary weight. The
// secondary update is projected through the 6D nullspace projector
// `(I - J+J)` so redundant or task-invisible DOFs can move toward
// posture preference without first-order disturbance of the pose task.
extern fn nuc_ik_dls_solve_6d_nullspace(
    ch: i64, vars_ptr: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tqw_b: i64, tqx_b: i64, tqy_b: i64, tqz_b: i64,
    q_pref_ptr: i64, secondary_weight_b: i64,
    max_iters: i64,
    tolerance_b: i64,
    damping_b: i64,
    weight_orient_b: i64) -> i64;

fn ik_dls_solve(
    ch: i64, vars_ptr: i64,
    tx_bits: i64, ty_bits: i64, tz_bits: i64,
    max_iters: i64,
    tolerance_bits: i64,
    damping_bits: i64) -> i64 {
    return nuc_ik_dls_solve(ch, vars_ptr, tx_bits, ty_bits, tz_bits,
                             max_iters, tolerance_bits, damping_bits);
}

fn ik_set_joint_limit(ch: i64, joint_idx: i64, lo_b: i64, hi_b: i64) {
    nuc_ik_set_joint_limit(ch, joint_idx, lo_b, hi_b);
}

fn ik_get_last_singularity_metric() -> i64 {
    return nuc_ik_get_last_singularity_metric();
}

fn ik_manipulability(ch: i64, vars_ptr: i64) -> i64 {
    return nuc_ik_manipulability(ch, vars_ptr);
}

fn ik_dls_solve_nullspace(
    ch: i64, vars_ptr: i64,
    tx_bits: i64, ty_bits: i64, tz_bits: i64,
    q_pref_ptr: i64, secondary_weight_bits: i64,
    max_iters: i64, tolerance_bits: i64, damping_bits: i64) -> i64
{
    return nuc_ik_dls_solve_nullspace(ch, vars_ptr,
        tx_bits, ty_bits, tz_bits, q_pref_ptr, secondary_weight_bits,
        max_iters, tolerance_bits, damping_bits);
}

fn ik_dls_solve_6d(
    ch: i64, vars_ptr: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tqw_b: i64, tqx_b: i64, tqy_b: i64, tqz_b: i64,
    max_iters: i64,
    tolerance_b: i64,
    damping_b: i64,
    weight_orient_b: i64) -> i64 {
    return nuc_ik_dls_solve_6d(
        ch, vars_ptr, tx_b, ty_b, tz_b,
        tqw_b, tqx_b, tqy_b, tqz_b,
        max_iters, tolerance_b, damping_b, weight_orient_b);
}

fn ik_dls_solve_6d_nullspace(
    ch: i64, vars_ptr: i64,
    tx_b: i64, ty_b: i64, tz_b: i64,
    tqw_b: i64, tqx_b: i64, tqy_b: i64, tqz_b: i64,
    q_pref_ptr: i64, secondary_weight_b: i64,
    max_iters: i64,
    tolerance_b: i64,
    damping_b: i64,
    weight_orient_b: i64) -> i64 {
    return nuc_ik_dls_solve_6d_nullspace(
        ch, vars_ptr, tx_b, ty_b, tz_b,
        tqw_b, tqx_b, tqy_b, tqz_b,
        q_pref_ptr, secondary_weight_b,
        max_iters, tolerance_b, damping_b, weight_orient_b);
}
