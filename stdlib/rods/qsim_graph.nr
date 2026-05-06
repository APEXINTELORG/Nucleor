// rods/qsim_graph — RFC-0061 Tier 3 Phase A: quantum
// entanglement-tracker + gate-influence DAG surface.
//
// The full RFC-0061 Tier 3 ship wires the existing
// `rods_trace_entangle` hook (called from CNOT/CZ/CRK/CCX in
// quantum.nr) to a real-time union-find tracker + a gate-
// influence DAG from the trace stream (~100-150 LOC C wrapper
// + ~30 LOC stdlib). Phase A (this rod + runtime) lands the
// canonical surface adopters can call independently of the
// quantum rod's tracing path: register entanglements directly,
// query components, log gate dependencies as a DAG.
//
// Sister to RFC-0061 Tier 1 (V1.17a CLOSED v0.7.86) and
// Tier 2 (Phase A v0.7.94).
//
// Workflow today:
//
//   import "stdlib/rods/qsim_graph.nr"
//
//   qsim_entangle_register(0, 1);   // Manual graph registration remains available
//   qsim_entangle_register(1, 2);
//   let n: i64 = qsim_entanglement_count();          // 1 component
//   let sz: i64 = qsim_entanglement_size(0);          // 3 qubits
//   let same: i64 = qsim_entanglement_same(0, 2);     // 1 (yes)
//
//   // Gate-influence DAG: each gate gets an id, depends on
//   // the gates that last touched its operand qubits.
//   let g0: i64 = qsim_gate_record("H", 0, 0 - 1);
//   let g1: i64 = qsim_gate_record("CNOT", 0, 1);
//   let n_dag: i64 = qsim_gate_dag_size();
//   let dep: i64 = qsim_gate_dag_depends_on(g1, g0);   // 1

#cfile "../runtime/qsim_graph_rt.c"

extern fn nuc_qsim_entangle_register(q1: i64, q2: i64) -> i64;
extern fn nuc_qsim_entangle_root(q: i64) -> i64;
extern fn nuc_qsim_entangle_same(q1: i64, q2: i64) -> i64;
extern fn nuc_qsim_entangle_size(q: i64) -> i64;
extern fn nuc_qsim_entangle_count() -> i64;
extern fn nuc_qsim_entangle_clear() -> i64;

extern fn nuc_qsim_gate_record(name: str, q1: i64, q2: i64) -> i64;
extern fn nuc_qsim_gate_count() -> i64;
extern fn nuc_qsim_gate_dag_depends_on(child: i64, parent: i64) -> i64;
extern fn nuc_qsim_gate_dag_parent_count(gate_id: i64) -> i64;
extern fn nuc_qsim_gate_dag_parent_at(gate_id: i64, idx: i64) -> i64;
extern fn nuc_qsim_gate_clear() -> i64;

// =====================================================
// Entanglement tracker (union-find) surface.
// =====================================================
fn qsim_entangle_register(q1: i64, q2: i64) -> i64 {
    return nuc_qsim_entangle_register(q1, q2);
}

fn qsim_entanglement_root(q: i64) -> i64 { return nuc_qsim_entangle_root(q); }

fn qsim_entanglement_same(q1: i64, q2: i64) -> i64 {
    return nuc_qsim_entangle_same(q1, q2);
}

fn qsim_entanglement_size(q: i64) -> i64 { return nuc_qsim_entangle_size(q); }

// Number of distinct entanglement components currently tracked.
fn qsim_entanglement_count() -> i64 { return nuc_qsim_entangle_count(); }

fn qsim_entanglement_clear() -> i64 { return nuc_qsim_entangle_clear(); }

// =====================================================
// Gate-influence DAG surface. Each gate record stores its
// name + operand qubits + parent gate IDs (the most-recent
// gate that touched each operand).
//
// q2 = -1 indicates a 1-qubit gate (no second operand).
// =====================================================
fn qsim_gate_record(name: str, q1: i64, q2: i64) -> i64 {
    return nuc_qsim_gate_record(name, q1, q2);
}

fn qsim_gate_dag_size() -> i64 { return nuc_qsim_gate_count(); }

fn qsim_gate_dag_depends_on(child: i64, parent: i64) -> i64 {
    return nuc_qsim_gate_dag_depends_on(child, parent);
}

fn qsim_gate_dag_parent_count(gate_id: i64) -> i64 {
    return nuc_qsim_gate_dag_parent_count(gate_id);
}

fn qsim_gate_dag_parent_at(gate_id: i64, idx: i64) -> i64 {
    return nuc_qsim_gate_dag_parent_at(gate_id, idx);
}

