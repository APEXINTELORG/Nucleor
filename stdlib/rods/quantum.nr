// =====================================================
// rods/quantum — Quantum circuit simulator
// =====================================================
// Import: import "stdlib/rods/quantum.nr"
//
// Statevector-based quantum simulator with S12b trace
// emission. Amplitudes are complex numbers (cx_* from
// the complex rod). Statevector is a Vec of cx handles.
//
// Provides:
//   State:  qsim_init, qsim_num_qubits, qsim_statevec
//   Gates:  qsim_h, qsim_x, qsim_y, qsim_z, qsim_cnot,
//           qsim_rx, qsim_ry, qsim_rz, qsim_swap, qsim_cz,
//           qsim_t, qsim_s, qsim_tdg, qsim_sdg, qsim_ccx,
//           qsim_crk, qsim_gate1, qsim_cgate1
//   Measure: qsim_measure, qsim_prob, qsim_prob_all
//   Utility: qsim_dump, qsim_reset, qsim_copy
//   Trace:   qtrace_init, qtrace_close, qtrace_phase,
//            qtrace_iteration
// =====================================================

import "complex.nr"
import "bitwise.nr"
import "qsim_graph.nr"
import "rod_helpers.nr"
import "strings.nr"

#cfile "quantum_rt.c"

// --- S12b trace externs ---
extern fn rods_trace_init(filename: str, n_qubits: i64);
extern fn rods_trace_close();
extern fn rods_trace_enabled() -> i64;
extern fn rods_trace_step() -> i64;
extern fn rods_trace_next_step() -> i64;
extern fn rods_trace_gate(gate: str, qubits_json: str, pre: i64, post: i64);
extern fn rods_trace_gate_angle(gate: str, qubits_json: str, angle_bits: i64);
extern fn rods_trace_entangle(gate: str, q1: i64, q2: i64);
extern fn rods_trace_sparsity(nonzero: i64, total: i64);
extern fn rods_trace_measure(qubit: i64, outcome: i64, prob: i64, collapse: i64);
extern fn rods_trace_phase(phase: str, detail: str);
extern fn rods_trace_iteration(iter: i64, gates: i64, prob: i64, components: i64);
extern fn rods_count_nonzero(sv: i64, threshold: i64) -> i64;
extern fn rods_trace_gate_influence(gate_step: i64, meas_step: i64, itype: str, chain_len: i64);
extern fn rods_trace_set_original(gates: i64, depth: i64, swaps: i64);
extern fn rods_i64_to_str(x: i64) -> str;

fn int_to_str(x: i64) -> str { return rods_i64_to_str(x); }

// S12b trace control
fn qtrace_init(filename: str, n_qubits: i64) { rods_trace_init(filename, n_qubits); }
fn qtrace_close() { rods_trace_close(); }
fn qtrace_phase(phase: str, detail: str) { rods_trace_phase(phase, detail); }
fn qtrace_set_original(gates: i64, depth: i64, swaps: i64) { rods_trace_set_original(gates, depth, swaps); }
fn qtrace_iteration(sv: i64, iter: i64, gates: i64, target: i64) {
    if rods_trace_enabled() == 1 {
        let prob: i64 = cx_abs_sq(vec_get(sv, target));
        let ncomp: i64 = 0;
        rods_trace_iteration(iter, gates, prob, 0);
    };
}

// Emit sparsity event
fn qtrace_sparsity(sv: i64) {
    if rods_trace_enabled() == 1 {
        let total: i64 = vec_len(sv);
        let threshold: i64 = f64(0, 1);
        let nonzero: i64 = rods_count_nonzero(sv, threshold);
        rods_trace_sparsity(nonzero, total);
    };
}

// =====================================================
// Statevector engine
// =====================================================

// Create an n-qubit simulator initialized to |0...0>
// Returns Vec handle (statevector of 2^n complex amplitudes)
fn qsim_init(n: i64) -> i64 {
    if n < 1 { return 0; };
    if n > 24 { return 0; };
    let size: i64 = bit_shift_left(1, n);
    let sv: i64 = vec_new();
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    vec_push(sv, one);
    let mut i: i64 = 1;
    while i < size {
        vec_push(sv, zero);
        i = i + 1;
    };
    return sv;
}

// Number of qubits from statevector size (log2)
fn qsim_num_qubits(sv: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let mut n: i64 = 0;
    let mut s: i64 = size;
    while s > 1 {
        s = bit_shift_right(s, 1);
        n = n + 1;
    };
    return n;
}

// =====================================================
// 1-qubit gate application (core engine)
// =====================================================

// Apply arbitrary 1-qubit gate matrix [[g00,g01],[g10,g11]] to qubit q
fn qsim_gate1(sv: i64, q: i64, g00: i64, g01: i64, g10: i64, g11: i64) {
    let size: i64 = vec_len(sv);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, q) == 0 {
            let j: i64 = bit_or(i, bit_shift_left(1, q));
            let ai: i64 = vec_get(sv, i);
            let aj: i64 = vec_get(sv, j);
            let new_i: i64 = cx_add(cx_mul(g00, ai), cx_mul(g01, aj));
            let new_j: i64 = cx_add(cx_mul(g10, ai), cx_mul(g11, aj));
            vec_set(sv, i, new_i);
            vec_set(sv, j, new_j);
        };
        i = i + 1;
    };
}

// Apply controlled 1-qubit gate: gate on target when control is |1>
fn qsim_cgate1(sv: i64, ctrl: i64, tgt: i64, g00: i64, g01: i64, g10: i64, g11: i64) {
    let size: i64 = vec_len(sv);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, ctrl) == 1 {
            if bit_test(i, tgt) == 0 {
                let j: i64 = bit_or(i, bit_shift_left(1, tgt));
                let ai: i64 = vec_get(sv, i);
                let aj: i64 = vec_get(sv, j);
                let new_i: i64 = cx_add(cx_mul(g00, ai), cx_mul(g01, aj));
                let new_j: i64 = cx_add(cx_mul(g10, ai), cx_mul(g11, aj));
                vec_set(sv, i, new_i);
                vec_set(sv, j, new_j);
            };
        };
        i = i + 1;
    };
}

