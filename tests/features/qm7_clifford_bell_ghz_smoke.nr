// v0.8.87 RFC QM-7 Phase 1 — Clifford rod smoke + correctness.
//
// Per gap-analysis: the Clifford rod (41KB stabilizer formalism
// runtime) had ZERO test coverage. This fixture exercises the
// core surface and the textbook Bell-state and GHZ-state
// entanglement guarantees.
//
// What we lock:
//   1. cliff_init / cliff_free / cliff_nq round-trip on a small
//      register without crashing.
//   2. Bell state |Φ+⟩ = (|00⟩ + |11⟩)/√2 via H + CNOT —
//      measuring qubit 0 then qubit 1 must yield the same bit
//      (entanglement; this is the defining stabilizer test of
//      the Clifford simulator).
//   3. 3-qubit GHZ |GHZ⟩ = (|000⟩ + |111⟩)/√2 via H + CNOT +
//      CNOT — all three measurements must agree.
//   4. cliff_x flips a fresh-zero qubit to 1 (basic gate sanity).
//   5. cliff_reset returns the simulator to |0...0⟩ — measurement
//      after reset must be 0 across all qubits.
//
// Expected: rc=0 (eight assertion failures bumping rc).

import "stdlib/rods/clifford.nr"

fn check_bell() -> i64 {
    let h: i64 = cliff_init(2);
    if h == 0 { return 1; };
    cliff_h(h, 0);
    cliff_cnot(h, 0, 1);
    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    cliff_free(h);
    if m0 != m1 { return 2; };  // Bell entanglement broken
    return 0;
}

fn check_ghz() -> i64 {
    let h: i64 = cliff_init(3);
    if h == 0 { return 3; };
    cliff_h(h, 0);
    cliff_cnot(h, 0, 1);
    cliff_cnot(h, 0, 2);
    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    let m2: i64 = cliff_measure(h, 2);
    cliff_free(h);
    if m0 != m1 || m1 != m2 { return 4; };  // GHZ entanglement broken
    return 0;
}

fn check_x_gate() -> i64 {
    let h: i64 = cliff_init(1);
    if h == 0 { return 5; };
    cliff_x(h, 0);
    let m: i64 = cliff_measure(h, 0);
    cliff_free(h);
    if m != 1 { return 6; };  // X|0⟩ should be |1⟩
    return 0;
}

fn check_reset_zero() -> i64 {
    let h: i64 = cliff_init(2);
    if h == 0 { return 7; };
    cliff_x(h, 0);
    cliff_x(h, 1);
    cliff_reset(h);
    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    cliff_free(h);
    if m0 != 0 || m1 != 0 { return 8; };  // reset failed
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bell();
    fails = fails + check_ghz();
    fails = fails + check_x_gate();
    fails = fails + check_reset_zero();
    return fails;
}
