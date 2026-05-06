// rods/logical_qubit — RFC-0054 Phase A: logical-qubit +
// pulse-level surface (rod-only).
//
// Nucleor's gate-level `quantum` rod ships statevector + Clifford
// + MPS; this rod adds the next-frontier surface RFC-0054 calls
// for: a typed distinction between logical and physical qubits,
// pulse-level schedules, and calibration-data types.
//
// The full RFC-0054 ship adds language-level
// `LogicalQubit<Code, distance>` + `@within(<duration>)` timing
// attribute + QIR/OpenQASM interop + decoder dispatch (~600 LOC
// compiler + ~1200 LOC stdlib + per-backend calibration parsers).
// Phase A (this rod) lands the canonical type surface + QEC code
// tags + waveform shapes + pulse / schedule / calibration data
// structures + a logical-qubit registry adopters can use today.
//
// Sister to RFC-0052 photonic + RFC-0053 neuromorphic Phase A.
// Hardware dispatch (IBM Q Pulse, IonQ, Quantinuum) and full
// surface-code decoders are the v2.x post-Phase-B ship.
//
// Workflow today:
//
//   import "stdlib/rods/logical_qubit.nr"
//
//   let lq: LogicalQubit = logical_qubit_new(qec_code_surface(), 7);
//   let pulse: Pulse = pulse(20, 1, 0, waveform_gaussian());
//   let sched: Schedule = schedule_new();
//   schedule_push(sched, pulse, 0);
//   let calib: CalibrationData = calibration_new("ibm_kyiv");
//   calibration_set_t1(calib, 0, 95);

#cfile "../runtime/logical_qubit_rt.c"

extern fn nuc_lq_register(code_id: i64, distance: i64) -> i64;
extern fn nuc_lq_count() -> i64;
extern fn nuc_lq_code(handle: i64) -> i64;
extern fn nuc_lq_distance(handle: i64) -> i64;
extern fn nuc_lq_release(handle: i64) -> i64;
extern fn nuc_lq_clear() -> i64;

// =====================================================
// QEC code tags (stable IDs).
// =====================================================
fn qec_code_surface() -> i64 { return 1; }
fn qec_code_toric()   -> i64 { return 2; }
fn qec_code_color()   -> i64 { return 3; }
fn qec_code_steane()  -> i64 { return 4; }
fn qec_code_shor()    -> i64 { return 5; }
fn qec_code_unknown() -> i64 { return 0; }

fn qec_code_name(id: i64) -> str {
    if id == 1 { return "SurfaceCode"; };
    if id == 2 { return "ToricCode"; };
    if id == 3 { return "ColorCode"; };
    if id == 4 { return "SteaneCode"; };
    if id == 5 { return "ShorCode"; };
    return "Unknown";
}

// Physical-qubits-per-logical for a distance-d code. These are
// the canonical bounds; real backends differ on auxiliaries.
fn qec_physical_qubits(code_id: i64, distance: i64) -> i64 {
    if code_id == 1 { return distance * distance + (distance * distance - 1); };  // surface code: d^2 data + d^2-1 syndrome
    if code_id == 2 { return 2 * distance * distance; };                          // toric code
    if code_id == 3 { return distance * distance; };                              // color code (approx)
    if code_id == 4 { return 7; };                                                // Steane is fixed [[7,1,3]]
    if code_id == 5 { return 9; };                                                // Shor is fixed [[9,1,3]]
    return 0;
}

// =====================================================
// LogicalQubit + PhysicalQubit structs.
// =====================================================
struct LogicalQubit {
    code: i64,
    distance: i64,
    handle: i64,
}

struct PhysicalQubit {
    handle: i64,
}

fn logical_qubit_new(code_id: i64, distance: i64) -> LogicalQubit {
    let h: i64 = nuc_lq_register(code_id, distance);
    return LogicalQubit { code: code_id, distance: distance, handle: h };
}

fn logical_qubit_code(lq: LogicalQubit) -> i64 { return lq.code; }
fn logical_qubit_distance(lq: LogicalQubit) -> i64 { return lq.distance; }
fn logical_qubit_handle(lq: LogicalQubit) -> i64 { return lq.handle; }

