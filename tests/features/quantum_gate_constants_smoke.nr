// v0834 QM-12 - shared quantum gate constants smoke.
//
// Locks the common H/CNOT/X/Z constants shared by MPS and diff_sim,
// plus the logical gate-kind mapping layer for backend-specific rotations.

import "stdlib/rods/quantum_gates.nr"
import "stdlib/rods/mps.nr"
import "stdlib/rods/diff_sim.nr"

fn check_common_constants() -> i64 {
    if qgate_h() != 0 { return 1; };
    if qgate_cnot() != 1 { return 2; };
    if qgate_x() != 2 { return 4; };
    if qgate_z() != 3 { return 8; };
    if qgate_common_supported(qgate_h()) != 1 { return 16; };
    if qgate_common_supported(qgate_cnot()) != 1 { return 32; };
    if qgate_common_supported(qgate_x()) != 1 { return 64; };
    if qgate_common_supported(qgate_z()) != 1 { return 128; };
    if qgate_common_supported(99) != 0 { return 256; };
    return 0;
}

fn check_logical_gate_kinds() -> i64 {
    if qgate_kind_h() != 0 { return 33554432; };
    if qgate_kind_cnot() != 1 { return 67108864; };
    if qgate_kind_x() != 2 { return 134217728; };
    if qgate_kind_z() != 3 { return 268435456; };
    if qgate_kind_rz() != 4 { return 536870912; };
    if qgate_kind_rx() != 5 { return 1073741824; };
    if qgate_kind_supported(qgate_kind_rz()) != 1 { return 2147483648; };
    if qgate_kind_supported(99) != 0 { return 4294967296; };
    if qgate_kind_is_rotation(qgate_kind_rz()) != 1 { return 8589934592; };
    if qgate_kind_is_rotation(qgate_kind_h()) != 0 { return 17179869184; };
    return 0;
}

fn check_mps_consumes_shared_common() -> i64 {
    if mps_gate_h() != qgate_h() { return 512; };
    if mps_gate_cnot() != qgate_cnot() { return 1024; };
    if mps_gate_x() != qgate_x() { return 2048; };
    if mps_gate_z() != qgate_z() { return 4096; };
    if mps_gate_rz() != qgate_mps_rz() { return 8192; };
    if mps_gate_rx() != qgate_mps_rx() { return 16384; };
    if mps_gate_from_kind(qgate_kind_rz()) != qgate_mps_rz() { return 34359738368; };
    if mps_gate_from_kind(qgate_kind_rx()) != qgate_mps_rx() { return 68719476736; };
    if mps_gate_kind_supported(qgate_kind_rx()) != 1 { return 137438953472; };
    return 0;
}

fn check_diff_sim_consumes_shared_common() -> i64 {
    if diff_gate_h() != qgate_h() { return 32768; };
    if diff_gate_cnot() != qgate_cnot() { return 65536; };
    if diff_gate_x() != qgate_x() { return 131072; };
    if diff_gate_z() != qgate_z() { return 262144; };
    if diff_gate_rz() != qgate_diff_rz() { return 524288; };
    if diff_gate_from_kind(qgate_kind_rz()) != qgate_diff_rz() { return 274877906944; };
    if diff_gate_from_kind(qgate_kind_rx()) != qgate_unsupported() { return 549755813888; };
    if diff_gate_kind_supported(qgate_kind_rx()) != 0 { return 1099511627776; };
    return 0;
}

fn check_rotation_mapping_disclosed() -> i64 {
    if qgate_mps_rz() == qgate_diff_rz() { return 1048576; };
    if qgate_kind_to_mps(qgate_kind_rz()) != qgate_mps_rz() { return 2199023255552; };
    if qgate_kind_to_diff(qgate_kind_rz()) != qgate_diff_rz() { return 4398046511104; };
    if qgate_kind_to_diff(qgate_kind_rx()) != qgate_unsupported() { return 8796093022208; };
    let s: str = qgate_limitations();
    if str_index_of(s, "logical gate kinds") < 0 { return 2097152; };
    if str_index_of(s, "RZ maps") < 0 { return 4194304; };
    if str_index_of(s, "RX maps") < 0 { return 17592186044416; };
    let m: str = mps_limitations();
    if str_index_of(m, "mps_gate_from_kind") < 0 { return 8388608; };
    let d: str = diff_sim_limitations();
    if str_index_of(d, "diff_gate_from_kind") < 0 { return 16777216; };
    return 0;
}

fn check_gate_kind_wrappers() -> i64 {
    let m: i64 = mps_init(1, 16);
    if m == 0 { return 35184372088832; };
    if mps_gate_kind(m, qgate_kind_rx(), 0, 0, 0) != 1 { mps_free(m); return 70368744177664; };
    if mps_gate_kind(m, 99, 0, 0, 0) != 0 { mps_free(m); return 140737488355328; };
    mps_free(m);

    let d: i64 = diff_sim_init(2, 2, 0, 42);
    if d == 0 { return 281474976710656; };
    if diff_gate_kind(d, qgate_kind_rz(), 0, 0, 0.0) != 1 { diff_free(d); return 562949953421312; };
    if diff_n_gates(d) != 1 { diff_free(d); return 1125899906842624; };
    if diff_gate_kind(d, qgate_kind_rx(), 0, 0, 0.0) != 0 { diff_free(d); return 2251799813685248; };
    if diff_n_gates(d) != 1 { diff_free(d); return 4503599627370496; };
    diff_free(d);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_common_constants();
    fails = fails + check_logical_gate_kinds();
    fails = fails + check_mps_consumes_shared_common();
    fails = fails + check_diff_sim_consumes_shared_common();
    fails = fails + check_rotation_mapping_disclosed();
    fails = fails + check_gate_kind_wrappers();
    return fails;
}
