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

// CNOT (CX): controlled-X
fn qsim_cnot(sv: i64, ctrl: i64, tgt: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("CNOT", _q2_json(ctrl, tgt), 0, 0); rods_trace_entangle("CNOT", ctrl, tgt); };
    qsim_entangle_register(ctrl, tgt);
    let zero: i64 = cx_zero();
    let one: i64 = cx_one();
    qsim_cgate1(sv, ctrl, tgt, zero, one, one, zero);
    qsim_gate_record_checked("CNOT", ctrl, tgt);
}

// CZ: controlled-Z
fn qsim_cz(sv: i64, ctrl: i64, tgt: i64) {
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate("CZ", _q2_json(ctrl, tgt), 0, 0); rods_trace_entangle("CZ", ctrl, tgt); };
    qsim_entangle_register(ctrl, tgt);
    let one: i64 = cx_one();
    let mone: i64 = cx_neg(one);
    let zero: i64 = cx_zero();
    qsim_cgate1(sv, ctrl, tgt, one, zero, zero, mone);
    qsim_gate_record_checked("CZ", ctrl, tgt);
}

// Controlled-Rk (controlled rotation by 2*pi/2^k) — used in QFT
fn qsim_crk(sv: i64, ctrl: i64, tgt: i64, k: i64) {
    let one: i64 = cx_one();
    let zero: i64 = cx_zero();
    let denom: i64 = f64_from_int(bit_shift_left(1, k));
    let theta: i64 = f64_div(f64_tau(), denom);
    if rods_trace_enabled() == 1 { rods_trace_next_step(); rods_trace_gate_angle("CRK", _q2_json(ctrl, tgt), theta); rods_trace_entangle("CRK", ctrl, tgt); };
    qsim_entangle_register(ctrl, tgt);
    let phase: i64 = cx_new(f64_cos(theta), f64_sin(theta));
    qsim_cgate1(sv, ctrl, tgt, one, zero, zero, phase);
    qsim_gate_record_checked("CRK", ctrl, tgt);
}

// SWAP: swap two qubits
fn qsim_swap(sv: i64, q1: i64, q2: i64) {
    qsim_cnot(sv, q1, q2);
    qsim_cnot(sv, q2, q1);
    qsim_cnot(sv, q1, q2);
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

    // Renormalize
    let norm: i64 = f64_div(f64_from_int(1), f64_sqrt(norm_sq));
    i = 0;
    let mut collapse_count: i64 = 0;
    while i < size {
        if bit_test(i, q) == outcome {
            vec_set(sv, i, cx_scale(vec_get(sv, i), norm));
        } else {
            collapse_count = collapse_count + 1;
        };
        i = i + 1;
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
    return "qsim (statevec) rod limitations (QM-1/QM-2/QM-17, audit R11-D1 v0.8.304/v0833/v0851): (1) HARD CAP at 24 qubits (16M amplitudes x 16 bytes ~ 256 MB working set). qsim_init(n) and qsim_init_checked(n) both return 0 for invalid/over-cap counts without allocation; qsim_init_preflight(n) and qsim_supports_n_qubits(n) expose status before allocation. Status codes: 0=ok, 1=invalid_qubit_count, 2=over_capacity. (2) QM-1 header compatibility is now real: qsim_prob, qsim_statevec, and qsim_copy exist. Full amplitude readout still uses raw vec_get on the i64 statevector handle; Phase 2 ships qsim_statevec_amplitude(sv, idx). (3) MID-CIRCUIT FEEDBACK: qsim_if_measure measures one qubit and immediately applies one of the supported 1q feedback gates (none/H/X/Y/Z/S/T/RX/RY/RZ) on the then/else branch. Hardware timing/lowering remains Phase B. (4) NO TENSOR / DENSITY-MATRIX backend (MPS rod is separate). (5) NO NOISE MODEL: gates are perfect - no T1/T2/dephasing. Phase 2 ships safe statevec readout + larger-circuit MPS handoff per audit R11-D1 ship plan.";
}
