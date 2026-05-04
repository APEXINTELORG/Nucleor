// v0.7.97 RFC-0054 Phase A smoke fixture — logical-qubit +
// pulse-level surface. Validates:
//   - QEC code tags + name + physical-qubits formula
//   - LogicalQubit construction + getters + registry round-trip
//   - PhysicalQubit construction
//   - Waveform shape tags + name
//   - Pulse construction + accessors
//   - Schedule push, count, total_duration, pulse_at, qubit_at,
//     start_at compute correct timing
//   - CalibrationData backend, gate fidelity registration,
//     T1/T2 set + Q1.16 read-back
import "stdlib/rods/logical_qubit.nr"

fn main() -> i64 {
    logical_qubit_clear();

    // QEC code tags.
    if qec_code_surface() != 1 { return 1; };
    if qec_code_steane() != 4 { return 2; };
    if str_eq(qec_code_name(1), "SurfaceCode") == 0 { return 3; };
    if str_eq(qec_code_name(99), "Unknown") == 0 { return 4; };

    // Surface-code distance-3: 9 data + 8 syndrome = 17.
    if qec_physical_qubits(qec_code_surface(), 3) != 17 { return 5; };
    // Steane is fixed at 7.
    if qec_physical_qubits(qec_code_steane(), 99) != 7 { return 6; };

    // LogicalQubit construction + registry.
    let lq1: LogicalQubit = logical_qubit_new(qec_code_surface(), 7);
    if logical_qubit_code(lq1) != qec_code_surface() { return 7; };
    if logical_qubit_distance(lq1) != 7 { return 8; };

    let lq2: LogicalQubit = logical_qubit_new(qec_code_steane(), 3);
    if logical_qubit_count() != 2 { return 9; };

    // PhysicalQubit.
    let pq: PhysicalQubit = physical_qubit(42);
    if pq.handle != 42 { return 10; };

    // Waveform tags.
    if waveform_gaussian() != 1 { return 11; };
    if waveform_drag() != 3 { return 12; };
    if str_eq(waveform_name(3), "DRAG") == 0 { return 13; };

    // Pulse construction.
    let p1: Pulse = pulse(20, 65536, 0, waveform_gaussian());
    if pulse_duration(p1) != 20 { return 14; };
    if pulse_amplitude(p1) != 65536 { return 15; };
    if pulse_waveform(p1) != waveform_gaussian() { return 16; };

    // Schedule.
    let sched: Schedule = schedule_new();
    if schedule_count(sched) != 0 { return 17; };
    if schedule_total_duration(sched) != 0 { return 18; };

    schedule_push(sched, p1, 0);
    let p2: Pulse = pulse(35, 32768, 0, waveform_drag());
    schedule_push(sched, p2, 1);
    let p3: Pulse = pulse(15, 65536, 0, waveform_square());
    schedule_push(sched, p3, 0);

    if schedule_count(sched) != 3 { return 19; };
    if schedule_total_duration(sched) != 70 { return 20; };  // 20 + 35 + 15

    if schedule_start_at(sched, 0) != 0 { return 21; };
    if schedule_start_at(sched, 1) != 20 { return 22; };
    if schedule_start_at(sched, 2) != 55 { return 23; };

    let pAt2: Pulse = schedule_pulse_at(sched, 2);
    if pAt2.duration_ns != 15 { return 24; };
    if pAt2.waveform != waveform_square() { return 25; };
    if schedule_qubit_at(sched, 1) != 1 { return 26; };

    // CalibrationData.
    let calib: CalibrationData = calibration_new("ibm_kyiv");
    if str_eq(calibration_backend(calib), "ibm_kyiv") == 0 { return 27; };

    calibration_set_gate_fidelity(calib, "x", 65470);    // ~0.999
    calibration_set_gate_fidelity(calib, "cx", 64880);   // ~0.99
    if calibration_gate_count(calib) != 2 { return 28; };

    calibration_set_t1(calib, 0, 95);
    calibration_set_t2(calib, 0, 80);
    calibration_set_t1(calib, 1, 110);

    if calibration_t1_q1616(calib, 0) != 95 * 65536 { return 29; };
    if calibration_t2_q1616(calib, 0) != 80 * 65536 { return 30; };
    if calibration_t1_q1616(calib, 1) != 110 * 65536 { return 31; };
    if calibration_t1_q1616(calib, 999) != 0 { return 32; };

    logical_qubit_clear();
    if logical_qubit_count() != 0 { return 33; };

    return 0;
}
