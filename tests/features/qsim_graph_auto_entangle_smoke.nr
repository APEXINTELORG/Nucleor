// v0828 R11-D4 Phase 2a — qsim entangling gates auto-register
// with qsim_graph's union-find tracker.
//
// Locks the stdlib contract that CNOT/CZ/CRK/CCX declare graph
// entanglement even when tracing is disabled. SWAP inherits the
// behavior through its existing CNOT decomposition.
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_cnot_cz_chain() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_cnot(sv, 0, 1);
    if qsim_entanglement_same(0, 1) != 1 { return 1; };
    if qsim_entanglement_count() != 1 { return 2; };

    qsim_cz(sv, 1, 2);
    if qsim_entanglement_same(0, 2) != 1 { return 4; };
    if qsim_entanglement_size(0) != 3 { return 8; };
    return 0;
}

fn check_crk_pair() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_crk(sv, 0, 2, 3);
    if qsim_entanglement_same(0, 2) != 1 { return 16; };
    if qsim_entanglement_count() != 1 { return 32; };
    return 0;
}

fn check_ccx_links_both_controls() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_ccx(sv, 0, 1, 2);
    if qsim_entanglement_same(0, 2) != 1 { return 64; };
    if qsim_entanglement_same(1, 2) != 1 { return 128; };
    if qsim_entanglement_size(2) != 3 { return 256; };
    return 0;
}

fn check_swap_inherits_cnot_registration() -> i64 {
    qsim_graph_clear();
    let sv: i64 = qsim_init(3);

    qsim_swap(sv, 0, 2);
    if qsim_entanglement_same(0, 2) != 1 { return 512; };
    if qsim_entanglement_count() != 1 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cnot_cz_chain();
    fails = fails + check_crk_pair();
    fails = fails + check_ccx_links_both_controls();
    fails = fails + check_swap_inherits_cnot_registration();
    return fails;
}
