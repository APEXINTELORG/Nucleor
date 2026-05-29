// v0.8.234 stdlib/rods/wbc.nr first test coverage.
//
// Whole-body / multi-task controller (weighted QP). Pre-v0.8.234:
// zero coverage on the standalone rod.
//
// With NO tasks added, the QP reduces to
//   minimize α · ‖q̇‖²
// which has the unique optimum q̇ = 0. This lets us exercise
// new / clear / solve / get_qdot / free without needing raw
// J/x_des pointers (those are exercised by downstream IK ships).
//
// Locks four invariants:
//
//   1. wbc_new returns valid handle — non-zero.
//   2. Empty-task solve succeeds — solve returns 1.
//   3. Empty-task qdot is zero for every joint.
//   4. clear_tasks then re-solve still gives zero —
//      idempotent zero forcing.
//
// Expected: rc=0.

import "stdlib/rods/wbc.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_new_valid() -> i64 {
    let h: i64 = wbc_new(7, f64_to_bits(1e-4));
    if h == 0 { return 1; };
    wbc_free(h);
    return 0;
}

fn check_empty_solve_success() -> i64 {
    let h: i64 = wbc_new(7, f64_to_bits(1e-4));
    let ok: i64 = wbc_solve(h);
    wbc_free(h);
    if ok != 1 { return 2; };
    return 0;
}

fn check_empty_qdot_zero() -> i64 {
    let h: i64 = wbc_new(7, f64_to_bits(1e-4));
    wbc_solve(h);
    let mut i: i64 = 0;
    while i < 7 {
        let q: i64 = wbc_get_qdot(h, i);
        if close(q, f64_to_bits(0.0), 1e-9) != 1 { wbc_free(h); return 4; };
        i = i + 1;
    };
    wbc_free(h);
    return 0;
}

fn check_clear_then_solve() -> i64 {
    let h: i64 = wbc_new(3, f64_to_bits(1e-4));
    wbc_clear_tasks(h);
    let ok: i64 = wbc_solve(h);
    let q0: i64 = wbc_get_qdot(h, 0);
    wbc_free(h);
    if ok != 1 { return 8; };
    if close(q0, f64_to_bits(0.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_empty_solve_success();
    fails = fails + check_empty_qdot_zero();
    fails = fails + check_clear_then_solve();
    return fails;
}
