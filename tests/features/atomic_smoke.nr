// v0.8.135 stdlib/rods/atomic.nr first test coverage.
//
// RFC-0007 atomics — load/store/RMW/CAS. Foundational for
// concurrent code. Pre-v0.8.135: zero coverage on the legacy
// handle API and the typed AtomicI64 surface.
//
// Locks five invariants:
//   1. atomic_new(42) -> load reads 42 (constructor + load round-trip).
//   2. atomic_store(7) -> load reads 7 (store round-trip).
//   3. atomic_inc/dec returns prior, leaves cell incremented (RMW
//      semantics — what every concurrent counter relies on).
//   4. atomic_cas_ok succeeds on match, leaves desired in cell;
//      fails on mismatch, leaves cell unchanged.
//   5. atomic_swap returns prior, leaves new value (xchg).
//
// Single-threaded but exercises the full atomicrmw / cmpxchg
// lowering path — locks the contract. Race-condition tests are
// out of scope for a smoke fixture.
//
// Expected: rc=0.

import "stdlib/rods/atomic.nr"

fn check_load_store() -> i64 {
    let a: i64 = atomic_new(42);
    if atomic_load_v(a) != 42 { atomic_drop(a); return 1; };
    atomic_store_v(a, 7);
    if atomic_load_v(a) != 7 { atomic_drop(a); return 2; };
    atomic_drop(a);
    return 0;
}

fn check_inc_dec() -> i64 {
    let a: i64 = atomic_new(10);
    let prev1: i64 = atomic_inc(a);
    if prev1 != 10 { atomic_drop(a); return 4; };
    if atomic_load_v(a) != 11 { atomic_drop(a); return 8; };
    let prev2: i64 = atomic_dec(a);
    if prev2 != 11 { atomic_drop(a); return 16; };
    if atomic_load_v(a) != 10 { atomic_drop(a); return 32; };
    atomic_drop(a);
    return 0;
}

fn check_fetch_add() -> i64 {
    let a: i64 = atomic_new(100);
    let prev: i64 = atomic_add(a, 50);
    if prev != 100 { atomic_drop(a); return 64; };
    if atomic_load_v(a) != 150 { atomic_drop(a); return 128; };
    let prev2: i64 = atomic_sub(a, 30);
    if prev2 != 150 { atomic_drop(a); return 256; };
    if atomic_load_v(a) != 120 { atomic_drop(a); return 512; };
    atomic_drop(a);
    return 0;
}

fn check_cas() -> i64 {
    let a: i64 = atomic_new(5);
    // Successful CAS: expected matches, desired wins.
    if atomic_cas_ok(a, 5, 99) != 1 { atomic_drop(a); return 1024; };
    if atomic_load_v(a) != 99 { atomic_drop(a); return 2048; };
    // Failed CAS: expected mismatch, cell unchanged.
    if atomic_cas_ok(a, 5, 7) != 0 { atomic_drop(a); return 4096; };
    if atomic_load_v(a) != 99 { atomic_drop(a); return 8192; };
    atomic_drop(a);
    return 0;
}

fn check_swap() -> i64 {
    let a: i64 = atomic_new(1000);
    let prev: i64 = atomic_swap_v(a, 2000);
    if prev != 1000 { atomic_drop(a); return 16384; };
    if atomic_load_v(a) != 2000 { atomic_drop(a); return 32768; };
    atomic_drop(a);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_load_store();
    fails = fails + check_inc_dec();
    fails = fails + check_fetch_add();
    fails = fails + check_cas();
    fails = fails + check_swap();
    return fails;
}
