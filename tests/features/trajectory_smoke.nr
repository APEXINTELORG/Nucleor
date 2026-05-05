// v0.8.183 stdlib/rods/trajectory.nr first test coverage.
//
// Quintic (5th-order) polynomial joint trajectory. Given start
// (q0, v0, a0) and goal (qT, vT, aT) over duration T, fits a
// C² polynomial. Pre-v0.8.183: zero coverage.
//
// Locks five textbook quintic-trajectory invariants:
//
//   1. **Boundary at t=0**: pos(0) == q0, vel(0) == v0, acc(0) == a0.
//   2. **Boundary at t=T**: pos(T) == qT, vel(T) == vT, acc(T) == aT.
//   3. **Duration round-trip**: duration() == T input.
//   4. **Constant trajectory**: q0=qT=5, all velocities/accels=0
//      → pos at midpoint == 5 (no motion).
//   5. **Standard rest-to-rest**: q0=0, qT=10, v0=v1=a0=a1=0,
//      T=2 → midpoint position is some intermediate (test it's
//      between 0 and 10).
//
// Expected: rc=0.

import "stdlib/rods/trajectory.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_boundary_at_0() -> i64 {
    let h: i64 = quintic_new(
        f64_to_bits(2.0),       // T
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),  // q0, v0, a0
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0)  // qT, vT, aT
    );
    if close(quintic_pos_at(h, f64_to_bits(0.0)), f64_to_bits(0.0), 1e-6) != 1 { quintic_free(h); return 1; };
    if close(quintic_vel_at(h, f64_to_bits(0.0)), f64_to_bits(0.0), 1e-6) != 1 { quintic_free(h); return 2; };
    if close(quintic_acc_at(h, f64_to_bits(0.0)), f64_to_bits(0.0), 1e-6) != 1 { quintic_free(h); return 4; };
    quintic_free(h);
    return 0;
}

fn check_boundary_at_T() -> i64 {
    let h: i64 = quintic_new(
        f64_to_bits(2.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    if close(quintic_pos_at(h, f64_to_bits(2.0)), f64_to_bits(10.0), 1e-6) != 1 { quintic_free(h); return 8; };
    if close(quintic_vel_at(h, f64_to_bits(2.0)), f64_to_bits(0.0), 1e-6) != 1 { quintic_free(h); return 16; };
    if close(quintic_acc_at(h, f64_to_bits(2.0)), f64_to_bits(0.0), 1e-6) != 1 { quintic_free(h); return 32; };
    quintic_free(h);
    return 0;
}

fn check_duration() -> i64 {
    let h: i64 = quintic_new(
        f64_to_bits(2.5),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    if close(quintic_duration(h), f64_to_bits(2.5), 1e-9) != 1 { quintic_free(h); return 64; };
    quintic_free(h);
    return 0;
}

fn check_constant_trajectory() -> i64 {
    let h: i64 = quintic_new(
        f64_to_bits(2.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    let mid: i64 = quintic_pos_at(h, f64_to_bits(1.0));
    if close(mid, f64_to_bits(5.0), 1e-6) != 1 { quintic_free(h); return 128; };
    quintic_free(h);
    return 0;
}

fn check_midpoint_intermediate() -> i64 {
    let h: i64 = quintic_new(
        f64_to_bits(2.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0)
    );
    let mid_bits: i64 = quintic_pos_at(h, f64_to_bits(1.0));
    let mid: f64 = f64_from_bits(mid_bits);
    quintic_free(h);
    if mid <= 0.0 { return 256; };
    if mid >= 10.0 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_boundary_at_0();
    fails = fails + check_boundary_at_T();
    fails = fails + check_duration();
    fails = fails + check_constant_trajectory();
    fails = fails + check_midpoint_intermediate();
    return fails;
}
