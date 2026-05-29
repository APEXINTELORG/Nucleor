// v0.8.196 stdlib/rods/quantum.nr first test coverage.
//
// Statevector quantum circuit simulator. Pre-v0.8.196: zero
// coverage on the standalone rod (some primitives were
// indirectly exercised through twin_core, but the basic
// state/gates/measurements weren't directly tested).
//
// Locks four textbook quantum-state invariants:
//
//   1. Initial state |0⟩: prob(qubit=0, state=0) == 1.0;
//      qsim_num_qubits round-trip.
//   2. X gate flips |0⟩ → |1⟩: after qsim_x(0), prob of
//      measuring 1 on qubit 0 is 1.0.
//   3. HH = I: applying H twice on |0⟩ returns |0⟩
//      (probability of 0 outcome = 1.0).
//   4. CNOT in |10⟩: |10⟩ + CNOT → |11⟩ (qubit 1 flips).
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

// qsim_prob0(sv, q) returns the probability that qubit q
// would measure to |0⟩ if measured now.
fn check_initial_state() -> i64 {
    let sv: i64 = qsim_init(2);
    if qsim_num_qubits(sv) != 2 { return 1; };
    // |00⟩: prob0 should be 1.0 on both qubits
    let p0: i64 = qsim_prob0(sv, 0);
    if close(p0, f64_to_bits(1.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_x_flip() -> i64 {
    let sv: i64 = qsim_init(2);
    qsim_x(sv, 0);
    // After X on qubit 0: prob0 of qubit 0 should be 0.0 (it's now |1⟩)
    let p0: i64 = qsim_prob0(sv, 0);
    if close(p0, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_h_h_is_identity() -> i64 {
    let sv: i64 = qsim_init(1);
    qsim_h(sv, 0);
    qsim_h(sv, 0);
    // HH = I → back to |0⟩ → prob0 = 1.0
    let p0: i64 = qsim_prob0(sv, 0);
    if close(p0, f64_to_bits(1.0), 1e-6) != 1 { return 8; };
    return 0;
}

fn check_cnot_on_10() -> i64 {
    let sv: i64 = qsim_init(2);
    // Prepare |10⟩ — flip qubit 0 (control).
    qsim_x(sv, 0);
    // CNOT control=0, target=1 → flips target since control is 1.
    qsim_cnot(sv, 0, 1);
    // After CNOT: |11⟩, so prob0 of qubit 1 = 0.0
    let p0: i64 = qsim_prob0(sv, 1);
    if close(p0, f64_to_bits(0.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_state();
    fails = fails + check_x_flip();
    fails = fails + check_h_h_is_identity();
    fails = fails + check_cnot_on_10();
    return fails;
}
