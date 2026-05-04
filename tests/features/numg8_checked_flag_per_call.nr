// v0.8.82 NUM-G8 Phase 1 — checked_* flag per-call lock.
// Validates that the (now thread-local) overflow flag is
// reset on every checked_* entry. Single-thread sequence
// proves the per-call clear; the thread-local hoist (made
// the flag per-thread instead of a shared static int) is
// validated by inspection of nucleor_llvm_rt.c since
// Nucleor's threading surface is still maturing.
//
// Pre-fix: shared static int meant concurrent calls from
// different threads would race on the flag, and the flag
// could be overwritten between a thread's call and its
// `checked_overflow_flag()` read. Post-fix: NUCLEOR_TLS
// per-thread storage. Each thread sees its own flag.
//
// Expected: rc=0 (four sequence assertions pass).

fn main() -> i64 {
    let mut fails: i64 = 0;

    // Step 1: overflow → flag = 1
    let _ = checked_add(9223372036854775000, 9223372036854775000);
    if checked_overflow_flag() != 1 { fails = fails + 10; };

    // Step 2: clean op → flag must clear back to 0
    let _ = checked_add(1, 2);
    if checked_overflow_flag() != 0 { fails = fails + 100; };

    // Step 3: overflow on sub → flag = 1
    let _ = checked_sub(-9223372036854775000, 9223372036854775000);
    if checked_overflow_flag() != 1 { fails = fails + 1000; };

    // Step 4: clean mul → flag clears
    let _ = checked_mul(2, 3);
    if checked_overflow_flag() != 0 { fails = fails + 10000; };

    return fails;
}
