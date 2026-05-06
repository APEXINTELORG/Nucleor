// v0.8.324 QM-8/QM-9 qsim_graph status-code preflight smoke.
//
// Locks the Nucleor-side qsim_gate_record_preflight contract:
//   1. status constants are stable: ok=0, out_of_range=1, dag_full=2
//   2. valid one-qubit and two-qubit gate args return ok
//   3. q1 outside [0,1023] returns out_of_range
//   4. q2 outside [-1,1023] returns out_of_range
//   5. a full gate DAG reports dag_full for otherwise-valid args
//   6. invalid args still report out_of_range even when the DAG is full
//
// Expected: rc=0.

import "stdlib/rods/qsim_graph.nr"

fn check_status_constants() -> i64 {
    if qsim_graph_status_ok() != 0 { return 1; };
    if qsim_graph_status_out_of_range() != 1 { return 2; };
    if qsim_graph_status_dag_full() != 2 { return 4; };
    return 0;
}

fn check_valid_args() -> i64 {
    qsim_graph_clear();
    if qsim_gate_record_preflight(0, 0 - 1) != qsim_graph_status_ok() { return 8; };
    if qsim_gate_record_preflight(1023, 0 - 1) != qsim_graph_status_ok() { return 16; };
    if qsim_gate_record_preflight(0, 1) != qsim_graph_status_ok() { return 32; };
    if qsim_gate_record_preflight(1022, 1023) != qsim_graph_status_ok() { return 64; };
    return 0;
}

fn check_out_of_range_args() -> i64 {
    qsim_graph_clear();
    if qsim_gate_record_preflight(0 - 1, 0 - 1) != qsim_graph_status_out_of_range() { return 128; };
    if qsim_gate_record_preflight(1024, 0 - 1) != qsim_graph_status_out_of_range() { return 256; };
    if qsim_gate_record_preflight(0, 0 - 2) != qsim_graph_status_out_of_range() { return 512; };
    if qsim_gate_record_preflight(0, 1024) != qsim_graph_status_out_of_range() { return 1024; };
    return 0;
}

fn check_dag_full() -> i64 {
    qsim_graph_clear();
    let mut i: i64 = 0;
    while i < qsim_graph_max_gates() {
        let g: i64 = qsim_gate_record("H", 0, 0 - 1);
        if g < 0 { return 2048; };
        i = i + 1;
    };
    if qsim_graph_gate_slots_remaining() != 0 { return 4096; };
    if qsim_gate_record_preflight(0, 0 - 1) != qsim_graph_status_dag_full() { return 8192; };
    if qsim_gate_record_preflight(0, 1) != qsim_graph_status_dag_full() { return 16384; };
    if qsim_gate_record_preflight(1024, 0 - 1) != qsim_graph_status_out_of_range() { return 32768; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_status_constants();
    fails = fails + check_valid_args();
    fails = fails + check_out_of_range_args();
    fails = fails + check_dag_full();
    qsim_graph_clear();
    return fails;
}