// Doubly-controlled 1-qubit gate (for Toffoli etc.)
fn qsim_ccgate1(sv: i64, c1: i64, c2: i64, tgt: i64, g00: i64, g01: i64, g10: i64, g11: i64) {
    let size: i64 = vec_len(sv);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, c1) == 1 {
            if bit_test(i, c2) == 1 {
                if bit_test(i, tgt) == 0 {
                    let j: i64 = bit_or(i, bit_shift_left(1, tgt));
                    let ai: i64 = vec_get(sv, i);
                    let aj: i64 = vec_get(sv, j);
                    let new_i: i64 = cx_add(cx_mul(g00, ai), cx_mul(g01, aj));
                    let new_j: i64 = cx_add(cx_mul(g10, ai), cx_mul(g11, aj));
                    vec_set(sv, i, new_i);
                    vec_set(sv, j, new_j);
                };
            };
        };
        i = i + 1;
    };
}

// =====================================================
// Standard gates
// =====================================================

// --- Trace helper for qubit array JSON ---
fn _q1_json(q: i64) -> str {
    return str_concat(str_concat("[", int_to_str(q)), "]");
}
fn _q2_json(q1: i64, q2: i64) -> str {
    return str_concat(str_concat(str_concat(str_concat("[", int_to_str(q1)), ","), int_to_str(q2)), "]");
}
fn _q3_json(q1: i64, q2: i64, q3: i64) -> str {
    return str_concat(str_concat(str_concat(str_concat(str_concat(str_concat("[", int_to_str(q1)), ","), int_to_str(q2)), ","), int_to_str(q3)), "]");
}

// Hadamard: H = (1/sqrt(2)) * [[1, 1], [1, -1]]
fn qsim_h(sv: i64, q: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("H", _q1_json(q), 0, 0); };
    let h: i64 = cx_from_real(f64_inv_sqrt2());
    let mh: i64 = cx_neg(h);
    qsim_gate1(sv, q, h, h, h, mh);
}

// Pauli-X (NOT): [[0, 1], [1, 0]]
fn qsim_x(sv: i64, q: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("X", _q1_json(q), 0, 0); };
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    qsim_gate1(sv, q, zero, one, one, zero);
}

// Pauli-Y: [[0, -i], [i, 0]]
fn qsim_y(sv: i64, q: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("Y", _q1_json(q), 0, 0); };
    let zero: i64 = cx_zero();
    let ni: i64 = cx_neg(cx_i());
    let pi: i64 = cx_i();
    qsim_gate1(sv, q, zero, ni, pi, zero);
}

// Pauli-Z: [[1, 0], [0, -1]]
fn qsim_z(sv: i64, q: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("Z", _q1_json(q), 0, 0); };
    let one: i64 = cx_one();
    let mone: i64 = cx_neg(one);
    let zero: i64 = cx_zero();
    qsim_gate1(sv, q, one, zero, zero, mone);
}

// S gate (sqrt(Z)): [[1, 0], [0, i]]
fn qsim_s(sv: i64, q: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    qsim_gate1(sv, q, one, zero, zero, cx_i());
}

// S-dagger: [[1, 0], [0, -i]]
fn qsim_sdg(sv: i64, q: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    qsim_gate1(sv, q, one, zero, zero, cx_neg(cx_i()));
}

// T gate (pi/8): [[1, 0], [0, e^(i*pi/4)]]
fn qsim_t(sv: i64, q: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    let pi4: i64 = f64_div(f64_pi(), f64_from_int(4));
    let phase: i64 = cx_new(f64_cos(pi4), f64_sin(pi4));
    qsim_gate1(sv, q, one, zero, zero, phase);
}

// T-dagger: [[1, 0], [0, e^(-i*pi/4)]]
fn qsim_tdg(sv: i64, q: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    let pi4: i64 = f64_neg(f64_div(f64_pi(), f64_from_int(4)));
    let phase: i64 = cx_new(f64_cos(pi4), f64_sin(pi4));
    qsim_gate1(sv, q, one, zero, zero, phase);
}

// Rx(theta): [[cos(t/2), -i*sin(t/2)], [-i*sin(t/2), cos(t/2)]]
fn qsim_rx(sv: i64, q: i64, theta: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate_angle("RX", _q1_json(q), theta); };
    let half_t: i64 = f64_div(theta, f64_from_int(2));
    let c: i64 = cx_from_real(f64_cos(half_t));
    let ms: i64 = cx_new(f64_from_int(0), f64_neg(f64_sin(half_t)));
    qsim_gate1(sv, q, c, ms, ms, c);
}

// Ry(theta): [[cos(t/2), -sin(t/2)], [sin(t/2), cos(t/2)]]
fn qsim_ry(sv: i64, q: i64, theta: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate_angle("RY", _q1_json(q), theta); };
    let half_t: i64 = f64_div(theta, f64_from_int(2));
    let c: i64 = cx_from_real(f64_cos(half_t));
    let s: i64 = cx_from_real(f64_sin(half_t));
    let ms: i64 = cx_neg(s);
    qsim_gate1(sv, q, c, ms, s, c);
}

// Rz(theta): [[e^(-it/2), 0], [0, e^(it/2)]]
fn qsim_rz(sv: i64, q: i64, theta: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate_angle("RZ", _q1_json(q), theta); };
    let half_t: i64 = f64_div(theta, f64_from_int(2));
    let zero: i64 = cx_zero();
    let em: i64 = cx_new(f64_cos(f64_neg(half_t)), f64_sin(f64_neg(half_t)));
    let ep: i64 = cx_new(f64_cos(half_t), f64_sin(half_t));
    qsim_gate1(sv, q, em, zero, zero, ep);
}

// Phase gate P(theta): [[1, 0], [0, e^(i*theta)]]
fn qsim_p(sv: i64, q: i64, theta: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    let phase: i64 = cx_new(f64_cos(theta), f64_sin(theta));
    qsim_gate1(sv, q, one, zero, zero, phase);
}

// =====================================================
// 2-qubit gates
// =====================================================

// Audit fix HIGH-LAYER9B-003 (2026-05-08): preflight qubit-index range
// against qsim_num_qubits(sv) to keep entanglement-graph (1024-cap),
// trace-side union-find (32-cap), and state-vector caps consistent.
// Prior code accepted any ctrl/tgt and forwarded to qsim_entangle_register
// (1024-cap) + rods_trace_entangle (32-cap, silently skipped >=32) +
// qsim_cgate1 (cap = qsim_num_qubits(sv)). An out-of-range index would
// silently leave the state-vector unchanged while the entanglement graph
// recorded the pair as "entangled" — adopters got inconsistent reasoning
// across rods. The guard returns early without firing trace events on a
// malformed call.
fn _qsim_2q_in_range(sv: i64, a: i64, b: i64) -> i64 {
    let n: i64 = qsim_num_qubits(sv);
    if a < 0 { return 0; };
    if b < 0 { return 0; };
    if a >= n { return 0; };
    if b >= n { return 0; };
    if a == b { return 0; };
    return 1;
}

