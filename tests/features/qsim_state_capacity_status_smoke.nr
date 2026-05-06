// v0830 QM-2 - qsim statevector capacity/status smoke.
//
// Locks the stdlib preflight surface around qsim_init's statevector cap.
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_status_constants() -> i64 {
    if qsim_status_ok() != 0 { return 1; };
    if qsim_status_invalid_qubit_count() != 1 { return 2; };
    if qsim_status_over_capacity() != 2 { return 4; };
    return 0;
}

fn check_preflight() -> i64 {
    if qsim_max_qubits() != 24 { return 8; };
    if qsim_init_preflight(1) != qsim_status_ok() { return 16; };
    if qsim_init_preflight(24) != qsim_status_ok() { return 32; };
    if qsim_init_preflight(0) != qsim_status_invalid_qubit_count() { return 64; };
    if qsim_init_preflight(25) != qsim_status_over_capacity() { return 128; };
    if qsim_supports_n_qubits(25) != 0 { return 256; };
    return 0;
}

fn check_status_explain() -> i64 {
    if str_eq(qsim_status_explain(qsim_status_ok()), "ok") != 1 { return 512; };
    if str_eq(qsim_status_explain(qsim_status_invalid_qubit_count()), "invalid_qubit_count") != 1 { return 1024; };
    if str_eq(qsim_status_explain(qsim_status_over_capacity()), "over_capacity") != 1 { return 2048; };
    return 0;
}

fn check_small_init_still_works() -> i64 {
    let sv: i64 = qsim_init(3);
    if sv == 0 { return 4096; };
    if qsim_num_qubits(sv) != 3 { return 8192; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = qsim_limitations();
    if str_index_of(s, "QM-2") < 0 { return 16384; };
    if str_index_of(s, "qsim_init_preflight") < 0 { return 32768; };
    if str_index_of(s, "over_capacity") < 0 { return 65536; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_status_constants();
    fails = fails + check_preflight();
    fails = fails + check_status_explain();
    fails = fails + check_small_init_still_works();
    fails = fails + check_limitations();
    return fails;
}
