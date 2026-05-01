// RFC-0007 Track G: typed AtomicI64 operations and LLVM atomic lowering.
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let mut fail: i64 = 0;
    let a: AtomicI64 = atomic_i64(1);

    if atomic_load(&a, MemOrder::SeqCst) != 1 { fail = fail + 1; print("FAIL atomic load initial\n"); };
    atomic_store(&a, 10, MemOrder::SeqCst);
    if atomic_load(&a, MemOrder::SeqCst) != 10 { fail = fail + 1; print("FAIL atomic store\n"); };

    let cx1: Result<i64, i64> = atomic_compare_exchange(&a, 10, 12, MemOrder::SeqCst, MemOrder::SeqCst);
    match cx1 {
        Ok(prev) => { if prev != 10 { fail = fail + 1; print("FAIL compare_exchange success payload\n"); }; },
        Err(prev) => { fail = fail + 1; print("FAIL compare_exchange expected success\n"); },
    };
    if atomic_load(&a, MemOrder::SeqCst) != 12 { fail = fail + 1; print("FAIL compare_exchange store\n"); };

    if atomic_fetch_add(&a, 5, MemOrder::SeqCst) != 12 { fail = fail + 1; print("FAIL fetch_add prior\n"); };
    if atomic_fetch_sub(&a, 2, MemOrder::SeqCst) != 17 { fail = fail + 1; print("FAIL fetch_sub prior\n"); };
    if atomic_fetch_and(&a, 6, MemOrder::SeqCst) != 15 { fail = fail + 1; print("FAIL fetch_and prior\n"); };
    if atomic_fetch_or(&a, 8, MemOrder::SeqCst) != 6 { fail = fail + 1; print("FAIL fetch_or prior\n"); };
    if atomic_fetch_xor(&a, 3, MemOrder::SeqCst) != 14 { fail = fail + 1; print("FAIL fetch_xor prior\n"); };
    if atomic_load(&a, MemOrder::SeqCst) != 13 { fail = fail + 1; print("FAIL final value\n"); };

    let cx2: Result<i64, i64> = atomic_compare_exchange(&a, 99, 0, MemOrder::SeqCst, MemOrder::Acquire);
    match cx2 {
        Ok(prev) => { fail = fail + 1; print("FAIL compare_exchange expected failure\n"); },
        Err(prev) => { if prev != 13 { fail = fail + 1; print("FAIL compare_exchange failure payload\n"); }; },
    };

    atomic_i64_drop(a);
    if fail != 0 { return 1; };
    print("OK rfc0007_atomic_basic\n");
    return 0;
}