fn _qsim_branch_mass_nonzero(sv: i64, q: i64, branch: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let mut mass: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, q) == branch {
            mass = f64_add(mass, cx_abs_sq(vec_get(sv, i)));
        };
        i = i + 1;
    };
    let tiny: i64 = f64_div(f64_from_int(1), f64_from_int(1000000000));
    let threshold: i64 = f64_mul(tiny, f64_mul(tiny, tiny));
    if f64_gt(mass, threshold) == 1 { return 1; };
    return 0;
}

fn _qsim_control_has_both_branches(sv: i64, ctrl: i64) -> i64 {
    if _qsim_branch_mass_nonzero(sv, ctrl, 0) != 1 { return 0; };
    if _qsim_branch_mass_nonzero(sv, ctrl, 1) != 1 { return 0; };
    return 1;
}

fn _qsim_target_has_both_branches(sv: i64, tgt: i64) -> i64 {
    if _qsim_branch_mass_nonzero(sv, tgt, 0) != 1 { return 0; };
    if _qsim_branch_mass_nonzero(sv, tgt, 1) != 1 { return 0; };
    return 1;
}

fn _qsim_swap_state(sv: i64, q1: i64, q2: i64) {
    let size: i64 = vec_len(sv);
    let mask: i64 = bit_or(bit_shift_left(1, q1), bit_shift_left(1, q2));
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, q1) != bit_test(i, q2) {
            let j: i64 = bit_xor(i, mask);
            if i < j {
                let ai: i64 = vec_get(sv, i);
                let aj: i64 = vec_get(sv, j);
                vec_set(sv, i, aj);
                vec_set(sv, j, ai);
            };
        };
        i = i + 1;
    };
}

// CNOT (CX): controlled-X
fn qsim_cnot(sv: i64, ctrl: i64, tgt: i64) {
    if _qsim_2q_in_range(sv, ctrl, tgt) != 1 { return; };
    let should_mark_entangle: i64 = _qsim_control_has_both_branches(sv, ctrl);
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("CNOT", _q2_json(ctrl, tgt), 0, 0); };
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    qsim_cgate1(sv, ctrl, tgt, zero, one, one, zero);
    if should_mark_entangle == 1 {
        if rods_trace_enabled() == 1 { rods_trace_entangle("CNOT", ctrl, tgt); };
        qsim_entangle_register(ctrl, tgt);
    };
    qsim_gate_record_checked("CNOT", ctrl, tgt);
}

// CZ: controlled-Z
fn qsim_cz(sv: i64, ctrl: i64, tgt: i64) {
    if _qsim_2q_in_range(sv, ctrl, tgt) != 1 { return; };
    let mut should_mark_entangle: i64 = 0;
    if _qsim_control_has_both_branches(sv, ctrl) == 1 {
        if _qsim_target_has_both_branches(sv, tgt) == 1 {
            should_mark_entangle = 1;
        };
    };
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("CZ", _q2_json(ctrl, tgt), 0, 0); };
    let one: i64 = cx_one();
    let mone: i64 = cx_neg(one);
    let zero: i64 = cx_zero();
    qsim_cgate1(sv, ctrl, tgt, one, zero, zero, mone);
    if should_mark_entangle == 1 {
        if rods_trace_enabled() == 1 { rods_trace_entangle("CZ", ctrl, tgt); };
        qsim_entangle_register(ctrl, tgt);
    };
    qsim_gate_record_checked("CZ", ctrl, tgt);
}

// Controlled-Rk (controlled rotation by 2*pi/2^k) — used in QFT
fn qsim_crk(sv: i64, ctrl: i64, tgt: i64, k: i64) {
    if _qsim_2q_in_range(sv, ctrl, tgt) != 1 { return; };
    let mut should_mark_entangle: i64 = 0;
    if _qsim_control_has_both_branches(sv, ctrl) == 1 {
        if _qsim_target_has_both_branches(sv, tgt) == 1 {
            should_mark_entangle = 1;
        };
    };
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    let denom: i64 = f64_from_int(bit_shift_left(1, k));
    let theta: i64 = f64_div(f64_tau(), denom);
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate_angle("CRK", _q2_json(ctrl, tgt), theta); };
    let phase: i64 = cx_new(f64_cos(theta), f64_sin(theta));
    qsim_cgate1(sv, ctrl, tgt, one, zero, zero, phase);
    if should_mark_entangle == 1 {
        if rods_trace_enabled() == 1 { rods_trace_entangle("CRK", ctrl, tgt); };
        qsim_entangle_register(ctrl, tgt);
    };
    qsim_gate_record_checked("CRK", ctrl, tgt);
}

// SWAP: swap two qubits
//
// Audit fix HIGH-LAYER9B-005 (2026-05-09): apply SWAP as a primitive
// statevector permutation. The earlier wrapper emitted one SWAP event and
// then called public qsim_cnot three times, so trace and qsim_graph saw
// four logical gates and inherited CNOT entanglement records. SWAP is a
// non-entangling unitary by itself; it now records exactly one DAG event.
fn qsim_swap(sv: i64, q1: i64, q2: i64) {
    if _qsim_2q_in_range(sv, q1, q2) != 1 { return; };
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("SWAP", _q2_json(q1, q2), 0, 0); };
    _qsim_swap_state(sv, q1, q2);
    qsim_gate_record_checked("SWAP", q1, q2);
}

// =====================================================
// 3-qubit gates
// =====================================================

// Toffoli (CCX): doubly-controlled X
fn qsim_ccx(sv: i64, c1: i64, c2: i64, tgt: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("CCX", _q3_json(c1, c2, tgt), 0, 0); rods_trace_entangle("CCX", c1, tgt); rods_trace_entangle("CCX", c2, tgt); };
    qsim_entangle_register(c1, tgt);
    qsim_entangle_register(c2, tgt);
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    qsim_ccgate1(sv, c1, c2, tgt, zero, one, one, zero);
    qsim_gate_record_checked("CCX", c1, tgt);
    qsim_gate_record_checked("CCX", c2, tgt);
}

// =====================================================
// Measurement
// =====================================================

