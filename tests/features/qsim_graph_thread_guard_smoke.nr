// v0836 QM-8/QM-9 - qsim_graph runtime thread guard smoke.
//
// Four OS threads concurrently mutate the process-local qsim_graph state on
// disjoint qubit pairs. The runtime-owned atomic spinlock should preserve exact
// entanglement-component and gate-DAG counts.

import "stdlib/rods/qsim_graph.nr"

fn qsim_graph_guard_worker(base: i64) -> i64 {
    let mut i: i64 = 0;
    while i < 64 {
        let q1: i64 = base * 128 + i * 2;
        let q2: i64 = q1 + 1;
        if qsim_entangle_register(q1, q2) < 0 { return 1; };
        if qsim_gate_record_checked("CNOT", q1, q2) < 0 { return 2; };
        i = i + 1;
    };
    return 0;
}

fn check_parallel_qsim_graph_updates() -> i64 {
    qsim_graph_clear();

    let h0: i64 = thread_spawn(qsim_graph_guard_worker, 0);
    let h1: i64 = thread_spawn(qsim_graph_guard_worker, 1);
    let h2: i64 = thread_spawn(qsim_graph_guard_worker, 2);
    let h3: i64 = thread_spawn(qsim_graph_guard_worker, 3);
    thread_join(h0);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);

    if qsim_entanglement_count() != 256 { return 4; };
    if qsim_gate_dag_size() != 256 { return 8; };
    if qsim_entanglement_same(0, 1) != 1 { return 16; };
    if qsim_entanglement_same(128, 129) != 1 { return 32; };
    if qsim_entanglement_same(256, 257) != 1 { return 64; };
    if qsim_entanglement_same(384, 385) != 1 { return 128; };
    if qsim_entanglement_same(0, 128) != 0 { return 256; };

    qsim_graph_clear();
    if qsim_entanglement_count() != 0 { return 512; };
    if qsim_gate_dag_size() != 0 { return 1024; };
    return 0;
}

fn main() -> i64 {
    if qsim_graph_is_thread_safe() != 1 { return 2048; };
    if qsim_graph_requires_external_lock() != 0 { return 4096; };
    return check_parallel_qsim_graph_updates();
}
