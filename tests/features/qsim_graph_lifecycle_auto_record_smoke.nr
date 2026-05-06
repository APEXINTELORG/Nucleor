// v0829 R11-D4 Phase 2d - qsim graph lifecycle + auto-record closure.
//
// Locks that high-level qsim wrappers update qsim_graph repeatably:
//   1. qsim_graph_clear resets entanglement and gate-DAG state.
//   2. A fresh qsim run after clear starts with zero graph/DAG counts.
//   3. CNOT, CZ, and CRK each add one DAG record and one entanglement edge.
//   4. SWAP records exactly its inherited three-CNOT sequence.
//   5. CCX remains the documented two control-target records.
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_clear_resets_both_states() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);
    qsim_cnot(sv, 0, 1);
    qsim_cz(sv, 1, 2);
    if qsim_entanglement_count() == 0 { return 1; };
    if qsim_gate_dag_size() == 0 { return 2; };

    qsim_graph_clear();
    if qsim_entanglement_count() != 0 { return 4; };
    if qsim_gate_dag_size() != 0 { return 8; };
    if qsim_graph_gate_slots_remaining() != qsim_graph_max_gates() { return 16; };
    return 0;
}

fn check_fresh_run_after_clear_starts_empty() -> i64 {
    qsim_graph_clear();
    let sv0: i64 = qsim_init(2);
    qsim_cnot(sv0, 0, 1);
    qsim_graph_clear();

    let sv1: i64 = qsim_init(2);
    if qsim_entanglement_count() != 0 { return 32; };
    if qsim_entanglement_same(0, 1) != 0 { return 64; };
    if qsim_gate_dag_size() != 0 { return 128; };

    qsim_x(sv1, 0);
    if qsim_entanglement_count() != 0 { return 256; };
    if qsim_gate_dag_size() != 0 { return 512; };
    return 0;
}

fn check_single_entangling_gate(name_code: i64) -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(2);
    if name_code == 0 { qsim_cnot(sv, 0, 1); };
    if name_code == 1 { qsim_cz(sv, 0, 1); };
    if name_code == 2 { qsim_crk(sv, 0, 1, 3); };

    if qsim_entanglement_same(0, 1) != 1 { return 1024; };
    if qsim_entanglement_count() != 1 { return 2048; };
    if qsim_gate_dag_size() != 1 { return 4096; };
    if qsim_gate_dag_parent_count(0) != 0 { return 8192; };
    return 0;
}

fn check_cnot_cz_crk_single_records() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_single_entangling_gate(0);
    fails = fails + check_single_entangling_gate(1);
    fails = fails + check_single_entangling_gate(2);
    return fails;
}

fn check_swap_inherited_record_shape() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(2);
    qsim_swap(sv, 0, 1);

    if qsim_entanglement_same(0, 1) != 1 { return 16384; };
    if qsim_entanglement_count() != 1 { return 32768; };
    if qsim_gate_dag_size() != 3 { return 65536; };
    if qsim_gate_dag_depends_on(1, 0) != 1 { return 131072; };
    if qsim_gate_dag_depends_on(2, 1) != 1 { return 262144; };
    return 0;
}

fn check_ccx_two_control_target_records() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);
    qsim_ccx(sv, 0, 1, 2);

    if qsim_entanglement_same(0, 2) != 1 { return 524288; };
    if qsim_entanglement_same(1, 2) != 1 { return 1048576; };
    if qsim_entanglement_size(2) != 3 { return 2097152; };
    if qsim_gate_dag_size() != 2 { return 4194304; };
    if qsim_gate_dag_depends_on(1, 0) != 1 { return 8388608; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_clear_resets_both_states();
    fails = fails + check_fresh_run_after_clear_starts_empty();
    fails = fails + check_cnot_cz_crk_single_records();
    fails = fails + check_swap_inherited_record_shape();
    fails = fails + check_ccx_two_control_target_records();
    qsim_graph_clear();
    return fails;
}