// Probability of measuring qubit q as |0>
fn qsim_prob0(sv: i64, q: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let mut prob: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, q) == 0 {
            let amp: i64 = vec_get(sv, i);
            prob = f64_add(prob, cx_abs_sq(amp));
        };
        i = i + 1;
    };
    return prob;
}

// Probability of measuring qubit q as `outcome` (0 or 1). This is
// the header-advertised compatibility surface; qsim_prob0 remains the
// lower-level primitive used internally.
fn qsim_prob(sv: i64, q: i64, outcome: i64) -> i64 {
    let p0: i64 = qsim_prob0(sv, q);
    if outcome == 0 { return p0; };
    if outcome == 1 { return f64_sub(f64_from_int(1), p0); };
    return f64_from_int(0);
}

fn qsim_feedback_gate_none() -> i64 { return 0; }
fn qsim_feedback_gate_h() -> i64 { return 1; }
fn qsim_feedback_gate_x() -> i64 { return 2; }
fn qsim_feedback_gate_y() -> i64 { return 3; }
fn qsim_feedback_gate_z() -> i64 { return 4; }
fn qsim_feedback_gate_s() -> i64 { return 5; }
fn qsim_feedback_gate_t() -> i64 { return 6; }
fn qsim_feedback_gate_rx() -> i64 { return 7; }
fn qsim_feedback_gate_ry() -> i64 { return 8; }
fn qsim_feedback_gate_rz() -> i64 { return 9; }

fn qsim_feedback_apply_gate(sv: i64, gate: i64, q: i64, angle: i64) -> i64 {
    if gate == qsim_feedback_gate_none() { return 1; };
    if gate == qsim_feedback_gate_h() { qsim_h(sv, q); return 1; };
    if gate == qsim_feedback_gate_x() { qsim_x(sv, q); return 1; };
    if gate == qsim_feedback_gate_y() { qsim_y(sv, q); return 1; };
    if gate == qsim_feedback_gate_z() { qsim_z(sv, q); return 1; };
    if gate == qsim_feedback_gate_s() { qsim_s(sv, q); return 1; };
    if gate == qsim_feedback_gate_t() { qsim_t(sv, q); return 1; };
    if gate == qsim_feedback_gate_rx() { qsim_rx(sv, q, angle); return 1; };
    if gate == qsim_feedback_gate_ry() { qsim_ry(sv, q, angle); return 1; };
    if gate == qsim_feedback_gate_rz() { qsim_rz(sv, q, angle); return 1; };
    return 0;
}

// Measure `measure_q`, then immediately apply one of two 1q feedback gates.
// Returns the measured outcome (0 or 1), -1 for invalid expected outcome,
// or -2 when the selected feedback gate code is unsupported.
fn qsim_if_measure(sv: i64, measure_q: i64, expected: i64, then_gate: i64, then_q: i64, else_gate: i64, else_q: i64, angle: i64) -> i64 {
    if expected != 0 {
        if expected != 1 { return 0 - 1; };
    };

    let outcome: i64 = qsim_measure(sv, measure_q);
    let mut ok: i64 = 0;
    if outcome == expected {
        ok = qsim_feedback_apply_gate(sv, then_gate, then_q, angle);
    } else {
        ok = qsim_feedback_apply_gate(sv, else_gate, else_q, angle);
    };
    if ok != 1 { return 0 - 2; };
    return outcome;
}

fn qsim_noise_status_ok() -> i64 { return 0; }
fn qsim_noise_status_invalid_probability() -> i64 { return 0 - 1; }

fn qsim_noise_probability_ok(p: i64) -> i64 {
    if f64_lt(p, f64_from_int(0)) == 1 { return 0; };
    if f64_gt(p, f64_from_int(1)) == 1 { return 0; };
    return 1;
}

fn qsim_noise_should_apply(p: i64) -> i64 {
    if qsim_noise_probability_ok(p) != 1 { return qsim_noise_status_invalid_probability(); };
    if f64_eq(p, f64_from_int(0)) == 1 { return 0; };
    if f64_eq(p, f64_from_int(1)) == 1 { return 1; };
    if f64_lt(rng_f64(), p) == 1 { return 1; };
    return 0;
}

// Stochastic-trajectory bit-flip noise: with probability p, apply X(q).
// This is a statevector trajectory surface, not a density-matrix backend.
fn qsim_noise_bit_flip(sv: i64, q: i64, p: i64) -> i64 {
    let apply: i64 = qsim_noise_should_apply(p);
    if apply < 0 { return apply; };
    if apply == 1 { qsim_x(sv, q); };
    return qsim_noise_status_ok();
}

// Stochastic-trajectory dephasing/phase-flip noise: with probability p,
// apply Z(q).
fn qsim_noise_dephase(sv: i64, q: i64, p: i64) -> i64 {
    let apply: i64 = qsim_noise_should_apply(p);
    if apply < 0 { return apply; };
    if apply == 1 { qsim_z(sv, q); };
    return qsim_noise_status_ok();
}

// Stochastic-trajectory depolarizing noise: with probability p, apply
// one of X/Y/Z uniformly. Deterministic p=0/p=1 callers can use the
// status return to gate tests; intermediate p uses the runtime RNG.
fn qsim_noise_depolarizing(sv: i64, q: i64, p: i64) -> i64 {
    let apply: i64 = qsim_noise_should_apply(p);
    if apply < 0 { return apply; };
    if apply == 1 {
        let branch: i64 = rng_range(3);
        if branch == 0 { qsim_x(sv, q); };
        if branch == 1 { qsim_y(sv, q); };
        if branch == 2 { qsim_z(sv, q); };
    };
    return qsim_noise_status_ok();
}

