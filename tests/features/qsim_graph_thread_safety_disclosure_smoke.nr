// v0835 QM-8/QM-9 - qsim_graph thread-safety disclosure.
//
// Locks the current contract: qsim_graph state is process-local static
// runtime state, not synchronized across pthread/async callers.

import "stdlib/rods/qsim_graph.nr"

fn check_thread_safety_flags() -> i64 {
    if qsim_graph_is_thread_safe() != 0 { return 1; };
    if qsim_graph_requires_external_lock() != 1 { return 2; };
    return 0;
}

fn check_required_primitive_text() -> i64 {
    let s: str = qsim_graph_thread_safety_required_primitive();
    if str_index_of(s, "runtime-owned qsim_graph mutex") < 0 { return 4; };
    if str_index_of(s, "per-graph handle state") < 0 { return 8; };
    if str_index_of(s, "not synchronized") < 0 { return 16; };
    return 0;
}

fn check_limitations_text() -> i64 {
    let s: str = qsim_graph_limitations();
    if str_index_of(s, "THREAD SAFETY") < 0 { return 32; };
    if str_index_of(s, "qsim_graph_is_thread_safe") < 0 { return 64; };
    if str_index_of(s, "pthread/async callers must serialize access") < 0 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_thread_safety_flags();
    fails = fails + check_required_primitive_text();
    fails = fails + check_limitations_text();
    return fails;
}