fn qsim_gate_dag_clear() -> i64 { return nuc_qsim_gate_clear(); }

// Combined reset for both trackers.
fn qsim_graph_clear() -> i64 {
    qsim_entanglement_clear();
    qsim_gate_dag_clear();
    return 0;
}

// === R11-D4 Phase 1 (v0.8.306) — qsim_graph status surface ===
//
// Per audit `BUILD_PLAN_R11_quantum_subsystem.md` §1 R11-D4 (HIGH):
// `qsim_gate_record` and the entanglement registers return `-1` on
// overflow / out-of-range silently. Adopters can't query the cap,
// can't decode WHY a -1 came back, and can't preflight.
//
// Phase 1: cap-query helpers + status decoder + limitations text.
// Phase 2 (audit ship plan) replaces raw `-1` returns with
// structured status codes throughout the runtime.

fn qsim_graph_max_qubits() -> i64 { return 1024; }
fn qsim_graph_max_gates() -> i64  { return 4096; }

fn qsim_graph_qubit_in_range(q: i64) -> i64 {
    if q < 0 { return 0; };
    if q >= qsim_graph_max_qubits() { return 0; };
    return 1;
}

fn qsim_graph_gate_slots_remaining() -> i64 {
    return qsim_graph_max_gates() - qsim_gate_dag_size();
}

fn qsim_graph_status_ok() -> i64 { return 0; }
fn qsim_graph_status_out_of_range() -> i64 { return 1; }
fn qsim_graph_status_dag_full() -> i64 { return 2; }
fn qsim_graph_status_unknown() -> i64 { return 3; }

fn qsim_gate_record_preflight(q1: i64, q2: i64) -> i64 {
    let m: i64 = qsim_graph_max_qubits();
    if q1 < 0 { return qsim_graph_status_out_of_range(); };
    if q1 >= m { return qsim_graph_status_out_of_range(); };
    if q2 < 0 - 1 { return qsim_graph_status_out_of_range(); };
    if q2 >= m { return qsim_graph_status_out_of_range(); };
    if qsim_graph_gate_slots_remaining() <= 0 { return qsim_graph_status_dag_full(); };
    return qsim_graph_status_ok();
}

fn qsim_gate_record_checked(name: str, q1: i64, q2: i64) -> i64 {
    let status: i64 = qsim_gate_record_preflight(q1, q2);
    if status != qsim_graph_status_ok() { return 0 - status; };

    let gate_id: i64 = qsim_gate_record(name, q1, q2);
    if gate_id >= 0 { return gate_id; };
    return 0 - qsim_graph_status_unknown();
}

// Decode a -1 return: "out_of_range" / "dag_full" / "ok"
// (ok = the -1 was for a different reason; check call args).
fn qsim_graph_status_explain(q1: i64, q2: i64) -> str {
    let status: i64 = qsim_gate_record_preflight(q1, q2);
    if status == qsim_graph_status_out_of_range() { return "out_of_range"; };
    if status == qsim_graph_status_dag_full() { return "dag_full"; };
    return "ok";
}

fn qsim_graph_limitations() -> str {
    return "qsim_graph rod limitations (QM-4, audit R11-D4 v0.8.306/v0.8.324/v0.8.325/v0828): (1) HARD CAPS: 1024 qubits, 4096 gate-DAG slots. Beyond either, qsim_entangle_register / raw qsim_gate_record return -1 silently. Prefer qsim_gate_record_checked(name, q1, q2): >=0 real gate id, -1 out_of_range, -2 dag_full, -3 unknown raw failure after preflight passed. Query qsim_graph_max_qubits / qsim_graph_max_gates / qsim_graph_gate_slots_remaining, or call qsim_gate_record_preflight(q1, q2) for status code 0=ok, 1=out_of_range, 2=dag_full BEFORE invoking raw qsim_gate_record. (2) RAW ESCAPE HATCH REMAINS: qsim_gate_record still returns raw gate ids or -1; the checked/preflight status surface helps adopters avoid known -1 causes but does not rewrite the C runtime ABI. (3) PHASE 2A AUTO-ENTANGLE: qsim CNOT/CZ/CRK/CCX in stdlib/rods/quantum.nr now call qsim_entangle_register in the same semantic places their trace hooks declare entanglement; qsim_swap inherits this through its CNOT sequence. Raw gate-DAG auto-recording remains open. (4) PROCESS-LOCAL state: not thread-safe across pthread/async boundaries.";
}
