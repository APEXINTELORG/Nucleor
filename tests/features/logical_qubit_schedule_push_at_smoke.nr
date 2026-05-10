// v0830 QM-13 - checked parallel schedule insertion smoke.
//
// Locks schedule_push_at for backend-parallel different-qubit pulses,
// same-qubit overlap rejection, boundary-touching insertion, and invalid rows.

import "stdlib/rods/logical_qubit.nr"

fn sched_count_ref(sched: &Schedule) -> i64 {
    return vec_len(sched.durations);
}

fn sched_start_ref(sched: &Schedule, idx: i64) -> i64 {
    return vec_get(sched.starts_ns, idx);
}

fn sched_total_ref(sched: &Schedule) -> i64 {
    let n: i64 = vec_len(sched.durations);
    let mut max_end: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let end_ns: i64 = vec_get(sched.starts_ns, i) + vec_get(sched.durations, i);
        if end_ns > max_end { max_end = end_ns; };
        i = i + 1;
    };
    return max_end;
}

fn check_parallel_different_qubits() -> i64 {
    let mut sched: Schedule = schedule_new();
    let p0: Pulse = pulse(20, 1, 0, waveform_gaussian());
    let p1: Pulse = pulse(15, 1, 0, waveform_square());

    if schedule_push_at(&mut sched, p0, 0, 0) != schedule_status_ok() { return 1; };
    if schedule_push_at(&mut sched, p1, 1, 0) != schedule_status_ok() { return 2; };
    if sched_count_ref(&sched) != 2 { return 4; };
    if sched_start_ref(&sched, 1) != 0 { return 8; };
    if sched_total_ref(&sched) != 20 { return 16; };
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_ok() { return 32; };
    return 0;
}

fn check_same_qubit_overlap_rejected_without_mutation() -> i64 {
    let mut sched: Schedule = schedule_new();
    let p0: Pulse = pulse(20, 1, 0, waveform_gaussian());
    let p1: Pulse = pulse(15, 1, 0, waveform_square());

    if schedule_push_at(&mut sched, p0, 0, 0) != schedule_status_ok() { return 64; };
    if schedule_push_at(&mut sched, p1, 0, 10) != schedule_status_overlap() { return 128; };
    if sched_count_ref(&sched) != 1 { return 256; };
    if sched_total_ref(&sched) != 20 { return 512; };
    return 0;
}

fn check_boundary_touching_same_qubit_allowed() -> i64 {
    let mut sched: Schedule = schedule_new();
    let p0: Pulse = pulse(20, 1, 0, waveform_gaussian());
    let p1: Pulse = pulse(15, 1, 0, waveform_square());

    if schedule_push_at(&mut sched, p0, 0, 0) != schedule_status_ok() { return 1024; };
    if schedule_push_at(&mut sched, p1, 0, 20) != schedule_status_ok() { return 2048; };
    if sched_count_ref(&sched) != 2 { return 4096; };
    if sched_total_ref(&sched) != 35 { return 8192; };
    if schedule_validate_no_same_qubit_overlap(sched) != schedule_status_ok() { return 16384; };
    return 0;
}

fn check_invalid_rows_rejected_without_mutation() -> i64 {
    let mut sched: Schedule = schedule_new();
    let ok: Pulse = pulse(20, 1, 0, waveform_gaussian());
    let bad: Pulse = pulse(0, 1, 0, waveform_square());

    if schedule_push_at(&mut sched, bad, 0, 0) != schedule_status_invalid() { return 32768; };
    if sched_count_ref(&sched) != 0 { return 65536; };
    if schedule_push_at(&mut sched, ok, 0, 0 - 1) != schedule_status_invalid() { return 131072; };
    if sched_count_ref(&sched) != 0 { return 262144; };
    return 0;
}

fn check_limitations_mentions_push_at() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "schedule_push_at") < 0 { return 524288; };
    if str_index_of(s, "Legacy schedule_push") < 0 { return 1048576; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_parallel_different_qubits();
    fails = fails + check_same_qubit_overlap_rejected_without_mutation();
    fails = fails + check_boundary_touching_same_qubit_allowed();
    fails = fails + check_invalid_rows_rejected_without_mutation();
    fails = fails + check_limitations_mentions_push_at();
    if fails == 0 { print("OK logical_qubit_schedule_push_at_smoke\n"); };
    return fails;
}
