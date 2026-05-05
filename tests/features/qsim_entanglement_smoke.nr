// v0.8.151 RFC-0061 Tier 3 Phase A — qsim entanglement tracker
// + gate-influence DAG smoke fixture.
//
// The qsim_graph rod has shipped the surface (v0.7.94) — this
// fixture is the missing acceptance-criterion lock from RFC-0061
// §Tier 3: "qsim_entanglement_* queries work end-to-end on a
// 4-qubit Bell-state simulator."
//
// Locks five textbook entanglement-tracker invariants on a
// 4-qubit GHZ-style preparation circuit:
//   1. Empty tracker: count == 0.
//   2. After CNOT(0,1) + CNOT(1,2) + CNOT(2,3): all 4 qubits in
//      one entanglement component.
//   3. component count == 1 after the GHZ chain.
//   4. component size from any qubit == 4.
//   5. same(0, 3) == 1 (transitively connected via union-find).
//
// Gate-DAG side: H q0 followed by CNOT(0,1) — the CNOT depends
// on the H gate via shared qubit q0.
//
// Expected: rc=0.

import "stdlib/rods/qsim_graph.nr"

fn check_empty_count() -> i64 {
    qsim_entanglement_clear();
    if qsim_entanglement_count() != 0 { return 1; };
    return 0;
}

fn check_ghz_chain_one_component() -> i64 {
    qsim_entanglement_clear();
    // GHZ chain: 0-1-2-3 via 3 CNOT entanglements.
    qsim_entangle_register(0, 1);
    qsim_entangle_register(1, 2);
    qsim_entangle_register(2, 3);
    if qsim_entanglement_count() != 1 { return 2; };
    if qsim_entanglement_size(0) != 4 { return 4; };
    if qsim_entanglement_size(3) != 4 { return 8; };
    if qsim_entanglement_same(0, 3) != 1 { return 16; };
    return 0;
}

fn check_disjoint_components() -> i64 {
    qsim_entanglement_clear();
    // Two disjoint Bell pairs: (0,1) and (2,3).
    qsim_entangle_register(0, 1);
    qsim_entangle_register(2, 3);
    if qsim_entanglement_count() != 2 { return 32; };
    if qsim_entanglement_same(0, 2) != 0 { return 64; };
    if qsim_entanglement_same(1, 3) != 0 { return 128; };
    if qsim_entanglement_size(0) != 2 { return 256; };
    return 0;
}

fn check_gate_dag() -> i64 {
    qsim_gate_dag_clear();
    // H q0 (1-qubit), then CNOT q0 q1 (2-qubit).
    let g0: i64 = qsim_gate_record("H", 0, 0 - 1);
    let g1: i64 = qsim_gate_record("CNOT", 0, 1);
    if qsim_gate_dag_size() != 2 { return 512; };
    // CNOT depends on H via shared qubit q0.
    if qsim_gate_dag_depends_on(g1, g0) != 1 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_count();
    fails = fails + check_ghz_chain_one_component();
    fails = fails + check_disjoint_components();
    fails = fails + check_gate_dag();
    return fails;
}
