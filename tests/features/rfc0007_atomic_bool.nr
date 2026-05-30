// stdlib/rods/atomic — AtomicBool ordered ops.
//
// v0.4.281 closes wrong-error finding filed by probe
// 2026-05-01: AtomicBool shipped in v0.4.273 with only the
// constructor + drop helpers. Adopters constructing AtomicBool
// got clang-link "undefined function `atomic_load_bool`" /
// "atomic_store_bool". This fixture exercises the new
// load/store/CAS surface via the AtomicI64 handle delegation.
//
// EXPECT: build success, runtime exit 0, output "OK rfc0007_atomic_bool".

import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let b: AtomicBool = atomic_bool(false);

    // Initial load reads false.
    let v0: bool = atomic_load_bool(&b, MemOrder::SeqCst);
    if v0 { print("FAIL initial false"); return 1; };

    // Store true, load reads true.
    atomic_store_bool(&b, true, MemOrder::SeqCst);
    let v1: bool = atomic_load_bool(&b, MemOrder::SeqCst);
    if !v1 { print("FAIL after store true"); return 1; };

    // Store false (Release/Acquire ordering pair).
    atomic_store_bool(&b, false, MemOrder::Release);
    let v2: bool = atomic_load_bool(&b, MemOrder::Acquire);
    if v2 { print("FAIL after store false"); return 1; };

    // CAS: false → true succeeds.
    let r1: Result<bool, bool> = atomic_compare_exchange_bool(&b, false, true, MemOrder::SeqCst, MemOrder::Relaxed);
    match r1 {
        Ok(prev) => if prev { print("FAIL CAS prev should be false"); return 1; },
        Err(_) => { print("FAIL CAS expected Ok"); return 1; },
    };

    // Confirm CAS landed.
    let v3: bool = atomic_load_bool(&b, MemOrder::Acquire);
    if !v3 { print("FAIL after CAS"); return 1; };

    // CAS: false → false should fail (current is true).
    let r2: Result<bool, bool> = atomic_compare_exchange_bool(&b, false, false, MemOrder::SeqCst, MemOrder::Relaxed);
    match r2 {
        Ok(_) => { print("FAIL CAS should have failed"); return 1; },
        Err(prev) => if !prev { print("FAIL CAS Err prev should be true"); return 1; },
    };

    print("OK rfc0007_atomic_bool");
    0
}
