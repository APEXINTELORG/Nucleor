// RFC-0007 Track G: all MemOrder variants lower through the typed API.
import "stdlib/rods/atomic.nr"

fn check_cx(a: &AtomicI64, expected: i64, success: MemOrder, failure: MemOrder) -> i64 {
    let r: Result<i64, i64> = atomic_compare_exchange(a, expected, expected + 1, success, failure);
    match r {
        Ok(prev) => { if prev == expected { return 0; }; return 1; },
        Err(prev) => { return 1; },
    };
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let a: AtomicI64 = atomic_i64(0);

    atomic_store(&a, 1, MemOrder::Relaxed);
    if atomic_load(&a, MemOrder::Relaxed) != 1 { fail = fail + 1; };
    atomic_store(&a, 2, MemOrder::Release);
    if atomic_load(&a, MemOrder::Acquire) != 2 { fail = fail + 1; };
    atomic_store(&a, 3, MemOrder::SeqCst);
    if atomic_load(&a, MemOrder::SeqCst) != 3 { fail = fail + 1; };

    atomic_store(&a, 0, MemOrder::SeqCst);
    if atomic_fetch_add(&a, 1, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if atomic_fetch_add(&a, 1, MemOrder::Acquire) != 1 { fail = fail + 1; };
    if atomic_fetch_add(&a, 1, MemOrder::Release) != 2 { fail = fail + 1; };
    if atomic_fetch_add(&a, 1, MemOrder::AcqRel) != 3 { fail = fail + 1; };
    if atomic_fetch_add(&a, 1, MemOrder::SeqCst) != 4 { fail = fail + 1; };

    if check_cx(&a, 5, MemOrder::Relaxed, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if check_cx(&a, 6, MemOrder::Acquire, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if check_cx(&a, 7, MemOrder::Acquire, MemOrder::Acquire) != 0 { fail = fail + 1; };
    if check_cx(&a, 8, MemOrder::Release, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if check_cx(&a, 9, MemOrder::AcqRel, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if check_cx(&a, 10, MemOrder::AcqRel, MemOrder::Acquire) != 0 { fail = fail + 1; };
    if check_cx(&a, 11, MemOrder::SeqCst, MemOrder::Relaxed) != 0 { fail = fail + 1; };
    if check_cx(&a, 12, MemOrder::SeqCst, MemOrder::Acquire) != 0 { fail = fail + 1; };
    if check_cx(&a, 13, MemOrder::SeqCst, MemOrder::SeqCst) != 0 { fail = fail + 1; };

    atomic_i64_drop(a);
    if fail != 0 { return 1; };
    print("OK rfc0007_atomic_orderings\n");
    return 0;
}