fn logical_qubit_count() -> i64 { return nuc_lq_count(); }
fn logical_qubit_clear() -> i64 { return nuc_lq_clear(); }

fn logical_qubit_max_registry() -> i64 { return 256; }
fn logical_qubit_registry_slots_remaining() -> i64 {
    return logical_qubit_max_registry() - logical_qubit_count();
}
fn logical_qubit_can_allocate() -> i64 {
    if logical_qubit_registry_slots_remaining() > 0 { return 1; };
    return 0;
}
fn logical_qubit_status_ok() -> i64 { return 0; }
fn logical_qubit_status_registry_full() -> i64 { return 1; }
fn logical_qubit_status_invalid_handle() -> i64 { return 2; }
fn logical_qubit_registry_preflight() -> i64 {
    if logical_qubit_can_allocate() == 1 { return logical_qubit_status_ok(); };
    return logical_qubit_status_registry_full();
}

fn logical_qubit_release_handle(handle: i64) -> i64 {
    if nuc_lq_release(handle) == 1 { return logical_qubit_status_ok(); };
    return logical_qubit_status_invalid_handle();
}

fn logical_qubit_release(lq: LogicalQubit) -> i64 {
    return logical_qubit_release_handle(lq.handle);
}

fn physical_qubit(handle: i64) -> PhysicalQubit {
    return PhysicalQubit { handle: handle };
}

// =====================================================
// Waveform shape tags (stable IDs).
// =====================================================
fn waveform_gaussian()   -> i64 { return 1; }
fn waveform_square()     -> i64 { return 2; }
fn waveform_drag()       -> i64 { return 3; }
fn waveform_cosine_tip() -> i64 { return 4; }
fn waveform_unknown()    -> i64 { return 0; }

fn waveform_name(id: i64) -> str {
    if id == 1 { return "Gaussian"; };
    if id == 2 { return "Square"; };
    if id == 3 { return "DRAG"; };
    if id == 4 { return "CosineTip"; };
    return "Unknown";
}

// =====================================================
// Pulse + Schedule.
// amplitude_q1616 / phase_q1616: Q1.16 fixed-point.
// =====================================================
struct Pulse {
    duration_ns: i64,
    amplitude_q1616: i64,
    phase_q1616: i64,
    waveform: i64,
}

fn pulse(duration_ns: i64, amp_q1616: i64, phase_q1616: i64, waveform_id: i64) -> Pulse {
    return Pulse {
        duration_ns: duration_ns,
        amplitude_q1616: amp_q1616,
        phase_q1616: phase_q1616,
        waveform: waveform_id,
    };
}

fn pulse_duration(p: Pulse) -> i64 { return p.duration_ns; }
fn pulse_amplitude(p: Pulse) -> i64 { return p.amplitude_q1616; }
fn pulse_waveform(p: Pulse) -> i64 { return p.waveform; }

struct Schedule {
    durations: Vec<i64>,
    amplitudes: Vec<i64>,
    phases: Vec<i64>,
    waveforms: Vec<i64>,
    qubits: Vec<i64>,
    starts_ns: Vec<i64>,
}

fn schedule_new() -> Schedule {
    let d: Vec<i64> = Vec::new();
    let a: Vec<i64> = Vec::new();
    let p: Vec<i64> = Vec::new();
    let w: Vec<i64> = Vec::new();
    let q: Vec<i64> = Vec::new();
    let s: Vec<i64> = Vec::new();
    return Schedule { durations: d, amplitudes: a, phases: p, waveforms: w, qubits: q, starts_ns: s };
}

fn schedule_push(sched: Schedule, p: Pulse, qubit_id: i64) -> i64 {
    let n: i64 = vec_len(sched.durations);
    let mut next_start: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let end_ns: i64 = vec_get(sched.starts_ns, i) + vec_get(sched.durations, i);
        if end_ns > next_start { next_start = end_ns; };
        i = i + 1;
    };
    sched.durations.push(p.duration_ns);
    sched.amplitudes.push(p.amplitude_q1616);
    sched.phases.push(p.phase_q1616);
    sched.waveforms.push(p.waveform);
    sched.qubits.push(qubit_id);
    sched.starts_ns.push(next_start);
    return 0;
}