// Measure qubit q, collapse state, return outcome (0 or 1)
fn qsim_measure(sv: i64, q: i64) -> i64 {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); };
    let p0: i64 = qsim_prob0(sv, q);
    let r: i64 = rng_f64();
    let mut outcome: i64 = 0;
    if f64_lt(r, p0) == 0 {
        outcome = 1;
    };

    // Collapse: zero out inconsistent amplitudes, renormalize
    let size: i64 = vec_len(sv);
    let zero: i64 = cx_zero();
    let mut norm_sq: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < size {
        if bit_test(i, q) != outcome {
            vec_set(sv, i, zero);
        } else {
            norm_sq = f64_add(norm_sq, cx_abs_sq(vec_get(sv, i)));
        };
        i = i + 1;
    };

    // Audit fix MED-LAYER9B-014 (2026-05-08): zero-norm guard. If the
    // selected outcome's basis projection has zero probability mass
    // (e.g., a deep circuit with truncation has driven the conditional
    // probability under f64 underflow, or the RNG branch hits an
    // outcome the state assigns probability 0), then `norm_sq = 0` and
    // `1 / sqrt(0) = inf` would corrupt every amplitude. We refuse the
    // measurement and reset the state to the fallback |0..0> by skipping
    // the rescale; the returned outcome is still defined so callers see
    // a deterministic transcript, and `collapse_count == size - 1`
    // signals the degenerate path.
    // Zero-norm threshold ~ 1e-30: norm_sq below this means the
    // measurement projection has effectively zero probability mass.
    let _tiny: i64 = f64_div(f64_from_int(1), f64_from_int(1000000000));
    let zero_norm_thresh: i64 = f64_mul(_tiny, f64_mul(_tiny, _tiny));
    let zero_norm: i64 = f64_lt(norm_sq, zero_norm_thresh);
    let mut norm: i64 = f64_from_int(1);
    if zero_norm == 0 {
        norm = f64_div(f64_from_int(1), f64_sqrt(norm_sq));
    };
    i = 0;
    let mut collapse_count: i64 = 0;
    while i < size {
        if bit_test(i, q) == outcome {
            if zero_norm == 0 {
                vec_set(sv, i, cx_scale(vec_get(sv, i), norm));
            };
        } else {
            collapse_count = collapse_count + 1;
        };
        i = i + 1;
    };
    if zero_norm == 1 {
        // Degenerate measurement — restore the state to |0..0> so
        // subsequent gates see a clean canonical state instead of
        // (0+0i, ..., 0+0i) which is undefined.
        let one: i64 = cx_one();
        let cz: i64 = cx_zero();
        vec_set(sv, 0, one);
        let mut k: i64 = 1;
        while k < size { vec_set(sv, k, cz); k = k + 1; };
    };

    if rods_trace_enabled() == 1 {
        let mut meas_prob: i64 = p0;
        if outcome == 1 { meas_prob = f64_sub(f64_from_int(1), p0); };
        rods_trace_measure(q, outcome, meas_prob, collapse_count);
    };

    return outcome;
}

// Get probability distribution over all basis states
// Returns Vec of f64 values (|amp|^2 for each basis state)
fn qsim_prob_all(sv: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let probs: i64 = vec_new();
    let mut i: i64 = 0;
    while i < size {
        vec_push(probs, cx_abs_sq(vec_get(sv, i)));
        i = i + 1;
    };
    return probs;
}

// Sample from the distribution (returns basis state index)
fn qsim_sample(sv: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let r: i64 = rng_f64();
    let mut cumulative: i64 = f64_from_int(0);
    let mut i: i64 = 0;
    while i < size {
        cumulative = f64_add(cumulative, cx_abs_sq(vec_get(sv, i)));
        if f64_lt(r, cumulative) == 1 {
            return i;
        };
        i = i + 1;
    };
    return size - 1;
}

// =====================================================
// Utility
// =====================================================

// Print all amplitudes (for debugging small circuits)
fn qsim_dump(sv: i64) {
    let size: i64 = vec_len(sv);
    let n: i64 = qsim_num_qubits(sv);
    let mut i: i64 = 0;
    while i < size {
        let amp: i64 = vec_get(sv, i);
        let p: i64 = cx_abs_sq(amp);
        let threshold: i64 = f64(0, 1);
        if f64_gt(p, threshold) == 1 {
            print(cx_to_str(amp));
        };
        i = i + 1;
    };
}

// Return the underlying statevector handle explicitly. The state is
// already represented as a Vec<complex> handle; this wrapper makes the
// documented surface real without copying.
fn qsim_statevec(sv: i64) -> i64 {
    return sv;
}

// Deep-copy the statevector amplitudes. Complex values are handle
// objects, so copy their real/imag fields rather than aliasing handles.
fn qsim_copy(sv: i64) -> i64 {
    let size: i64 = vec_len(sv);
    let out: i64 = vec_new();
    let mut i: i64 = 0;
    while i < size {
        let amp: i64 = vec_get(sv, i);
        vec_push(out, cx_new(cx_real(amp), cx_imag(amp)));
        i = i + 1;
    };
    return out;
}

// Reset to |0...0>
fn qsim_reset(sv: i64) {
    let size: i64 = vec_len(sv);
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    vec_set(sv, 0, one);
    let mut i: i64 = 1;
    while i < size {
        vec_set(sv, i, zero);
        i = i + 1;
    };
}

// === R11-D1 Phase 1 (v0.8.304) — qsim state surface disclosure ===
//
// Per audit `BUILD_PLAN_R11_quantum_subsystem.md` §1 R11-D1 (HIGH):
// the rod's header documents missing statevec access (full
// amplitude vector readout); state accounting is capped at a hard
// qubit count internally. Adopters reading the rod can't query
// EITHER the cap NOR whether their qubit count is supported
// without trying it.
//
// Phase 1: ship `qsim_max_qubits()`, `qsim_supports_n_qubits(n)`,
// and `qsim_limitations()` text.

// Returns the maximum qubit count supported by qsim_init's
// underlying state-vector representation. As of v0.8.304 the safe
// limit is 24 (16M amplitudes × 16 bytes complex = 256 MB).
fn qsim_max_qubits() -> i64 {
    return 24;
}

// Returns 1 if `n` qubits is supported by qsim_init(n), 0 if it
// would exceed the cap. Adopters call BEFORE qsim_init.
fn qsim_supports_n_qubits(n: i64) -> i64 {
    if n < 1 { return 0; };
    if n > qsim_max_qubits() { return 0; };
    return 1;
}

fn qsim_status_ok() -> i64 { return 0; }
fn qsim_status_invalid_qubit_count() -> i64 { return 1; }
fn qsim_status_over_capacity() -> i64 { return 2; }

fn qsim_init_preflight(n: i64) -> i64 {
    if n < 1 { return qsim_status_invalid_qubit_count(); };
    if n > qsim_max_qubits() { return qsim_status_over_capacity(); };
    return qsim_status_ok();
}

fn qsim_init_checked(n: i64) -> i64 {
    if qsim_init_preflight(n) != qsim_status_ok() { return 0; };
    return qsim_init(n);
}

