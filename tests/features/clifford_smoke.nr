// v0.8.142 stdlib/rods/clifford.nr first test coverage.
//
// Clifford / stabilizer formalism — efficient quantum error
// correction simulation (polynomial in n, not exponential).
// Pre-v0.8.142: zero coverage on a quantum-tier rod.
//
// Locks five textbook stabilizer-formalism invariants:
//   1. **Initial |0...0⟩ measure = 0**: cliff_init creates the
//      computational-basis ground state; Z-measurement on every
//      qubit is deterministic 0.
//   2. **X flips |0⟩ → |1⟩**: after `cliff_x`, Z-measurement
//      returns 1.
//   3. **Z on |0⟩ is identity**: Z eigenstate; measurement still 0.
//   4. **H twice is identity**: HH = I → measurement still 0.
//   5. **Bell state correlation**: H q0 + CNOT(0,1) → measure q0
//      and q1 are equal (both 0 or both 1). The defining property
//      of the Bell pair |Φ⁺⟩.
//
// Expected: rc=0.

import "stdlib/rods/clifford.nr"

fn check_init_ground_state() -> i64 {
    let st: i64 = cliff_init(3);
    if cliff_nq(st) != 3 { cliff_free(st); return 1; };
    if cliff_measure(st, 0) != 0 { cliff_free(st); return 2; };
    if cliff_measure(st, 1) != 0 { cliff_free(st); return 4; };
    if cliff_measure(st, 2) != 0 { cliff_free(st); return 8; };
    cliff_free(st);
    return 0;
}

fn check_x_flips() -> i64 {
    let st: i64 = cliff_init(2);
    cliff_x(st, 0);
    if cliff_measure(st, 0) != 1 { cliff_free(st); return 16; };
    // q1 untouched
    if cliff_measure(st, 1) != 0 { cliff_free(st); return 32; };
    cliff_free(st);
    return 0;
}

fn check_z_is_identity_on_zero() -> i64 {
    let st: i64 = cliff_init(1);
    cliff_z(st, 0);
    if cliff_measure(st, 0) != 0 { cliff_free(st); return 64; };
    cliff_free(st);
    return 0;
}

fn check_h_twice_is_identity() -> i64 {
    let st: i64 = cliff_init(1);
    cliff_h(st, 0);
    cliff_h(st, 0);
    if cliff_measure(st, 0) != 0 { cliff_free(st); return 128; };
    cliff_free(st);
    return 0;
}

fn check_bell_correlation() -> i64 {
    // |00⟩ -> H q0 -> (|00⟩+|10⟩)/√2 -> CNOT(0,1) -> (|00⟩+|11⟩)/√2 = Bell |Φ⁺⟩
    // After collapse on q0, q1 must match (both 0 or both 1).
    // Run several independent trials to hit both outcomes.
    let mut i: i64 = 0;
    let mut saw_00: i64 = 0;
    let mut saw_11: i64 = 0;
    while i < 20 {
        let st: i64 = cliff_init(2);
        cliff_h(st, 0);
        cliff_cnot(st, 0, 1);
        let m0: i64 = cliff_measure(st, 0);
        let m1: i64 = cliff_measure(st, 1);
        cliff_free(st);
        if m0 != m1 { return 256; };
        if m0 == 0 { saw_00 = 1; };
        if m0 == 1 { saw_11 = 1; };
        i = i + 1;
    };
    // We don't strictly require both outcomes (RNG could be deterministic),
    // but at least one must occur (we did 20 trials).
    if saw_00 == 0 { if saw_11 == 0 { return 512; }; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_init_ground_state();
    fails = fails + check_x_flips();
    fails = fails + check_z_is_identity_on_zero();
    fails = fails + check_h_twice_is_identity();
    fails = fails + check_bell_correlation();
    return fails;
}
