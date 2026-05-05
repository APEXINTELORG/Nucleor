// v0.8.213 stdlib/rods/logical_qubit.nr first test coverage.
//
// RFC-0054 Phase A: logical-qubit + pulse-level surface
// (rod-only). Pre-v0.8.213: zero coverage on the standalone
// rod. Phase B (~600 LOC compiler + ~1200 LOC stdlib +
// per-backend calibration parsers) is deferred.
//
// Locks four invariants Phase B compiler enforcement must NOT
// regress:
//
//   1. **Stable QEC code IDs + physical-qubit formulas** —
//      surface(d=3) = d²+(d²-1) = 17; Steane = 7 fixed;
//      Shor = 9 fixed.
//   2. **LogicalQubit construction round-trip** — code +
//      distance preserved; logical_qubit_count tracks registry.
//   3. **Schedule push tracks count + total_duration** — two
//      pulses of duration d1+d2 → total_duration = d1+d2;
//      starts at 0, d1 (back-to-back).
//   4. **Calibration T1/T2 round-trip** — set_t1(q, 5us) →
//      t1_q1616 = 5 * 65536 (Q1.16 fixed-point).
//
// Expected: rc=0.

import "stdlib/rods/logical_qubit.nr"

fn check_qec_codes() -> i64 {
    if qec_code_surface() != 1 { return 1; };
    if qec_code_toric() != 2 { return 2; };
    if qec_code_steane() != 4 { return 4; };
    if qec_code_shor() != 5 { return 8; };
    if qec_physical_qubits(qec_code_surface(), 3) != 17 { return 16; };
    if qec_physical_qubits(qec_code_steane(), 3) != 7 { return 32; };
    if qec_physical_qubits(qec_code_shor(), 3) != 9 { return 64; };
    return 0;
}

fn check_logical_qubit_round_trip() -> i64 {
    logical_qubit_clear();
    let lq: LogicalQubit = logical_qubit_new(qec_code_surface(), 7);
    if logical_qubit_code(lq) != qec_code_surface() { return 128; };
    if logical_qubit_distance(lq) != 7 { return 256; };
    if logical_qubit_count() != 1 { return 512; };
    return 0;
}

fn check_schedule_push() -> i64 {
    let s: Schedule = schedule_new();
    let p1: Pulse = pulse(20, 1, 0, waveform_gaussian());
    let p2: Pulse = pulse(15, 1, 0, waveform_square());
    schedule_push(s, p1, 0);
    schedule_push(s, p2, 0);
    if schedule_count(s) != 2 { return 1024; };
    if schedule_start_at(s, 0) != 0 { return 2048; };
    if schedule_start_at(s, 1) != 20 { return 4096; };
    if schedule_total_duration(s) != 35 { return 8192; };
    return 0;
}

fn check_calibration_t1_t2() -> i64 {
    let c: CalibrationData = calibration_new("ibm_kyiv");
    if str_eq(calibration_backend(c), "ibm_kyiv") != 1 { return 16384; };
    calibration_set_t1(c, 0, 95);
    calibration_set_t2(c, 0, 60);
    if calibration_t1_q1616(c, 0) != (95 * 65536) { return 32768; };
    if calibration_t2_q1616(c, 0) != (60 * 65536) { return 65536; };
    if calibration_t1_q1616(c, 99) != 0 { return 131072; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_qec_codes();
    fails = fails + check_logical_qubit_round_trip();
    fails = fails + check_schedule_push();
    fails = fails + check_calibration_t1_t2();
    return fails;
}
