// =====================================================
// rods/clifford — Clifford / stabilizer formalism (quantum error correction)
// =====================================================
// Import: import "stdlib/rods/clifford.nr"
// Provides: efficient simulation of stabilizer states (no exponential
//   memory blowup), Clifford gates (H, S, CNOT, X, Y, Z), measurement,
//   error detection, distance computation, GNN-style state features.
// =====================================================

#cfile "../runtime/clifford_rt.c"

extern fn nuc_cliff_init(n_qubits: i64) -> i64;
extern fn nuc_cliff_init_code(n_qubits: i64) -> i64;
extern fn nuc_cliff_free(h: i64);
extern fn nuc_cliff_clone(h: i64) -> i64;
extern fn nuc_cliff_nq(h: i64) -> i64;
extern fn nuc_cliff_h(h: i64, q: i64);
extern fn nuc_cliff_s(h: i64, q: i64);
extern fn nuc_cliff_cnot(h: i64, ctrl: i64, tgt: i64);
extern fn nuc_cliff_x(h: i64, q: i64);
extern fn nuc_cliff_y(h: i64, q: i64);
extern fn nuc_cliff_z(h: i64, q: i64);
extern fn nuc_cliff_measure(h: i64, q: i64) -> i64;
extern fn nuc_cliff_error_detectable(h: i64, error_vec: Vec<i64>) -> i64;
extern fn nuc_cliff_num_stabilizers(h: i64) -> i64;
extern fn nuc_cliff_distance(h: i64, n_logical: i64) -> i64;
extern fn nuc_cliff_add_stabilizer(h: i64, pauli_vec: Vec<i64>) -> i64;
extern fn nuc_cliff_reset(h: i64);
extern fn nuc_cliff_get_stabilizers(h: i64) -> i64;
extern fn nuc_cliff_state_features(h: i64, n_logical: i64) -> i64;
extern fn nuc_cliff_random_gate(h: i64, gate_type: i64, seed: i64);
extern fn nuc_cliff_count_detectable_errors(h: i64) -> i64;
extern fn nuc_cliff_best_distance_k1(h: i64) -> i64;
extern fn nuc_cliff_weight_enumerator_max_qubits() -> i64;
extern fn nuc_cliff_stabilizer_weight_count(h: i64, weight: i64) -> i64;
extern fn nuc_cliff_logical_weight_count(h: i64, n_logical: i64, weight: i64) -> i64;

fn cliff_init(n_qubits: i64) -> i64 { return nuc_cliff_init(n_qubits); }
fn cliff_init_code(n_qubits: i64) -> i64 { return nuc_cliff_init_code(n_qubits); }
fn cliff_free(h: i64) { nuc_cliff_free(h); }
fn cliff_clone(h: i64) -> i64 { return nuc_cliff_clone(h); }
fn cliff_nq(h: i64) -> i64 { return nuc_cliff_nq(h); }
fn cliff_h(h: i64, q: i64) { nuc_cliff_h(h, q); }
fn cliff_s(h: i64, q: i64) { nuc_cliff_s(h, q); }
fn cliff_cnot(h: i64, ctrl: i64, tgt: i64) { nuc_cliff_cnot(h, ctrl, tgt); }
fn cliff_x(h: i64, q: i64) { nuc_cliff_x(h, q); }
fn cliff_y(h: i64, q: i64) { nuc_cliff_y(h, q); }
fn cliff_z(h: i64, q: i64) { nuc_cliff_z(h, q); }
fn cliff_measure(h: i64, q: i64) -> i64 { return nuc_cliff_measure(h, q); }
fn cliff_distance(h: i64, n_logical: i64) -> i64 { return nuc_cliff_distance(h, n_logical); }
fn cliff_add_stabilizer(h: i64, pauli: Vec<i64>) -> i64 { return nuc_cliff_add_stabilizer(h, pauli); }
fn cliff_reset(h: i64) { nuc_cliff_reset(h); }
fn cliff_num_stabilizers(h: i64) -> i64 { return nuc_cliff_num_stabilizers(h); }
fn cliff_get_stabilizers(h: i64) -> i64 { return nuc_cliff_get_stabilizers(h); }
fn cliff_state_features(h: i64, n_logical: i64) -> i64 { return nuc_cliff_state_features(h, n_logical); }
fn cliff_error_detectable(h: i64, err: Vec<i64>) -> i64 { return nuc_cliff_error_detectable(h, err); }
fn cliff_count_errors(h: i64) -> i64 { return nuc_cliff_count_detectable_errors(h); }
fn cliff_best_d_k1(h: i64) -> i64 { return nuc_cliff_best_distance_k1(h); }
fn cliff_random_gate(h: i64, gate_type: i64, seed: i64) { nuc_cliff_random_gate(h, gate_type, seed); }
fn cliff_weight_enumerator_max_qubits() -> i64 { return nuc_cliff_weight_enumerator_max_qubits(); }
fn cliff_stabilizer_weight_count(h: i64, weight: i64) -> i64 { return nuc_cliff_stabilizer_weight_count(h, weight); }
fn cliff_logical_weight_count(h: i64, n_logical: i64, weight: i64) -> i64 { return nuc_cliff_logical_weight_count(h, n_logical, weight); }

// === R11 Phase 1 (v0.8.312) - clifford rod disclosure (QM-7) ===
//
// Updated 2026-05-06 after QM-7 Surface-17 coverage landed in tests/features.
fn clifford_limitations() -> str {
    return "Clifford-stabilizer rod limitations (QM-7, updated 2026-05-06): (1) OSS verify coverage now includes Bell/GHZ entanglement, gate identities, reset/rebuild round-trip coverage, a [[5,1,3]] stabilizer-distance smoke, a rotated Surface-17 d=3 stabilizer/logical smoke, and bounded stabilizer/logical weight-enumerator helpers for small codes. (2) ERROR-MODEL coverage is still narrow: cliff_error_detectable / cliff_count_errors are checked on known codes, but adopters must validate their own stabilizer construction. (3) NO QASM / OpenQASM2 INTEROP. (4) Published external weight-enumerator parity values are not yet cited in-tree; current coverage is internal exhaustive consistency over explicit stabilizer sets.";
}
