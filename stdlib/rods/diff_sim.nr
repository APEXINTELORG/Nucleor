// rods/diff_sim — Differentiable quantum simulation
//
// N-core (parallel circuit replicas), learnable noise logits per
// gate, von Neumann entropy backprop. The runtime supports forward
// state-vector evolution, adjoint-method backprop through gates,
// per-feature gradient extraction, gate-importance scoring, and
// import / export of learned noise priors.
//
// Modes encoded in `mode_bits`: bit 0 = noisy / clean, bit 1 =
// per-feature gradient, bit 2 = state-vector caching. See the
// runtime for the full enumeration.
//
// Float values cross the FFI as i64 reinterpreted bits
// (`*_bits` parameters).
//
// See `stdlib/runtime/diff_sim_rt.c`.
import "quantum_gates.nr"
#cfile "../runtime/diff_sim_rt.c"

extern fn nuc_diff_sim_init(nq: i64, n_cores: i64, mode_bits: i64, seed: i64) -> i64;
extern fn nuc_diff_sim_init_from_prior(nq: i64, n_cores: i64, prior_vec: i64, seed: i64) -> i64;
extern fn nuc_diff_gate(handle: i64, gate_type: i64, q0: i64, q1: i64, angle_bits: i64);
extern fn nuc_diff_extract(handle: i64) -> i64;
extern fn nuc_diff_backward(handle: i64, grad_loss_bits: i64);
extern fn nuc_diff_backward_perfeature(handle: i64, grad_input_vec: i64);
extern fn nuc_diff_backward_selective(handle: i64, grad_loss_bits: i64, threshold_bits: i64);
extern fn nuc_diff_get_logits(handle: i64) -> i64;
extern fn nuc_diff_get_grad_logits(handle: i64) -> i64;
extern fn nuc_diff_set_logits(handle: i64, vec: i64);
extern fn nuc_diff_zero_grad(handle: i64);
extern fn nuc_diff_reset(handle: i64);
extern fn nuc_diff_reset_cached(handle: i64) -> i64;
extern fn nuc_diff_cache_clean(handle: i64);
extern fn nuc_diff_resize_cores(handle: i64, new_n_cores: i64) -> i64;
extern fn nuc_diff_n_gates(handle: i64) -> i64;
extern fn nuc_diff_n_noisy(handle: i64) -> i64;
extern fn nuc_diff_logit_count(handle: i64) -> i64;
extern fn nuc_diff_gate_importance(handle: i64) -> i64;
extern fn nuc_diff_export_prior(handle: i64) -> i64;
extern fn nuc_diff_get_sv(handle: i64, core: i64) -> i64;
extern fn nuc_diff_get_probs(handle: i64, core: i64) -> i64;
extern fn nuc_diff_free(handle: i64);

fn diff_sim_init(nq: i64, n_cores: i64, mode_bits: i64, seed: i64) -> i64 {
    if diff_sim_init_preflight(nq, n_cores) != diff_sim_status_ok() { return 0; };
    return nuc_diff_sim_init(nq, n_cores, mode_bits, seed);
}
fn diff_sim_init_from_prior(nq: i64, n_cores: i64, prior_vec: i64, seed: i64) -> i64 {
    return nuc_diff_sim_init_from_prior(nq, n_cores, prior_vec, seed);
}
fn diff_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle_bits: i64) {
    nuc_diff_gate(h, gate_type, q0, q1, angle_bits);
}
fn diff_extract(h: i64) -> i64 { return nuc_diff_extract(h); }
fn diff_backward(h: i64, grad_loss_bits: i64) {
    nuc_diff_backward(h, grad_loss_bits);
}
fn diff_backward_perfeature(h: i64, grad_input_vec: i64) {
    nuc_diff_backward_perfeature(h, grad_input_vec);
}
fn diff_backward_selective(h: i64, grad_loss_bits: i64, threshold_bits: i64) {
    nuc_diff_backward_selective(h, grad_loss_bits, threshold_bits);
}
fn diff_get_logits(h: i64) -> i64 { return nuc_diff_get_logits(h); }
fn diff_get_grad_logits(h: i64) -> i64 { return nuc_diff_get_grad_logits(h); }
fn diff_set_logits(h: i64, v: i64) { nuc_diff_set_logits(h, v); }
fn diff_zero_grad(h: i64) { nuc_diff_zero_grad(h); }
fn diff_reset(h: i64) { nuc_diff_reset(h); }
fn diff_reset_cached(h: i64) -> i64 { return nuc_diff_reset_cached(h); }
fn diff_cache_clean(h: i64) { nuc_diff_cache_clean(h); }
fn diff_resize_cores(h: i64, n: i64) -> i64 { return nuc_diff_resize_cores(h, n); }
fn diff_n_gates(h: i64) -> i64 { return nuc_diff_n_gates(h); }
fn diff_n_noisy(h: i64) -> i64 { return nuc_diff_n_noisy(h); }
fn diff_logit_count(h: i64) -> i64 { return nuc_diff_logit_count(h); }
fn diff_gate_importance(h: i64) -> i64 { return nuc_diff_gate_importance(h); }
fn diff_export_prior(h: i64) -> i64 { return nuc_diff_export_prior(h); }
fn diff_get_sv(h: i64, core: i64) -> i64 { return nuc_diff_get_sv(h, core); }
fn diff_get_probs(h: i64, core: i64) -> i64 { return nuc_diff_get_probs(h, core); }
fn diff_free(h: i64) { nuc_diff_free(h); }

