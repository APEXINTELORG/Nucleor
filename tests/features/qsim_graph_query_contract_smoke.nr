// v0829 R11-D4 Phase 2e - qsim graph query contract smoke.
//
// Locks that adopters can inspect the auto-recorded gate DAG through public
// qsim_graph helpers after a mixed manual/high-level sequence:
//   1. parent_count and parent_at expose direct parents.
//   2. depends_on follows transitive dependencies.
//   3. SWAP inherits the expected three CNOT records.
//   4. clear/rebuild resets query state.
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_mixed_query_contract() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(4);

    let h0: i64 = qsim_gate_record_checked("H", 0, 0 - 1);
    if h0 != 0 { return 1; };
    if qsim_gate_dag_parent_count(h0) != 0 { return 2; };
    if qsim_gate_dag_parent_at(h0, 0) != (0 - 1) { return 4; };

    qsim_cnot(sv, 0, 1);
    if qsim_gate_dag_size() != 2 { return 8; };
    if qsim_gate_dag_parent_count(1) != 1 { return 16; };
    if qsim_gate_dag_parent_at(1, 0) != h0 { return 32; };
    if qsim_gate_dag_parent_at(1, 1) != (0 - 1) { return 64; };

    qsim_cz(sv, 1, 2);
    if qsim_gate_dag_parent_count(2) != 1 { return 128; };
    if qsim_gate_dag_parent_at(2, 0) != 1 { return 256; };

    qsim_crk(sv, 0, 2, 3);
    if qsim_gate_dag_parent_count(3) != 2 { return 512; };
    if qsim_gate_dag_parent_at(3, 0) != 1 { return 1024; };
    if qsim_gate_dag_parent_at(3, 1) != 2 { return 2048; };
    if qsim_gate_dag_depends_on(3, h0) != 1 { return 4096; };
    if qsim_gate_dag_depends_on(3, 2) != 1 { return 8192; };

    qsim_swap(sv, 0, 3);
    if qsim_gate_dag_size() != 7 { return 16384; };
    if qsim_gate_dag_parent_count(4) != 1 { return 32768; };
    if qsim_gate_dag_parent_at(4, 0) != 3 { return 65536; };
    if qsim_gate_dag_parent_count(5) != 1 { return 131072; };
    if qsim_gate_dag_parent_at(5, 0) != 4 { return 262144; };
    if qsim_gate_dag_parent_count(6) != 1 { return 524288; };
    if qsim_gate_dag_parent_at(6, 0) != 5 { return 1048576; };
    if qsim_gate_dag_depends_on(6, h0) != 1 { return 2097152; };
    return 0;
}

fn check_clear_rebuild_query_state() -> i64 {
    qsim_graph_clear();
    let sv0: i64 = qsim_init(2);
    qsim_cnot(sv0, 0, 1);
    if qsim_gate_dag_size() != 1 { return 4194304; };

    qsim_graph_clear();
    if qsim_gate_dag_size() != 0 { return 8388608; };
    let sv1: i64 = qsim_init(2);
    qsim_cnot(sv1, 0, 1);
    if qsim_gate_dag_size() != 1 { return 16777216; };
    if qsim_gate_dag_parent_count(0) != 0 { return 33554432; };
    if qsim_gate_dag_parent_at(0, 0) != (0 - 1) { return 67108864; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mixed_query_contract();
    fails = fails + check_clear_rebuild_query_state();
    qsim_graph_clear();
    return fails;
}
