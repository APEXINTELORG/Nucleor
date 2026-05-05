// v0.8.304 R11-D1 Phase 1 — qsim state-surface disclosure.
//
// Verifies qsim_max_qubits / qsim_supports_n_qubits / qsim_limitations.
//
// Locks 6 invariants:
//   1. cap = 24
//   2. n=1 supported
//   3. n=24 supported
//   4. n=25 NOT supported (over cap)
//   5. n=0 NOT supported (invalid)
//   6. limitations names "HARD CAP" + "NOISE"
//
// Expected: rc=0.

import "stdlib/rods/quantum.nr"

fn check_cap() -> i64 {
    if qsim_max_qubits() != 24 { return 1; };
    return 0;
}

fn check_n1_ok() -> i64 {
    if qsim_supports_n_qubits(1) != 1 { return 2; };
    return 0;
}

fn check_n24_ok() -> i64 {
    if qsim_supports_n_qubits(24) != 1 { return 4; };
    return 0;
}

fn check_n25_rejected() -> i64 {
    if qsim_supports_n_qubits(25) != 0 { return 8; };
    return 0;
}

fn check_n0_rejected() -> i64 {
    if qsim_supports_n_qubits(0) != 0 { return 16; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = qsim_limitations();
    if str_len(s) == 0 { return 32; };
    if str_index_of(s, "HARD CAP") < 0 { return 64; };
    if str_index_of(s, "NOISE") < 0 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cap();
    fails = fails + check_n1_ok();
    fails = fails + check_n24_ok();
    fails = fails + check_n25_rejected();
    fails = fails + check_n0_rejected();
    fails = fails + check_limitations();
    return fails;
}
