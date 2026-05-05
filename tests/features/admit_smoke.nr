// v0.8.231 stdlib/rods/admit.nr first test coverage.
//
// Per-DOF admittance controller — maps measured force to a
// position command via a virtual mass-spring-damper. Pre-
// v0.8.231: zero coverage on the standalone rod.
//
// Locks four lifecycle invariants. admit_step takes a raw
// force_meas_ptr (double[n_dof]) which we cannot construct
// from Nucleor without low-level pointer plumbing — that path
// is exercised by downstream MPC / impedance ships.
//
//   1. **admit_new returns valid handle** — non-zero for a
//      reasonable n_dof.
//   2. **Fresh state has zero position** — virtual mass-spring
//      starts at rest at origin.
//   3. **Fresh state has zero velocity** — likewise.
//   4. **admit_reset re-zeros state** — even after gain change,
//      the (x, ẋ) state is back to zero.
//
// Expected: rc=0.

import "stdlib/rods/admit.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_new_valid() -> i64 {
    let h: i64 = admit_new(3);
    if h == 0 { return 1; };
    admit_free(h);
    return 0;
}

fn check_zero_position() -> i64 {
    let h: i64 = admit_new(3);
    let p0: i64 = admit_get_position(h, 0);
    let p1: i64 = admit_get_position(h, 1);
    let p2: i64 = admit_get_position(h, 2);
    admit_free(h);
    if close(p0, f64_to_bits(0.0), 1e-12) != 1 { return 2; };
    if close(p1, f64_to_bits(0.0), 1e-12) != 1 { return 4; };
    if close(p2, f64_to_bits(0.0), 1e-12) != 1 { return 8; };
    return 0;
}

fn check_zero_velocity() -> i64 {
    let h: i64 = admit_new(3);
    let v0: i64 = admit_get_velocity(h, 0);
    let v1: i64 = admit_get_velocity(h, 1);
    admit_free(h);
    if close(v0, f64_to_bits(0.0), 1e-12) != 1 { return 16; };
    if close(v1, f64_to_bits(0.0), 1e-12) != 1 { return 32; };
    return 0;
}

fn check_reset_zeros() -> i64 {
    let h: i64 = admit_new(2);
    admit_set_gains(h, 0, f64_to_bits(2.0), f64_to_bits(0.5), f64_to_bits(10.0));
    admit_set_force_target(h, 0, f64_to_bits(1.0));
    admit_reset(h);
    let p0: i64 = admit_get_position(h, 0);
    let v0: i64 = admit_get_velocity(h, 0);
    admit_free(h);
    if close(p0, f64_to_bits(0.0), 1e-12) != 1 { return 64; };
    if close(v0, f64_to_bits(0.0), 1e-12) != 1 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_zero_position();
    fails = fails + check_zero_velocity();
    fails = fails + check_reset_zeros();
    return fails;
}
