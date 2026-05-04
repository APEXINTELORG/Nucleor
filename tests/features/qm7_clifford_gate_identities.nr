// v0.8.88 RFC QM-7 Phase 1 sister — Clifford gate-identity coverage.
//
// Sister to qm7_clifford_bell_ghz_smoke.nr (v0.8.87, first test
// coverage of the Clifford rod). Adds gate-composition identities
// that catch single-gate regressions without depending on
// measurement randomness.
//
// All asserts use deterministic outcomes (start in computational
// basis, never enter a coherent superposition before the final
// measurement, OR cancel any superposition with the inverse gate
// pair). Stabilizer simulators are deterministic for these paths.
//
// Identities exercised:
//   Z|0>           -> 0    (Z preserves the |0> eigenstate)
//   X X|0>         -> 0    (X^2 = I on |0>)
//   Z Z|0>         -> 0    (Z^2 = I on |0>)
//   Y Y|0>         -> 0    (Y^2 = I on |0>)
//   S S S S|0>     -> 0    (S^4 = I, no measurement randomness)
//   X|0> -> 1; X|1> -> 0   (X bit-flips deterministically)
//   CNOT CNOT|10>  -> 1, 0 (CNOT^2 = I on classical inputs)
//   X on q1 of |10> via CNOT gates does not affect q0
//
// Expected: rc=0 (eight assertion bumps).

import "stdlib/rods/clifford.nr"

fn check_z_preserves_zero() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_z(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 0 { return 1; };
    return 0;
}

fn check_x_squared_identity() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_x(h, 0);
    cliff_x(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 0 { return 2; };
    return 0;
}

fn check_z_squared_identity() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_z(h, 0);
    cliff_z(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 0 { return 4; };
    return 0;
}

fn check_y_squared_identity() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_y(h, 0);
    cliff_y(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 0 { return 8; };
    return 0;
}

fn check_s_fourth_identity() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_s(h, 0);
    cliff_s(h, 0);
    cliff_s(h, 0);
    cliff_s(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 0 { return 16; };
    return 0;
}

fn check_x_flips_one_back_to_zero() -> i64 {
    let h: i64 = cliff_init(1);
    cliff_x(h, 0);  // |0> -> |1>
    let m1: i64 = cliff_measure(h, 0);
    cliff_x(h, 0);  // |1> -> |0>
    let m2: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m1 != 1 || m2 != 0 { return 32; };
    return 0;
}

fn check_cnot_squared_identity() -> i64 {
    let h: i64 = cliff_init(2);
    cliff_x(h, 0);  // |10>
    cliff_cnot(h, 0, 1);  // |11>
    cliff_cnot(h, 0, 1);  // |10>
    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    cliff_free(h);
    if m0 != 1 || m1 != 0 { return 64; };
    return 0;
}

fn check_cnot_no_effect_when_control_zero() -> i64 {
    let h: i64 = cliff_init(2);
    // |00> — control is 0, target should stay 0 after CNOT
    cliff_cnot(h, 0, 1);
    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    cliff_free(h);
    if m0 != 0 || m1 != 0 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_z_preserves_zero();
    fails = fails + check_x_squared_identity();
    fails = fails + check_z_squared_identity();
    fails = fails + check_y_squared_identity();
    fails = fails + check_s_fourth_identity();
    fails = fails + check_x_flips_one_back_to_zero();
    fails = fails + check_cnot_squared_identity();
    fails = fails + check_cnot_no_effect_when_control_zero();
    return fails;
}
