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

fn ik_dls_solve(
    ch: i64, vars_ptr: i64,
    tx_bits: i64, ty_bits: i64, tz_bits: i64,
    max_iters: i64,
    tolerance_bits: i64,
    damping_bits: i64) -> i64 {
    return nuc_ik_dls_solve(ch, vars_ptr, tx_bits, ty_bits, tz_bits,
                             max_iters, tolerance_bits, damping_bits);
}
