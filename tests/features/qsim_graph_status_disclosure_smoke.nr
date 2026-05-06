// v0.8.306 R11-D4 Phase 1 — qsim_graph status surface.
//
// Locks 7 invariants:
//   1. max_qubits = 1024
//   2. max_gates  = 4096
//   3. qubit_in_range(0) = 1
//   4. qubit_in_range(1023) = 1
//   5. qubit_in_range(1024) = 0 (over cap)
//   6. status_explain with out-of-range q returns "out_of_range"
//   7. limitations names "HARD CAPS" + "AUTO-GRAPH" + "QUERY CONTRACT"
//
// Expected: rc=0.

import "stdlib/rods/qsim_graph.nr"

fn check_caps() -> i64 {
    if qsim_graph_max_qubits() != 1024 { return 1; };
    if qsim_graph_max_gates() != 4096 { return 2; };
    return 0;
}

fn check_qubit_in_range() -> i64 {
    if qsim_graph_qubit_in_range(0) != 1 { return 4; };
    if qsim_graph_qubit_in_range(1023) != 1 { return 8; };
    if qsim_graph_qubit_in_range(1024) != 0 { return 16; };
    if qsim_graph_qubit_in_range(0 - 1) != 0 { return 32; };
    return 0;
}

fn check_status_explain() -> i64 {
    let s_oor: str = qsim_graph_status_explain(99999, 0);
    if str_eq(s_oor, "out_of_range") != 1 { return 64; };
    let s_ok: str = qsim_graph_status_explain(0, 1);
    if str_eq(s_ok, "ok") != 1 { return 128; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = qsim_graph_limitations();
    if str_len(s) == 0 { return 256; };
    if str_index_of(s, "HARD CAPS") < 0 { return 512; };
    if str_index_of(s, "AUTO-GRAPH") < 0 { return 1024; };
    if str_index_of(s, "QUERY CONTRACT") < 0 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_caps();
    fails = fails + check_qubit_in_range();
    fails = fails + check_status_explain();
    fails = fails + check_limitations();
    return fails;
}
