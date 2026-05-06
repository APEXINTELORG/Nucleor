// rods/mps — Matrix Product States (efficient quantum simulation)
import "quantum_gates.nr"
#cfile "../runtime/mps_rt.c"

extern fn nuc_mps_init(nq: i64, max_bond: i64) -> i64;
extern fn nuc_mps_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle: i64);
extern fn nuc_mps_extract(h: i64) -> i64;
extern fn nuc_mps_free(h: i64);
extern fn nuc_mps_max_bond(h: i64) -> i64;
extern fn nuc_mps_expect_z(h: i64, q: i64) -> i64;
extern fn nuc_mps_prob0(h: i64, q: i64) -> i64;
extern fn nuc_mps_prob_basis(h: i64, basis_bits: i64) -> i64;

fn mps_init(nq: i64, max_bond: i64) -> i64 { return nuc_mps_init(nq, max_bond); }
fn mps_gate(h: i64, gate_type: i64, q0: i64, q1: i64, angle: i64) { nuc_mps_gate(h, gate_type, q0, q1, angle); }
fn mps_extract(h: i64) -> i64 { return nuc_mps_extract(h); }
fn mps_free(h: i64) { nuc_mps_free(h); }
fn mps_max_bond(h: i64) -> i64 { return nuc_mps_max_bond(h); }
fn mps_expect_z(h: i64, q: i64) -> i64 { return nuc_mps_expect_z(h, q); }
fn mps_prob0(h: i64, q: i64) -> i64 { return nuc_mps_prob0(h, q); }
fn mps_prob_basis(h: i64, basis_bits: i64) -> i64 { return nuc_mps_prob_basis(h, basis_bits); }

// === R11-D2 Phase 1 (v0.8.305) — named gate wrappers ===
//
// Per audit `BUILD_PLAN_R11_quantum_subsystem.md` §1 R11-D2 (HIGH):
// pre-v0.8.305 adopters had to call `mps_gate(h, 0, q, 0, 0)` with
// raw gate-type integers (0=H, 1=CNOT, 2=X, 3=Z, 4=RZ, 5=RX) —
// error-prone and undocumented. Phase 1 ships named wrappers
// preserving the raw escape hatch. Phase 2 lifts the gate-type
// to a typed enum.

// === MPS gate type constants (matches mps_rt.c dispatch) ===
fn mps_gate_h() -> i64    { return qgate_h(); }
fn mps_gate_cnot() -> i64 { return qgate_cnot(); }
fn mps_gate_x() -> i64    { return qgate_x(); }
fn mps_gate_z() -> i64    { return qgate_z(); }
fn mps_gate_rz() -> i64   { return qgate_mps_rz(); }
fn mps_gate_rx() -> i64   { return qgate_mps_rx(); }

// Returns 1 if `code` is a known/shipped gate-type integer.
// Phase 2 will add Y, S, T, RY, CZ, SWAP — querying this surface
// before invoking lets adopters fail fast on an unsupported code.
fn mps_gate_type_supported(code: i64) -> i64 {
    if code == 0 { return 1; };
    if code == 1 { return 1; };
    if code == 2 { return 1; };
    if code == 3 { return 1; };
    if code == 4 { return 1; };
    if code == 5 { return 1; };
    return 0;
}

// === Named 1q gate wrappers ===
fn mps_h(h: i64, q: i64)  { nuc_mps_gate(h, qgate_h(), q, 0, 0); }
fn mps_x(h: i64, q: i64)  { nuc_mps_gate(h, qgate_x(), q, 0, 0); }
fn mps_z(h: i64, q: i64)  { nuc_mps_gate(h, qgate_z(), q, 0, 0); }
fn mps_rz(h: i64, q: i64, angle_bits: i64) { nuc_mps_gate(h, qgate_mps_rz(), q, 0, angle_bits); }
fn mps_rx(h: i64, q: i64, angle_bits: i64) { nuc_mps_gate(h, qgate_mps_rx(), q, 0, angle_bits); }

// === Named 2q gate wrappers ===
fn mps_cnot(h: i64, ctrl: i64, tgt: i64) { nuc_mps_gate(h, qgate_cnot(), ctrl, tgt, 0); }

fn mps_limitations() -> str {
    return "MPS rod limitations (QM-2/QM-3/QM-6/QM-12, audit R11-D2/D3 v0.8.305/v0831): (1) GATE COVERAGE: only H, X, Z, RZ, RX, CNOT shipped. H/CNOT/X/Z now consume the shared quantum_gates constants; MPS-specific rotations remain RZ=4/RX=5 until native dispatch tables unify with diff_sim. Y, S, T, RY, CZ, SWAP, Toffoli, controlled-rotation are NOT in mps_rt.c's dispatch — adopter must fall back to qsim or compose from existing primitives. Query mps_gate_type_supported(code) for per-code truth. (2) PROBABILITY READOUT: mps_prob0(h, q) exposes single-qubit P(q=0), and mps_prob_basis(h, basis_bits) exposes full computational-basis joint-probability by contracting selected MPS tensor slices; bulk statevector extraction is still absent. (3) NO TYPED ENUM yet — gate_type is a raw i64; v0.8.305 ships named wrappers (mps_h, mps_x, mps_cnot, etc.) preserving the raw escape hatch. (4) NO BOND-DIMENSION DIAGNOSTIC: mps_max_bond returns the cap but adopters can't query the CURRENT bond dim mid-circuit; truncation error is silent (Phase 2 ships mps_current_bond + mps_truncation_error). (5) NON-ADJACENT CNOT uses SWAP decomposition (visible in mps_rt.c:386-419) which inflates bond dim — caveat for noise-sensitive applications. Phase 2 wires the missing gates + typed enum + bond-dim diagnostics per audit ship plan.";
}
