// v0830 QM-14 - logical-qubit registry capacity/status smoke.
//
// Locks the public registry cap helpers and the native overflow shape without
// adding a partial-release API. Expected: rc=0.

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

fn check_full_registry_overflow() -> i64 {
    logical_qubit_clear();
    let mut i: i64 = 0;
    while i < logical_qubit_max_registry() {
        let lq: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
        if logical_qubit_handle(lq) != i { return 128; };
        i = i + 1;
    };
    if logical_qubit_count() != logical_qubit_max_registry() { return 256; };
    if logical_qubit_registry_slots_remaining() != 0 { return 512; };
    if logical_qubit_can_allocate() != 0 { return 1024; };
    if logical_qubit_registry_preflight() != logical_qubit_status_registry_full() { return 2048; };

    let overflow: LogicalQubit = logical_qubit_new(qec_code_surface(), 3);
    if logical_qubit_handle(overflow) != (0 - 1) { return 4096; };
    if logical_qubit_count() != logical_qubit_max_registry() { return 8192; };
    logical_qubit_clear();
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = logical_qubit_limitations();
    if str_index_of(s, "LOGICAL-QUBIT REGISTRY") < 0 { return 16384; };
    if str_index_of(s, "256") < 0 { return 32768; };
    if str_index_of(s, "schedule_validate_no_same_qubit_overlap") < 0 { return 65536; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_initial_capacity();
    fails = fails + check_single_alloc_updates_remaining();
    fails = fails + check_full_registry_overflow();
    fails = fails + check_limitations();
    return fails;
}
