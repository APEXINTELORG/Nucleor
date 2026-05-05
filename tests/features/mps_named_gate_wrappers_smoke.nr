// v0.8.305 R11-D2 Phase 1 — MPS named gate wrappers + supported query.
//
// Locks 8 invariants:
//   1. mps_gate_h() = 0
//   2. mps_gate_cnot() = 1
//   3. mps_gate_x() = 2
//   4. mps_gate_z() = 3
//   5. mps_gate_rz() = 4
//   6. mps_gate_rx() = 5
//   7. mps_gate_type_supported(0..5) all = 1; supported(99) = 0
//   8. mps_limitations names "GATE COVERAGE" + "Y, S, T"
//
// Expected: rc=0.

import "stdlib/rods/mps.nr"

fn check_codes() -> i64 {
    if mps_gate_h() != 0 { return 1; };
    if mps_gate_cnot() != 1 { return 2; };
    if mps_gate_x() != 2 { return 4; };
    if mps_gate_z() != 3 { return 8; };
    if mps_gate_rz() != 4 { return 16; };
    if mps_gate_rx() != 5 { return 32; };
    return 0;
}

fn check_supported() -> i64 {
    if mps_gate_type_supported(0) != 1 { return 64; };
    if mps_gate_type_supported(1) != 1 { return 128; };
    if mps_gate_type_supported(5) != 1 { return 256; };
    if mps_gate_type_supported(99) != 0 { return 512; };
    if mps_gate_type_supported(0 - 1) != 0 { return 1024; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = mps_limitations();
    if str_len(s) == 0 { return 2048; };
    if str_index_of(s, "GATE COVERAGE") < 0 { return 4096; };
    if str_index_of(s, "Y, S, T") < 0 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_codes();
    fails = fails + check_supported();
    fails = fails + check_limitations();
    return fails;
}