// === QM-11 / QM-12 capacity and gate constants (v0830) ===
//
// Mirrors the current runtime caps in stdlib/runtime/diff_sim_rt.c so callers
// can preflight before hitting the native clamp behavior.
fn diff_sim_max_qubits() -> i64 { return 12; }
fn diff_sim_max_cores() -> i64 { return 16; }
fn diff_sim_min_cores() -> i64 { return 2; }
fn diff_sim_max_gates() -> i64 { return 200; }

fn diff_gate_h() -> i64 { return qgate_h(); }
fn diff_gate_cnot() -> i64 { return qgate_cnot(); }
fn diff_gate_x() -> i64 { return qgate_x(); }
fn diff_gate_z() -> i64 { return qgate_z(); }
fn diff_gate_rz() -> i64 { return qgate_kind_to_diff(qgate_kind_rz()); }
fn diff_gate_from_kind(kind: i64) -> i64 { return qgate_kind_to_diff(kind); }
fn diff_gate_kind_supported(kind: i64) -> i64 { return qgate_kind_supported_by_diff(kind); }

fn diff_gate_type_supported(gate_type: i64) -> i64 {
    if gate_type == diff_gate_h() { return 1; };
    if gate_type == diff_gate_cnot() { return 1; };
    if gate_type == diff_gate_x() { return 1; };
    if gate_type == diff_gate_z() { return 1; };
    if gate_type == diff_gate_rz() { return 1; };
    return 0;
}

fn diff_sim_status_ok() -> i64 { return 0; }
fn diff_sim_status_invalid_qubits() -> i64 { return 1; }
fn diff_sim_status_over_qubit_cap() -> i64 { return 2; }
fn diff_sim_status_invalid_cores() -> i64 { return 3; }
fn diff_sim_status_over_core_cap() -> i64 { return 4; }

fn diff_sim_init_preflight(nq: i64, n_cores: i64) -> i64 {
    if nq < 1 { return diff_sim_status_invalid_qubits(); };
    if nq > diff_sim_max_qubits() { return diff_sim_status_over_qubit_cap(); };
    if n_cores < diff_sim_min_cores() { return diff_sim_status_invalid_cores(); };
    if n_cores > diff_sim_max_cores() { return diff_sim_status_over_core_cap(); };
    return diff_sim_status_ok();
}

fn diff_sim_init_checked(nq: i64, n_cores: i64, mode_bits: i64, seed: i64) -> i64 {
    if diff_sim_init_preflight(nq, n_cores) != diff_sim_status_ok() { return 0; };
    return diff_sim_init(nq, n_cores, mode_bits, seed);
}

fn diff_sim_supports_n_qubits(nq: i64) -> i64 {
    if nq < 1 { return 0; };
    if nq > diff_sim_max_qubits() { return 0; };
    return 1;
}

fn diff_sim_status_explain(status: i64) -> str {
    if status == diff_sim_status_ok() { return "ok"; };
    if status == diff_sim_status_invalid_qubits() { return "invalid_qubits"; };
    if status == diff_sim_status_over_qubit_cap() { return "over_qubit_cap"; };
    if status == diff_sim_status_invalid_cores() { return "invalid_cores"; };
    if status == diff_sim_status_over_core_cap() { return "over_core_cap"; };
    return "unknown";
}

fn diff_sim_limitations() -> str {
    return "diff_sim rod limitations (QM-11/QM-12, v0834): (1) HARD CAPS mirror runtime constants: 12 qubits, 16 cores, 200 gates. diff_sim_init(nq, n_cores, mode_bits, seed) and diff_sim_init_checked(...) both return 0 for invalid/over-cap inputs instead of relying on native clamp behavior. diff_sim_init_preflight(nq, n_cores) exposes status codes: 0=ok, 1=invalid_qubits, 2=over_qubit_cap, 3=invalid_cores, 4=over_core_cap. (2) H/CNOT/X/Z gate constants now consume the shared quantum_gates rod. Cross-rod callers can use qgate_kind_* plus diff_gate_from_kind/diff_gate_kind_supported/diff_gate_kind so RZ routes to diff_sim native 6 while RX cleanly reports unsupported instead of reusing the MPS native ID. (3) Noise is learnable parameterized depolarizing; no independent per-gate channel API.";
}

// === Ergonomic f64 wrappers (v0.4.267) ===
//
// Closes the f64-arc started in v0.4.260. Three wrappers for
// the diff_sim fns whose i64 carries an f64 bit pattern (gate
// angle, gradient loss, selective-backward threshold).
// Pointer args (vec, prior_vec, grad_input_vec) stay as i64 —
// they're memory addresses to caller-allocated double[]
// buffers. Other handle-typed bits-i64 returns (sv, probs,
// logits, gate_importance, export_prior) are themselves
// pointer-handles to vec values, not f64 scalars.
//
// `mode_bits` in `diff_sim_init` is intentionally i64-encoded —
// it's a packed bitfield (bit 0 = noisy, bit 1 = per-feature
// gradient, bit 2 = state-vector caching), not an f64. No
// wrapper needed.

fn diff_gate_f64(h: i64, gate_type: i64, q0: i64, q1: i64, angle: f64) {
    nuc_diff_gate(h, gate_type, q0, q1, f64_to_bits(angle));
}
fn diff_gate_kind(h: i64, kind: i64, q0: i64, q1: i64, angle: f64) -> i64 {
    let native: i64 = diff_gate_from_kind(kind);
    if native == qgate_unsupported() { return 0; };
    nuc_diff_gate(h, native, q0, q1, f64_to_bits(angle));
    return 1;
}
fn diff_backward_f64(h: i64, grad_loss: f64) {
    nuc_diff_backward(h, f64_to_bits(grad_loss));
}
fn diff_backward_selective_f64(h: i64, grad_loss: f64, threshold: f64) {
    nuc_diff_backward_selective(h, f64_to_bits(grad_loss), f64_to_bits(threshold));
}