fn schedule_count(sched: Schedule) -> i64 { return vec_len(sched.durations); }

fn schedule_total_duration(sched: Schedule) -> i64 {
    let n: i64 = vec_len(sched.durations);
    if n == 0 { return 0; };
    let mut max_end: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let end_ns: i64 = vec_get(sched.starts_ns, i) + vec_get(sched.durations, i);
        if end_ns > max_end { max_end = end_ns; };
        i = i + 1;
    };
    return max_end;
}

fn schedule_pulse_at(sched: Schedule, idx: i64) -> Pulse {
    return Pulse {
        duration_ns: vec_get(sched.durations, idx),
        amplitude_q1616: vec_get(sched.amplitudes, idx),
        phase_q1616: vec_get(sched.phases, idx),
        waveform: vec_get(sched.waveforms, idx),
    };
}

fn schedule_qubit_at(sched: Schedule, idx: i64) -> i64 { return vec_get(sched.qubits, idx); }
fn schedule_start_at(sched: Schedule, idx: i64) -> i64 { return vec_get(sched.starts_ns, idx); }

fn schedule_status_ok() -> i64 { return 0; }
fn schedule_status_overlap() -> i64 { return 1; }
fn schedule_status_invalid() -> i64 { return 2; }

fn schedule_push_at(sched: &mut Schedule, p: Pulse, qubit_id: i64, start_ns: i64) -> i64 {
    if start_ns < 0 { return schedule_status_invalid(); };
    if p.duration_ns <= 0 { return schedule_status_invalid(); };

    let n: i64 = vec_len(sched.durations);
    if vec_len(sched.starts_ns) != n { return schedule_status_invalid(); };
    if vec_len(sched.qubits) != n { return schedule_status_invalid(); };

    let new_end: i64 = start_ns + p.duration_ns;
    let mut i: i64 = 0;
    while i < n {
        let si: i64 = vec_get(sched.starts_ns, i);
        let di: i64 = vec_get(sched.durations, i);
        if si < 0 { return schedule_status_invalid(); };
        if di <= 0 { return schedule_status_invalid(); };
        if vec_get(sched.qubits, i) == qubit_id {
            let ei: i64 = si + di;
            if start_ns < ei {
                if si < new_end { return schedule_status_overlap(); };
            };
        };
        i = i + 1;
    };

    sched.durations.push(p.duration_ns);
    sched.amplitudes.push(p.amplitude_q1616);
    sched.phases.push(p.phase_q1616);
    sched.waveforms.push(p.waveform);
    sched.qubits.push(qubit_id);
    sched.starts_ns.push(start_ns);
    return schedule_status_ok();
}

fn schedule_validate_no_same_qubit_overlap(sched: Schedule) -> i64 {
    let n: i64 = vec_len(sched.durations);
    if vec_len(sched.starts_ns) != n { return schedule_status_invalid(); };
    if vec_len(sched.qubits) != n { return schedule_status_invalid(); };

    let mut i: i64 = 0;
    while i < n {
        let si: i64 = vec_get(sched.starts_ns, i);
        let di: i64 = vec_get(sched.durations, i);
        if si < 0 { return schedule_status_invalid(); };
        if di <= 0 { return schedule_status_invalid(); };
        let ei: i64 = si + di;

        let mut j: i64 = i + 1;
        while j < n {
            if vec_get(sched.qubits, i) == vec_get(sched.qubits, j) {
                let sj: i64 = vec_get(sched.starts_ns, j);
                let dj: i64 = vec_get(sched.durations, j);
                if sj < 0 { return schedule_status_invalid(); };
                if dj <= 0 { return schedule_status_invalid(); };
                let ej: i64 = sj + dj;
                if si < ej {
                    if sj < ei { return schedule_status_overlap(); };
                };
            };
            j = j + 1;
        };
        i = i + 1;
    };
    return schedule_status_ok();
}

// =====================================================
// CalibrationData — backend gate fidelities + T1 / T2
// coherence times. Q1.16 micrcoseconds for coherence
// times to keep everything in i64.
// =====================================================
struct CalibrationData {
    backend: str,
    gate_names: Vec<str>,
    gate_fidelities_q1616: Vec<i64>,
    t1_us_q1616: Vec<i64>,
    t2_us_q1616: Vec<i64>,
}

