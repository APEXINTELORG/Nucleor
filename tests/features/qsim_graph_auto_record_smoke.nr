// v0828 R11-D4 Phase 2b — qsim entangling gates auto-record
// gate-DAG intent through qsim_graph's checked-record surface.
//
// Locks that the high-level qsim wrappers update the queryable DAG
// even when tracing is disabled. SWAP inherits its records through
// the existing CNOT decomposition. CCX is represented by two
// control-target records because qsim_gate_record_checked is a
// two-qubit public surface.
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_cnot_cz_dependencies() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_cnot(sv, 0, 1);
    if qsim_gate_dag_size() != 1 { return 1; };

    qsim_cz(sv, 1, 2);
    if qsim_gate_dag_size() != 2 { return 2; };
    if qsim_gate_dag_depends_on(1, 0) != 1 { return 4; };
    return 0;
}

fn check_crk_records_after_prior_touches() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_cnot(sv, 0, 1);
    qsim_cz(sv, 1, 2);
    qsim_crk(sv, 0, 2, 3);
    if qsim_gate_dag_size() != 3 { return 8; };
    if qsim_gate_dag_parent_count(2) != 2 { return 16; };
    if qsim_gate_dag_depends_on(2, 0) != 1 { return 32; };
    if qsim_gate_dag_depends_on(2, 1) != 1 { return 64; };
    return 0;
}

fn check_swap_inherits_cnot_records() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(2);

    qsim_swap(sv, 0, 1);
    if qsim_gate_dag_size() != 3 { return 128; };
    if qsim_gate_dag_depends_on(1, 0) != 1 { return 256; };
    if qsim_gate_dag_depends_on(2, 1) != 1 { return 512; };
    return 0;
}

fn check_ccx_control_target_records() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_ccx(sv, 0, 1, 2);
    if qsim_gate_dag_size() != 2 { return 1024; };
    if qsim_gate_dag_depends_on(1, 0) != 1 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cnot_cz_dependencies();
    fails = fails + check_crk_records_after_prior_touches();
    fails = fails + check_swap_inherits_cnot_records();
    fails = fails + check_ccx_control_target_records();
    qsim_graph_clear();
    return fails;
}
