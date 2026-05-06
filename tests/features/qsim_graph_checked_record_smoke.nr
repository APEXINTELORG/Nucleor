// v0.8.325 QM-9 qsim_graph checked gate-record smoke.
//
// Locks the Nucleor-side qsim_gate_record_checked contract:
//   1. status_unknown is stable at 3, giving checked-record -3
//   2. valid one-qubit and two-qubit records return real gate ids
//   3. invalid q1/q2 returns -1 (out_of_range)
//   4. full DAG returns -2 (dag_full)
//   5. invalid args still return -1 when the DAG is full
//
// Expected: rc=0.

import "stdlib/rods/qsim_graph.nr"

fn check_status_constants() -> i64 {
    if qsim_graph_status_ok() != 0 { return 1; };
    if qsim_graph_status_out_of_range() != 1 { return 2; };
    if qsim_graph_status_dag_full() != 2 { return 4; };
    if qsim_graph_status_unknown() != 3 { return 8; };
    return 0;
}

fn check_valid_records() -> i64 {
    qsim_graph_clear();
    let g0: i64 = qsim_gate_record_checked("H", 0, 0 - 1);
    if g0 != 0 { return 16; };
    let g1: i64 = qsim_gate_record_checked("CNOT", 0, 1);
    if g1 != 1 { return 32; };
    if qsim_gate_dag_depends_on(g1, g0) != 1 { return 64; };
    if qsim_gate_dag_size() != 2 { return 128; };
    return 0;
}

fn check_out_of_range_records() -> i64 {
    qsim_graph_clear();
    if qsim_gate_record_checked("H", 0 - 1, 0 - 1) != (0 - qsim_graph_status_out_of_range()) { return 256; };
    if qsim_gate_record_checked("H", 1024, 0 - 1) != (0 - qsim_graph_status_out_of_range()) { return 512; };
    if qsim_gate_record_checked("CNOT", 0, 0 - 2) != (0 - qsim_graph_status_out_of_range()) { return 1024; };
    if qsim_gate_record_checked("CNOT", 0, 1024) != (0 - qsim_graph_status_out_of_range()) { return 2048; };
    if qsim_gate_dag_size() != 0 { return 4096; };
    return 0;
}

fn check_dag_full_records() -> i64 {
    qsim_graph_clear();
    let mut i: i64 = 0;
    while i < qsim_graph_max_gates() {
        let g: i64 = qsim_gate_record_checked("H", 0, 0 - 1);
        if g != i { return 8192; };
        i = i + 1;
    };
    if qsim_graph_gate_slots_remaining() != 0 { return 16384; };
    if qsim_gate_record_checked("H", 0, 0 - 1) != (0 - qsim_graph_status_dag_full()) { return 32768; };
    if qsim_gate_record_checked("CNOT", 0, 1) != (0 - qsim_graph_status_dag_full()) { return 65536; };
    if qsim_gate_record_checked("H", 1024, 0 - 1) != (0 - qsim_graph_status_out_of_range()) { return 131072; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_status_constants();
    fails = fails + check_valid_records();
    fails = fails + check_out_of_range_records();
    fails = fails + check_dag_full_records();
    qsim_graph_clear();
    return fails;
}