fn calibration_new(backend: str) -> CalibrationData {
    let gn: Vec<str> = Vec::new();
    let gf: Vec<i64> = Vec::new();
    let t1: Vec<i64> = Vec::new();
    let t2: Vec<i64> = Vec::new();
    return CalibrationData {
        backend: backend,
        gate_names: gn,
        gate_fidelities_q1616: gf,
        t1_us_q1616: t1,
        t2_us_q1616: t2,
    };
}

fn calibration_backend(c: CalibrationData) -> str { return c.backend; }

fn calibration_set_gate_fidelity(c: CalibrationData, gate: str, fidelity_q1616: i64) -> i64 {
    c.gate_names.push(gate);
    c.gate_fidelities_q1616.push(fidelity_q1616);
    return 0;
}

fn calibration_gate_count(c: CalibrationData) -> i64 { return vec_len(c.gate_names); }

fn calibration_set_t1(c: CalibrationData, qubit_id: i64, us_int: i64) -> i64 {
    while vec_len(c.t1_us_q1616) <= qubit_id { c.t1_us_q1616.push(0); };
    vec_set(c.t1_us_q1616, qubit_id, us_int * 65536);
    return 0;
}

fn calibration_set_t2(c: CalibrationData, qubit_id: i64, us_int: i64) -> i64 {
    while vec_len(c.t2_us_q1616) <= qubit_id { c.t2_us_q1616.push(0); };
    vec_set(c.t2_us_q1616, qubit_id, us_int * 65536);
    return 0;
}

fn calibration_t1_q1616(c: CalibrationData, qubit_id: i64) -> i64 {
    if qubit_id < 0 { return 0; };
    if vec_len(c.t1_us_q1616) <= qubit_id { return 0; };
    return vec_get(c.t1_us_q1616, qubit_id);
}

fn calibration_t2_q1616(c: CalibrationData, qubit_id: i64) -> i64 {
    if qubit_id < 0 { return 0; };
    if vec_len(c.t2_us_q1616) <= qubit_id { return 0; };
    return vec_get(c.t2_us_q1616, qubit_id);
}

// === R11-D5 Phase 1 (v0.8.285) — limitation diagnostics ===
//
// Per audit `BUILD_PLAN_R11_quantum_subsystem.md` §1 R11-D5
// (MEDIUM): the rod surface presents convention-level support for
// surface-code QEC, OpenQASM import/export, and mid-circuit
// feedback, but the actual primitives are absent. Phase 1 ships a
// `logical_qubit_limitations()` query helper that adopters can call
// to learn what's NOT supported before relying on it. Phase 2
// implements the primitives per the audit ship plan
// (surface-code → export/import → mid-circuit feedback).
fn logical_qubit_limitations() -> str {
    return "Logical-qubit / advanced quantum-subsystem limitations (QM-13/14/15/17, audit R11-D5 v0.8.285/v0830): (1) SURFACE-CODE QEC: Pulse / Schedule / CalibrationData scaffolding is present but no end-to-end d=3+ surface-code circuit synthesis or stabilizer-cycle insertion; the codes return integer durations + waveform IDs only. (2) SCHEDULE SAFETY: schedule_push_at(&mut sched, pulse, qubit, start_ns) inserts backend-parallel pulses only when same-qubit intervals do not overlap; schedule_validate_no_same_qubit_overlap(sched) audits existing schedules and malformed rows. Legacy schedule_push remains serialized append. (3) LOGICAL-QUBIT REGISTRY: process-local registry cap is 256; query logical_qubit_registry_preflight() / logical_qubit_registry_slots_remaining() before allocation. logical_qubit_release(lq) and logical_qubit_release_handle(handle) release individual registry slots for reuse; logical_qubit_clear() still wipes all entries. (4) OPENQASM IMPORT/EXPORT: no qasm.parse / qasm.emit functions; round-trip not supported. (5) QIR EXPORT: not implemented. (6) MID-CIRCUIT FEEDBACK: no measurement-conditioned-gate primitive; classical-control wires not modeled. Phase 2 ships these surfaces with deterministic small fixtures per RFC-0054 + audit R11-D5 ship plan.";
}
