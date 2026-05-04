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
//   qsim_entangle_register(0, 1);   // CNOT 0 -> 1 entangles q0 + q1
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
