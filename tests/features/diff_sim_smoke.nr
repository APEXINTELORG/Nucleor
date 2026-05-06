// v0.8.228 stdlib/rods/diff_sim.nr first test coverage.
//
// Differentiable quantum simulation — N-core parallel circuit
// replicas, learnable noise logits per gate, von Neumann entropy
// backprop. Pre-v0.8.228: zero coverage on the standalone rod.
//
// Setup: 2 qubits, 1 core (clean only), mode_bits=0, seed=42.
// Apply 3 gates so n_gates increments.
//
// Locks four lifecycle invariants:
//
//   1. **Init returns valid handle** — non-zero.
//   2. **n_gates == 0 right after init** — no gates applied.
//   3. **n_gates tracks gate calls** — 3 diff_gate → n_gates 3.
//   4. **diff_reset clears gate counter** — after reset,
//      n_gates == 0.
//
// Heavier surfaces (extract, backward, gate_importance) need
// downstream feature wiring; deferred to ML-suite ships.
//
// Expected: rc=0.

import "stdlib/rods/diff_sim.nr"

fn check_init_valid() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    if h == 0 { return 1; };
    diff_free(h);
    return 0;
}

fn check_initial_n_gates_zero() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    if diff_n_gates(h) != 0 { diff_free(h); return 2; };
    diff_free(h);
    return 0;
}

fn check_n_gates_tracks_calls() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    diff_gate(h, 0, 0, 0, 0);  // H on q0
    diff_gate(h, 0, 1, 0, 0);  // H on q1
    diff_gate(h, 1, 0, 1, 0);  // CNOT 0→1
    if diff_n_gates(h) != 3 { diff_free(h); return 4; };
    diff_free(h);
    return 0;
}

fn check_reset_clears_counter() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    diff_gate(h, 0, 0, 0, 0);
    diff_gate(h, 0, 1, 0, 0);
    diff_reset(h);
    if diff_n_gates(h) != 0 { diff_free(h); return 8; };
    diff_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_init_valid();
    fails = fails + check_initial_n_gates_zero();
    fails = fails + check_n_gates_tracks_calls();
    fails = fails + check_reset_clears_counter();
    return fails;
}
