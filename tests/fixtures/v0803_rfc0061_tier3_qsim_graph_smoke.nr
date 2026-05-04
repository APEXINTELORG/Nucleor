// v0.8.3 RFC-0061 Tier 3 Phase A smoke fixture — quantum
// entanglement union-find + gate-influence DAG. Validates:
//   - register_entangle (q1, q2) groups qubits into one
//     component
//   - chained registers grow the component
//   - count returns distinct components
//   - same / size predicates agree with the union-find
//   - clear resets to empty
//   - gate_record builds a DAG with parent edges from the
//     last gate that touched each operand qubit
//   - depends_on traverses the parent chain transitively
import "stdlib/rods/qsim_graph.nr"

fn main() -> i64 {
    qsim_graph_clear();

    // Two disjoint pairs.
    qsim_entangle_register(0, 1);
    qsim_entangle_register(5, 6);

    if qsim_entanglement_count() != 2 { return 1; };
    if qsim_entanglement_size(0) != 2 { return 2; };
    if qsim_entanglement_size(5) != 2 { return 3; };

    // Same / not-same.
    if qsim_entanglement_same(0, 1) != 1 { return 4; };
    if qsim_entanglement_same(0, 5) != 0 { return 5; };

    // Extend first pair into a triple.
    qsim_entangle_register(1, 2);
    if qsim_entanglement_count() != 2 { return 6; };
    if qsim_entanglement_size(0) != 3 { return 7; };
    if qsim_entanglement_same(0, 2) != 1 { return 8; };

    // Merge the two components via 2 <-> 5.
    qsim_entangle_register(2, 5);
    if qsim_entanglement_count() != 1 { return 9; };
    if qsim_entanglement_size(0) != 5 { return 10; };
    if qsim_entanglement_same(0, 6) != 1 { return 11; };

    // Inactive qubit (never registered) returns size 0.
    if qsim_entanglement_size(99) != 0 { return 12; };
    if qsim_entanglement_same(0, 99) != 0 { return 13; };

    // Clear -> 0.
    qsim_entanglement_clear();
    if qsim_entanglement_count() != 0 { return 14; };

    // Gate-influence DAG.
    qsim_gate_dag_clear();
    let g0: i64 = qsim_gate_record("H", 0, 0 - 1);          // 1-qubit, q1=0
    let g1: i64 = qsim_gate_record("H", 1, 0 - 1);          // 1-qubit, q1=1
    let g2: i64 = qsim_gate_record("CNOT", 0, 1);           // 2-qubit, parents = g0, g1
    let g3: i64 = qsim_gate_record("X", 0, 0 - 1);          // 1-qubit, parent = g2

    if qsim_gate_dag_size() != 4 { return 15; };

    // g2 depends on g0 (q1=0 last-touched by g0).
    if qsim_gate_dag_depends_on(g2, g0) != 1 { return 16; };
    if qsim_gate_dag_depends_on(g2, g1) != 1 { return 17; };

    // g3 depends transitively on g0 (via g2).
    if qsim_gate_dag_depends_on(g3, g0) != 1 { return 18; };
    if qsim_gate_dag_depends_on(g3, g1) != 1 { return 19; };

    // g0 doesn't depend on anything later.
    if qsim_gate_dag_depends_on(g0, g3) != 0 { return 20; };
    if qsim_gate_dag_depends_on(g0, g2) != 0 { return 21; };

    // Parent-count + parent-at.
    if qsim_gate_dag_parent_count(g0) != 0 { return 22; };
    if qsim_gate_dag_parent_count(g2) != 2 { return 23; };
    if qsim_gate_dag_parent_count(g3) != 1 { return 24; };

    let p0: i64 = qsim_gate_dag_parent_at(g3, 0);
    if p0 != g2 { return 25; };

    qsim_graph_clear();
    if qsim_entanglement_count() != 0 { return 26; };
    if qsim_gate_dag_size() != 0 { return 27; };

    return 0;
}
