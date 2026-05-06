// v0830 QM-12 - shared quantum gate constants smoke.
//
// Locks the common H/CNOT/X/Z constants shared by MPS and diff_sim,
// and documents the current rotation divergence explicitly.

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

fn check_mps_consumes_shared_common() -> i64 {
    if mps_gate_h() != qgate_h() { return 512; };
    if mps_gate_cnot() != qgate_cnot() { return 1024; };
    if mps_gate_x() != qgate_x() { return 2048; };
    if mps_gate_z() != qgate_z() { return 4096; };
    if mps_gate_rz() != qgate_mps_rz() { return 8192; };
    if mps_gate_rx() != qgate_mps_rx() { return 16384; };
    return 0;
}

fn check_diff_sim_consumes_shared_common() -> i64 {
    if diff_gate_h() != qgate_h() { return 32768; };
    if diff_gate_cnot() != qgate_cnot() { return 65536; };
    if diff_gate_x() != qgate_x() { return 131072; };
    if diff_gate_z() != qgate_z() { return 262144; };
    if diff_gate_rz() != qgate_diff_rz() { return 524288; };
    return 0;
}

fn check_rotation_divergence_disclosed() -> i64 {
    if qgate_mps_rz() == qgate_diff_rz() { return 1048576; };
    let s: str = qgate_limitations();
    if str_index_of(s, "MPS RZ=4") < 0 { return 2097152; };
    if str_index_of(s, "diff_sim RZ=6") < 0 { return 4194304; };
    let m: str = mps_limitations();
    if str_index_of(m, "shared quantum_gates") < 0 { return 8388608; };
    let d: str = diff_sim_limitations();
    if str_index_of(d, "shared quantum_gates") < 0 { return 16777216; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_common_constants();
    fails = fails + check_mps_consumes_shared_common();
    fails = fails + check_diff_sim_consumes_shared_common();
    fails = fails + check_rotation_divergence_disclosed();
    return fails;
}
