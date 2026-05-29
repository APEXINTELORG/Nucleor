// v0.8.235 stdlib/rods/hwbc.nr first test coverage.
//
// Hierarchical (strict-priority) whole-body controller via
// Siciliano-Slotine null-space projection. Pre-v0.8.235: zero
// coverage on the standalone rod (sister to wbc.nr soft-priority
// weighted QP).
//
// Empty-task path: with no tasks, q̇ = 0 (the null space is the
// full ℝⁿ but there's nothing forcing motion). Same lifecycle
// pattern as wbc_smoke v0.8.234.
//
// Locks four invariants (J / x_des use raw ptrs; deferred to IK
// ships):
//
//   1. hwbc_new returns valid handle.
//   2. Empty-task solve succeeds — returns 1.
//   3. Empty-task qdot is zero for every joint.
//   4. clear + re-solve idempotent zero — resilient empty
//      stack.
//
// Expected: rc=0.

import "stdlib/rods/hwbc.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_new_valid() -> i64 {
    let h: i64 = hwbc_new(7, f64_to_bits(1e-3));
    if h == 0 { return 1; };
    hwbc_free(h);
    return 0;
}

fn check_empty_solve_success() -> i64 {
    let h: i64 = hwbc_new(7, f64_to_bits(1e-3));
    let ok: i64 = hwbc_solve(h);
    hwbc_free(h);
    if ok != 1 { return 2; };
    return 0;
}

fn check_empty_qdot_zero() -> i64 {
    let h: i64 = hwbc_new(7, f64_to_bits(1e-3));
    hwbc_solve(h);
    let mut i: i64 = 0;
    while i < 7 {
        let q: i64 = hwbc_get_qdot(h, i);
        if close(q, f64_to_bits(0.0), 1e-9) != 1 { hwbc_free(h); return 4; };
        i = i + 1;
    };
    hwbc_free(h);
    return 0;
}

fn check_clear_then_solve() -> i64 {
    let h: i64 = hwbc_new(3, f64_to_bits(1e-3));
    hwbc_clear_tasks(h);
    let ok: i64 = hwbc_solve(h);
    let q0: i64 = hwbc_get_qdot(h, 0);
    hwbc_free(h);
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
