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
// **Position-only solver.** Orientation IK lands in v0.5
// (RFC-0013 follow-on) — extends to 6-DOF target via a 6×n
// Jacobian. The position-only path (3×n) covers most pick-and-
// place use cases.
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
