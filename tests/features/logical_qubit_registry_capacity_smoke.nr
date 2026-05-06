// v0830 QM-14 - logical-qubit registry capacity/status smoke.
//
// Locks the public registry cap helpers, native overflow shape, and partial
// release/reuse behavior. Expected: rc=0.

import "stdlib/rods/logical_qubit.nr"

fn check_initial_capacity() -> i64 {
    logical_qubit_clear();
    if logical_qubit_max_registry() != 256 { return 1; };
    if logical_qubit_registry_slots_remaining() != 256 { return 2; };
    if logical_qubit_can_allocate() != 1 { return 4; };
    if logical_qubit_registry_preflight() != logical_qubit_status_ok() { return 8; };
    return 0;
}

fn check_single_alloc_updates_remaining() -> i64 {
    logical_qubit_clear();
    let lq: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
    if logical_qubit_handle(lq) != 0 { return 16; };
    if logical_qubit_count() != 1 { return 32; };
    if logical_qubit_registry_slots_remaining() != 255 { return 64; };
    return 0;
}

fn check_partial_release_reuses_slot() -> i64 {
    logical_qubit_clear();
    let lq0: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
    let lq1: LogicalQubit = logical_qubit_new(qec_code_steane(), 3);
    let h0: i64 = logical_qubit_handle(lq0);
    let h1: i64 = logical_qubit_handle(lq1);
    if h0 != 0 { return 128; };
    if h1 != 1 { return 256; };
    if logical_qubit_count() != 2 { return 512; };
    if logical_qubit_release_handle(h0) != logical_qubit_status_ok() { return 1024; };
    if logical_qubit_count() != 1 { return 2048; };
    if logical_qubit_registry_slots_remaining() != 255 { return 4096; };
    if logical_qubit_release_handle(h0) != logical_qubit_status_invalid_handle() { return 8192; };
    if nuc_lq_code(h0) != 0 { return 16384; };

    let lq2: LogicalQubit = logical_qubit_new(qec_code_shor(), 5);
    let h2: i64 = logical_qubit_handle(lq2);
    if h2 != 0 { return 32768; };
    if logical_qubit_count() != 2 { return 65536; };
    if nuc_lq_code(h2) != qec_code_shor() { return 131072; };
    logical_qubit_clear();
    return 0;
}

fn check_full_registry_overflow() -> i64 {
    logical_qubit_clear();
    let mut i: i64 = 0;
    while i < logical_qubit_max_registry() {
        let lq: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
        if logical_qubit_handle(lq) != i { return 262144; };
        i = i + 1;
    };
    if logical_qubit_count() != logical_qubit_max_registry() { return 524288; };
    if logical_qubit_registry_slots_remaining() != 0 { return 1048576; };
    if logical_qubit_can_allocate() != 0 { return 2097152; };
    if logical_qubit_registry_preflight() != logical_qubit_status_registry_full() { return 4194304; };

    let overflow: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
    if logical_qubit_handle(overflow) != (0 - 1) { return 8388608; };
    if logical_qubit_count() != logical_qubit_max_registry() { return 16777216; };
    if logical_qubit_release_handle(5) != logical_qubit_status_ok() { return 33554432; };
    if logical_qubit_count() != logical_qubit_max_registry() - 1 { return 67108864; };
    if logical_qubit_registry_preflight() != logical_qubit_status_ok() { return 134217728; };
    let reused: LogicalQubit = logical_qubit_new(qec_code_color(), 7);
    if logical_qubit_handle(reused) != 5 { return 268435456; };
    if logical_qubit_count() != logical_qubit_max_registry() { return 536870912; };
    logical_qubit_clear();
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "LOGICAL-QUBIT REGISTRY") < 0 { return 1001; };
    if str_index_of(s, "256") < 0 { return 1002; };
    if str_index_of(s, "logical_qubit_release") < 0 { return 1003; };
    if str_index_of(s, "schedule_validate_no_same_qubit_overlap") < 0 { return 1004; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_capacity();
    fails = fails + check_single_alloc_updates_remaining();
    fails = fails + check_partial_release_reuses_slot();
    fails = fails + check_full_registry_overflow();
    fails = fails + check_limitations();
    return fails;
}