fn qsim_status_explain(status: i64) -> str {
    if status == qsim_status_ok() { return "ok"; };
    if status == qsim_status_invalid_qubit_count() { return "invalid_qubit_count"; };
    if status == qsim_status_over_capacity() { return "over_capacity"; };
    return "unknown";
}

fn qsim_limitations() -> str {
    return "qsim (statevec) rod limitations (QM-1/QM-2/QM-16/QM-17, audit R11-D1 v0.8.304/v0833/v0851): (1) HARD CAP at 24 qubits (16M amplitudes x 16 bytes ~ 256 MB working set). qsim_init(n) and qsim_init_checked(n) both return 0 for invalid/over-cap counts without allocation; qsim_init_preflight(n) and qsim_supports_n_qubits(n) expose status before allocation. Status codes: 0=ok, 1=invalid_qubit_count, 2=over_capacity. (2) QM-1 header compatibility is now real: qsim_prob, qsim_statevec, and qsim_copy exist. Full amplitude readout still uses raw vec_get on the i64 statevector handle; Phase 2 ships qsim_statevec_amplitude(sv, idx). (3) MID-CIRCUIT FEEDBACK: qsim_if_measure measures one qubit and immediately applies one of the supported 1q feedback gates (none/H/X/Y/Z/S/T/RX/RY/RZ) on the then/else branch. Hardware timing/lowering remains Phase B. (4) TRAJECTORY NOISE: qsim_noise_bit_flip, qsim_noise_dephase, and qsim_noise_depolarizing expose explicit per-gate stochastic trajectory noise with probability preflight. This is not a full density-matrix/Kraus backend. (5) NO TENSOR / DENSITY-MATRIX backend (MPS rod is separate). Phase 2 ships safe statevec readout + larger-circuit MPS handoff per audit R11-D1 ship plan.";
}

// =====================================================
// QM-7 OpenQASM2 minimal emitter (v0842, 2026-05-07)
// =====================================================
//
// Emit-only surface. Imports OpenQASM2 source remain explicitly out of
// scope; the limitations text below names the gap. Supported gates:
// H, X, Z, CX. Header is fixed:
//
//     OPENQASM 2.0;
//     include "qelib1.inc";
//     qreg q[N];
//
// A program handle is a Vec<i64>: slot 0 holds n_qubits as a raw i64,
// slots 1..len hold body lines as str pointers (vec_str_push). The
// builder never materializes unsupported gates — emit_named_* returns
// qasm2_status_unsupported_gate without mutating the program.

fn qasm2_max_qubits() -> i64 { return 1024; }

fn qasm2_status_ok() -> i64                  { return 0; }
fn qasm2_status_invalid_program() -> i64     { return 1; }
fn qasm2_status_qubit_out_of_range() -> i64  { return 2; }
fn qasm2_status_same_qubit() -> i64          { return 3; }
fn qasm2_status_unsupported_gate() -> i64    { return 4; }
fn qasm2_status_invalid_qubit_count() -> i64 { return 5; }

fn qasm2_status_explain(status: i64) -> str {
    if status == qasm2_status_ok()                  { return "ok"; };
    if status == qasm2_status_invalid_program()     { return "invalid_program"; };
    if status == qasm2_status_qubit_out_of_range()  { return "qubit_out_of_range"; };
    if status == qasm2_status_same_qubit()          { return "same_qubit"; };
    if status == qasm2_status_unsupported_gate()    { return "unsupported_gate"; };
    if status == qasm2_status_invalid_qubit_count() { return "invalid_qubit_count"; };
    return "unknown";
}

fn qasm2_program_new(n: i64) -> i64 {
    if n < 1 { return 0; };
    if n > qasm2_max_qubits() { return 0; };
    let p: i64 = vec_new();
    vec_push(p, n);
    return p;
}

fn qasm2_program_qubits(p: i64) -> i64 {
    if p == 0 { return 0; };
    return vec_get(p, 0);
}

fn qasm2_program_line_count(p: i64) -> i64 {
    if p == 0 { return 0; };
    return vec_len(p) - 1;
}

fn qasm2_qubit_in_range(p: i64, q: i64) -> i64 {
    if p == 0 { return 0; };
    if q < 0 { return 0; };
    if q >= vec_get(p, 0) { return 0; };
    return 1;
}

fn _qasm2_push_1q(p: i64, name: str, q: i64) -> i64 {
    if p == 0 { return qasm2_status_invalid_program(); };
    if qasm2_qubit_in_range(p, q) == 0 { return qasm2_status_qubit_out_of_range(); };
    let line: str = str_concat(str_concat(str_concat(name, " q["), int_to_str(q)), "];");
    vec_str_push(p, line);
    return qasm2_status_ok();
}

fn qasm2_emit_h(p: i64, q: i64) -> i64 { return _qasm2_push_1q(p, "h", q); }
fn qasm2_emit_x(p: i64, q: i64) -> i64 { return _qasm2_push_1q(p, "x", q); }
fn qasm2_emit_z(p: i64, q: i64) -> i64 { return _qasm2_push_1q(p, "z", q); }

fn qasm2_emit_cx(p: i64, ctrl: i64, tgt: i64) -> i64 {
    if p == 0 { return qasm2_status_invalid_program(); };
    if qasm2_qubit_in_range(p, ctrl) == 0 { return qasm2_status_qubit_out_of_range(); };
    if qasm2_qubit_in_range(p, tgt)  == 0 { return qasm2_status_qubit_out_of_range(); };
    if ctrl == tgt { return qasm2_status_same_qubit(); };
    let line: str = str_concat(
        str_concat(
            str_concat(
                str_concat(
                    str_concat("cx q[", int_to_str(ctrl)),
                    "],q["),
                int_to_str(tgt)),
            "];"),
        "");
    vec_str_push(p, line);
    return qasm2_status_ok();
}

// Returns 1 if `name` names one of the supported emit gates ("h", "x",
// "z", "cx"), else 0. Use BEFORE qasm2_emit_named_* if you want to
// branch without a status code.
fn qasm2_supported_gate(name: str) -> i64 {
    if str_eq(name, "h")  == 1 { return 1; };
    if str_eq(name, "x")  == 1 { return 1; };
    if str_eq(name, "z")  == 1 { return 1; };
    if str_eq(name, "cx") == 1 { return 1; };
    return 0;
}

