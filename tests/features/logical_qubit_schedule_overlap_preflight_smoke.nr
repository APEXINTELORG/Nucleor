// v0830 QM-13 - pulse schedule same-qubit overlap preflight smoke.
//
// Locks schedule_validate_no_same_qubit_overlap for valid serialized schedules,
// valid parallel different-qubit schedules, same-qubit overlaps, and malformed
// pulse durations. Expected: rc=0.

import "stdlib/rods/logical_qubit.nr"

fn make_schedule(d0: i64, s0: i64, q0: i64, d1: i64, s1: i64, q1: i64) -> Schedule {
    let d: Vec<i64> = Vec::new();
    let a: Vec<i64> = Vec::new();
    let p: Vec<i64> = Vec::new();
    let w: Vec<i64> = Vec::new();
    let q: Vec<i64> = Vec::new();
    let s: Vec<i64> = Vec::new();
    d.push(d0); d.push(d1);
    a.push(1); a.push(1);
    p.push(0); p.push(0);
    w.push(waveform_gaussian()); w.push(waveform_square());
    q.push(q0); q.push(q1);
    s.push(s0); s.push(s1);
    return Schedule { durations: d, amplitudes: a, phases: p, waveforms: w, qubits: q, starts_ns: s };
}

fn check_serialized_same_qubit_allowed() -> i64 {
    let sched: Schedule = make_schedule(20, 0, 0, 15, 20, 0);
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_ok() { return 1; };
    return 0;
}

fn check_parallel_different_qubits_allowed() -> i64 {
    let sched: Schedule = make_schedule(20, 0, 0, 15, 0, 1);
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_ok() { return 2; };
    return 0;
}

fn check_same_qubit_overlap_rejected() -> i64 {
    let sched: Schedule = make_schedule(20, 0, 0, 15, 10, 0);
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_overlap() { return 4; };
    return 0;
}

fn check_invalid_duration_rejected() -> i64 {
    let sched: Schedule = make_schedule(20, 0, 0, 0, 20, 0);
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_invalid() { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_serialized_same_qubit_allowed();
    fails = fails + check_parallel_different_qubits_allowed();
    fails = fails + check_same_qubit_overlap_rejected();
    fails = fails + check_invalid_duration_rejected();
    return fails;
}
