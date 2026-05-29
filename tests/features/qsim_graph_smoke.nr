// v0.8.224 stdlib/rods/qsim_graph.nr first test coverage.
//
// RFC-0061 Tier 3 Phase A: quantum entanglement-tracker
// (union-find) + gate-influence DAG surface. Pre-v0.8.224:
// zero coverage on the standalone rod (sister to Tier 1
// CLOSED v0.7.86 + Tier 2 Phase A v0.7.94).
//
// Locks four invariants:
//
//   1. Union-find merges via transitive close —
//      register (0,1) and (1,2) → all three same component.
//   2. Component size and count — after merging q0/q1/q2:
//      size=3, count=1.
//   3. Distinct components don't merge — register (0,1)
//      and (5,6) → q0 and q5 are in different components,
//      count=2.
//   4. Gate DAG depends_on after re-touching qubit —
//      record H on q0 (g0), then CNOT 0→1 (g1) → g1 depends
//      on g0 (g0 last touched q0).
//
// Expected: rc=0.

import "stdlib/rods/qsim_graph.nr"

fn check_transitive_merge() -> i64 {
    qsim_graph_clear();
    qsim_entangle_register(0, 1);
    qsim_entangle_register(1, 2);
    if qsim_entanglement_same(0, 2) != 1 { return 1; };
    if qsim_entanglement_same(0, 1) != 1 { return 2; };
    return 0;
}

fn check_component_size_count() -> i64 {
    qsim_graph_clear();
    qsim_entangle_register(0, 1);
    qsim_entangle_register(1, 2);
    if qsim_entanglement_size(0) != 3 { return 4; };
    if qsim_entanglement_count() != 1 { return 8; };
    return 0;
}

fn check_distinct_components() -> i64 {
    qsim_graph_clear();
    qsim_entangle_register(0, 1);
    qsim_entangle_register(5, 6);
    if qsim_entanglement_same(0, 5) != 0 { return 16; };
    if qsim_entanglement_count() != 2 { return 32; };
    return 0;
}

fn check_gate_dag_depends_on() -> i64 {
    qsim_graph_clear();
    let g0: i64 = qsim_gate_record("H", 0, 0 - 1);
    let g1: i64 = qsim_gate_record("CNOT", 0, 1);
    if qsim_gate_dag_depends_on(g1, g0) != 1 { return 64; };
    if qsim_gate_dag_size() != 2 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_transitive_merge();
    fails = fails + check_component_size_count();
    fails = fails + check_distinct_components();
    fails = fails + check_gate_dag_depends_on();
    return fails;
}