// Name-dispatched 1-qubit emit. Returns qasm2_status_unsupported_gate
// for any name outside {h, x, z}.
fn qasm2_emit_named_1q(p: i64, name: str, q: i64) -> i64 {
    if str_eq(name, "h") == 1 { return qasm2_emit_h(p, q); };
    if str_eq(name, "x") == 1 { return qasm2_emit_x(p, q); };
    if str_eq(name, "z") == 1 { return qasm2_emit_z(p, q); };
    return qasm2_status_unsupported_gate();
}

// Name-dispatched 2-qubit emit. Returns qasm2_status_unsupported_gate
// for any name other than "cx".
fn qasm2_emit_named_2q(p: i64, name: str, ctrl: i64, tgt: i64) -> i64 {
    if str_eq(name, "cx") == 1 { return qasm2_emit_cx(p, ctrl, tgt); };
    return qasm2_status_unsupported_gate();
}

// Render the program as a deterministic OpenQASM 2.0 source string.
// Header is always the fixed three-line preamble; body lines are joined
// with a trailing newline each.
fn qasm2_render(p: i64) -> str {
    if p == 0 { return ""; };
    let n: i64 = vec_get(p, 0);
    let mut out: str = "OPENQASM 2.0;\n";
    out = str_concat(out, "include \"qelib1.inc\";\n");
    out = str_concat(out, str_concat(str_concat("qreg q[", int_to_str(n)), "];\n"));
    let total: i64 = vec_len(p);
    let mut i: i64 = 1;
    while i < total {
        out = str_concat(out, vec_str_get(p, i));
        out = str_concat(out, "\n");
        i = i + 1;
    };
    return out;
}

fn qasm2_limitations() -> str {
    return "qsim OpenQASM 2.0 emit + minimal parser (QM-7 v0842 emit + v0843 parser): (1) Round-trip is closed for the H/X/Z/CX subset emitted by qasm2_render. The parser qasm2_parse(src) accepts ONLY the deterministic emit dialect: exact header lines 'OPENQASM 2.0;' + 'include \"qelib1.inc\";' + 'qreg q[N];', then per-line gates 'h q[N];' / 'x q[N];' / 'z q[N];' / 'cx q[A],q[B];' separated by '\\n'. There is intentionally no whitespace tolerance, no comment handling, no alternative spelling, no creg, no measurement, no classical control, no parameterized rotations, and no barrier/reset. Real importing of foreign OpenQASM2 sources remains future work. (2) Supported gate subset is H/X/Z/CX. Name-dispatched emit (qasm2_emit_named_1q / qasm2_emit_named_2q) returns qasm2_status_unsupported_gate (4) for any other gate without mutating the program. The parser returns qasm2_status_parse_unsupported_gate (9) for any gate name outside {h,x,z,cx} and propagates the existing emit-side qasm2_status_qubit_out_of_range / same_qubit / invalid_qubit_count codes when the source references invalid qubits. (3) Header is fixed: 'OPENQASM 2.0;', 'include \"qelib1.inc\";', 'qreg q[N];'. (4) HARD CAP at qasm2_max_qubits() = 1024 qubits, enforced by both emit and parse. (5) Status codes: 0=ok, 1=invalid_program, 2=qubit_out_of_range, 3=same_qubit, 4=unsupported_gate, 5=invalid_qubit_count, 6=parse_empty_source, 7=parse_unexpected_header, 8=parse_malformed_qreg, 9=parse_unsupported_gate, 10=parse_malformed_gate. (6) Parse result is a 2-slot Vec<i64> handle: slot 0 = status, slot 1 = program handle on success or 0 on failure. Use qasm2_parse_result_status / qasm2_parse_result_program to decode.";
}

// =====================================================
// QM-7 OpenQASM 2.0 minimal parser (v0843, 2026-05-08)
// =====================================================
//
// Closes the round-trip story opened by qasm2_render. The parser
// accepts ONLY the exact deterministic dialect that qasm2_render
// emits: fixed header, then per-line H/X/Z/CX gate forms separated
// by '\n'. This is intentionally not a general OpenQASM2 importer.

fn qasm2_status_parse_empty_source() -> i64       { return 6; }
fn qasm2_status_parse_unexpected_header() -> i64  { return 7; }
fn qasm2_status_parse_malformed_qreg() -> i64     { return 8; }
fn qasm2_status_parse_unsupported_gate() -> i64   { return 9; }
fn qasm2_status_parse_malformed_gate() -> i64     { return 10; }

fn qasm2_status_parse_explain(status: i64) -> str {
    if status == qasm2_status_parse_empty_source()      { return "parse_empty_source"; };
    if status == qasm2_status_parse_unexpected_header() { return "parse_unexpected_header"; };
    if status == qasm2_status_parse_malformed_qreg()    { return "parse_malformed_qreg"; };
    if status == qasm2_status_parse_unsupported_gate()  { return "parse_unsupported_gate"; };
    if status == qasm2_status_parse_malformed_gate()    { return "parse_malformed_gate"; };
    return qasm2_status_explain(status);
}

// Parse a non-negative decimal integer from an entire string slice.
// Rejects empty, negative, and non-digit input. Caps at
// qasm2_max_qubits()+1 so the parser cannot accumulate past a
// reasonable bound on the qreg-size-style integers it sees.
fn _qasm2_parse_uint(s: str) -> i64 {
    let n: i64 = str_len(s);
    if n == 0 { return 0 - 1; };
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c < 48 { return 0 - 1; };
        if c > 57 { return 0 - 1; };
        acc = acc * 10 + (c - 48);
        if acc > qasm2_max_qubits() + 1 { return 0 - 1; };
        i = i + 1;
    };
    return acc;
}

// Parse the qubit operand of a "<name> q[N];" 1q gate line. Returns
// the qubit index, or -1 on parse failure (wrong prefix, missing
// "];" suffix, malformed integer).
fn _qasm2_parse_1q_arg(line: str, name: str) -> i64 {
    let prefix: str = str_concat(name, " q[");
    if strings_starts_with(line, prefix) != 1 { return 0 - 1; };
    if strings_ends_with(line, "];") != 1 { return 0 - 1; };
    let plen: i64 = str_len(prefix);
    let llen: i64 = str_len(line);
    if llen < plen + 3 { return 0 - 1; };
    let inner: str = str_substring(line, plen, llen - 2);
    return _qasm2_parse_uint(inner);
}

