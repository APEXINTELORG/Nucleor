// v0830 QM-11/QM-12 - diff_sim capacity/status smoke.
//
// Locks the stdlib preflight surface around the runtime's native caps and
// exposes named diff_sim gate constants used by capacity-safe call sites.
// Expected: rc=0.

import "stdlib/rods/diff_sim.nr"

fn check_caps() -> i64 {
    if diff_sim_max_qubits() != 12 { return 1; };
    if diff_sim_min_cores() != 2 { return 2; };
    if diff_sim_max_cores() != 16 { return 4; };
    if diff_sim_max_gates() != 200 { return 8; };
    return 0;
}

fn check_preflight() -> i64 {
    if diff_sim_init_preflight(1, 2) != diff_sim_status_ok() { return 16; };
    if diff_sim_init_preflight(12, 16) != diff_sim_status_ok() { return 32; };
    if diff_sim_init_preflight(0, 2) != diff_sim_status_invalid_qubits() { return 64; };
    if diff_sim_init_preflight(13, 2) != diff_sim_status_over_qubit_cap() { return 128; };
    if diff_sim_init_preflight(2, 1) != diff_sim_status_invalid_cores() { return 256; };
    if diff_sim_init_preflight(2, 17) != diff_sim_status_over_core_cap() { return 512; };
    return 0;
}

fn check_gate_constants() -> i64 {
    if diff_gate_h() != 0 { return 1024; };
    if diff_gate_cnot() != 1 { return 2048; };
    if diff_gate_x() != 2 { return 4096; };
    if diff_gate_z() != 3 { return 8192; };
    if diff_gate_rz() != 6 { return 16384; };
    if diff_gate_type_supported(diff_gate_h()) != 1 { return 32768; };
    if diff_gate_type_supported(99) != 0 { return 65536; };
    return 0;
}

fn check_small_init_still_works() -> i64 {
    let h: i64 = diff_sim_init(2, 2, 0, 42);
    if h == 0 { return 131072; };
    diff_gate(h, diff_gate_h(), 0, 0, 0);
    diff_gate(h, diff_gate_cnot(), 0, 1, 0);
    if diff_n_gates(h) != 2 { diff_free(h); return 262144; };
    diff_free(h);
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = diff_sim_limitations();
    if str_index_of(s, "QM-11") < 0 { return 524288; };
    if str_index_of(s, "diff_sim_init_preflight") < 0 { return 1048576; };
    if str_index_of(s, "over_qubit_cap") < 0 { return 2097152; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_caps();
    fails = fails + check_preflight();
    fails = fails + check_gate_constants();
    fails = fails + check_small_init_still_works();
    fails = fails + check_limitations();
    return fails;
}