// Parse "cx q[A],q[B];" into a 2-slot Vec<i64> [ctrl, tgt]. Either
// slot is -1 on parse failure.
fn _qasm2_parse_cx_args(line: str) -> i64 {
    let result: i64 = vec_new();
    vec_push(result, 0 - 1);
    vec_push(result, 0 - 1);

    if strings_starts_with(line, "cx q[") != 1 { return result; };
    if strings_ends_with(line, "];") != 1 { return result; };
    let llen: i64 = str_len(line);
    if llen < 11 { return result; };
    let inner: str = str_substring(line, 5, llen - 2);
    let mid: i64 = strings_index_of(inner, "],q[");
    if mid < 0 { return result; };
    let ctrl_str: str = str_substring(inner, 0, mid);
    let tgt_str: str = str_substring(inner, mid + 4, str_len(inner));
    let ctrl: i64 = _qasm2_parse_uint(ctrl_str);
    let tgt: i64 = _qasm2_parse_uint(tgt_str);
    if ctrl < 0 { return result; };
    if tgt < 0 { return result; };
    vec_set(result, 0, ctrl);
    vec_set(result, 1, tgt);
    return result;
}

// Dispatch one body line to the right emit_* call. Returns the emit
// status code, or qasm2_status_parse_malformed_gate /
// qasm2_status_parse_unsupported_gate on parser-level failure.
fn _qasm2_parse_gate_into(p: i64, line: str) -> i64 {
    if strings_starts_with(line, "h q[") == 1 {
        let q: i64 = _qasm2_parse_1q_arg(line, "h");
        if q < 0 { return qasm2_status_parse_malformed_gate(); };
        return qasm2_emit_h(p, q);
    };
    if strings_starts_with(line, "x q[") == 1 {
        let q: i64 = _qasm2_parse_1q_arg(line, "x");
        if q < 0 { return qasm2_status_parse_malformed_gate(); };
        return qasm2_emit_x(p, q);
    };
    if strings_starts_with(line, "z q[") == 1 {
        let q: i64 = _qasm2_parse_1q_arg(line, "z");
        if q < 0 { return qasm2_status_parse_malformed_gate(); };
        return qasm2_emit_z(p, q);
    };
    if strings_starts_with(line, "cx q[") == 1 {
        let args: i64 = _qasm2_parse_cx_args(line);
        let ctrl: i64 = vec_get(args, 0);
        let tgt: i64 = vec_get(args, 1);
        if ctrl < 0 { return qasm2_status_parse_malformed_gate(); };
        if tgt < 0 { return qasm2_status_parse_malformed_gate(); };
        return qasm2_emit_cx(p, ctrl, tgt);
    };
    return qasm2_status_parse_unsupported_gate();
}

fn _qasm2_parse_result_new(status: i64, program: i64) -> i64 {
    let r: i64 = vec_new();
    vec_push(r, status);
    vec_push(r, program);
    return r;
}

// Parse `src` as the deterministic emit dialect. Returns a 2-slot
// Vec<i64> result handle: slot 0 = status, slot 1 = program handle
// (0 on failure). Decode with qasm2_parse_result_status /
// qasm2_parse_result_program.
fn qasm2_parse(src: str) -> i64 {
    if str_len(src) == 0 {
        return _qasm2_parse_result_new(qasm2_status_parse_empty_source(), 0);
    };

    let parts: Vec<i32> = strings_split(src, "\n");
    let nparts: i64 = parts.len();

    // Render appends a trailing '\n' after each body line, so split
    // produces a final empty element. Treat empty trailing parts as
    // benign rather than as malformed gate lines.
    if nparts < 3 {
        return _qasm2_parse_result_new(qasm2_status_parse_unexpected_header(), 0);
    };

    if str_eq(parts.get(0), "OPENQASM 2.0;") != 1 {
        return _qasm2_parse_result_new(qasm2_status_parse_unexpected_header(), 0);
    };
    if str_eq(parts.get(1), "include \"qelib1.inc\";") != 1 {
        return _qasm2_parse_result_new(qasm2_status_parse_unexpected_header(), 0);
    };

    let qreg_line: str = parts.get(2);
    if strings_starts_with(qreg_line, "qreg q[") != 1 {
        return _qasm2_parse_result_new(qasm2_status_parse_malformed_qreg(), 0);
    };
    if strings_ends_with(qreg_line, "];") != 1 {
        return _qasm2_parse_result_new(qasm2_status_parse_malformed_qreg(), 0);
    };
    let qreg_inner: str = str_substring(qreg_line, 7, str_len(qreg_line) - 2);
    let n: i64 = _qasm2_parse_uint(qreg_inner);
    if n < 1 {
        return _qasm2_parse_result_new(qasm2_status_parse_malformed_qreg(), 0);
    };
    if n > qasm2_max_qubits() {
        return _qasm2_parse_result_new(qasm2_status_invalid_qubit_count(), 0);
    };

    let p: i64 = qasm2_program_new(n);
    if p == 0 {
        return _qasm2_parse_result_new(qasm2_status_invalid_qubit_count(), 0);
    };

    let mut i: i64 = 3;
    while i < nparts {
        let line: str = parts.get(i);
        // Skip the trailing empty element that strings_split produces
        // when src ends with '\n'.
        if str_len(line) == 0 {
            i = i + 1;
        } else {
            let st: i64 = _qasm2_parse_gate_into(p, line);
            if st != qasm2_status_ok() {
                return _qasm2_parse_result_new(st, 0);
            };
            i = i + 1;
        };
    };

    return _qasm2_parse_result_new(qasm2_status_ok(), p);
}

fn qasm2_parse_result_status(r: i64) -> i64 {
    if r == 0 { return qasm2_status_invalid_program(); };
    return vec_get(r, 0);
}

fn qasm2_parse_result_program(r: i64) -> i64 {
    if r == 0 { return 0; };
    return vec_get(r, 1);
}

// Returns 1 iff two program handles describe the same n_qubits and
// the same body line sequence. Used by round-trip tests:
// qasm2_program_eq(p, qasm2_parse_result_program(qasm2_parse(qasm2_render(p)))).
fn qasm2_program_eq(a: i64, b: i64) -> i64 {
    if a == 0 { return 0; };
    if b == 0 { return 0; };
    if vec_get(a, 0) != vec_get(b, 0) { return 0; };
    let la: i64 = vec_len(a);
    let lb: i64 = vec_len(b);
    if la != lb { return 0; };
    let mut i: i64 = 1;
    while i < la {
        if str_eq(vec_str_get(a, i), vec_str_get(b, i)) != 1 { return 0; };
        i = i + 1;
    };
    return 1;
}
