// v0836 C-17 - typed ordered wrappers for AtomicU64 / AtomicI32 / AtomicU32.
//
// This locks the non-i64 width surface so adopters do not need to drop to the
// raw `.handle` field for ordered load/store/fetch/swap/CAS operations.

import "stdlib/rods/atomic.nr"

fn check_u64() -> i64 {
    let a: AtomicU64 = atomic_u64(10);
    if atomic_load_u64(&a, MemOrder::SeqCst) != 10 { return 1; };
    atomic_store_u64(&a, 20, MemOrder::Release);
    if atomic_load_u64(&a, MemOrder::Acquire) != 20 { return 2; };
    if atomic_fetch_add_u64(&a, 5, MemOrder::SeqCst) != 20 { return 3; };
    if atomic_fetch_sub_u64(&a, 3, MemOrder::SeqCst) != 25 { return 4; };
    if atomic_fetch_and_u64(&a, 15, MemOrder::SeqCst) != 22 { return 5; };
    if atomic_fetch_or_u64(&a, 32, MemOrder::SeqCst) != 6 { return 6; };
    if atomic_fetch_xor_u64(&a, 3, MemOrder::SeqCst) != 38 { return 7; };
    if atomic_swap_u64(&a, 99, MemOrder::SeqCst) != 37 { return 8; };
    let r1: Result<u64, u64> = atomic_compare_exchange_u64(&a, 99, 101, MemOrder::SeqCst, MemOrder::Relaxed);
    match r1 {
        Ok(prev) => { if prev != 99 { return 9; }; },
        Err(_) => return 10,
    };
    let r2: Result<u64, u64> = atomic_compare_exchange_u64(&a, 99, 1, MemOrder::SeqCst, MemOrder::Acquire);
    match r2 {
        Ok(_) => return 11,
        Err(prev) => { if prev != 101 { return 12; }; },
    };
    atomic_u64_drop(a);
    return 0;
}

fn check_i32() -> i64 {
    let a: AtomicI32 = atomic_i32(7);
    if atomic_load_i32(&a, MemOrder::SeqCst) != 7 { return 16; };
    atomic_store_i32(&a, -4, MemOrder::SeqCst);
    if atomic_load_i32(&a, MemOrder::SeqCst) != -4 { return 17; };
    if atomic_fetch_add_i32(&a, 10, MemOrder::SeqCst) != -4 { return 18; };
    if atomic_fetch_sub_i32(&a, 2, MemOrder::SeqCst) != 6 { return 19; };
    if atomic_fetch_or_i32(&a, 8, MemOrder::SeqCst) != 4 { return 20; };
    if atomic_fetch_xor_i32(&a, 1, MemOrder::SeqCst) != 12 { return 21; };
    if atomic_fetch_and_i32(&a, 7, MemOrder::SeqCst) != 13 { return 22; };
    if atomic_swap_i32(&a, 33, MemOrder::SeqCst) != 5 { return 23; };
    let r: Result<i32, i32> = atomic_compare_exchange_i32(&a, 33, 44, MemOrder::SeqCst, MemOrder::Relaxed);
    match r {
        Ok(prev) => { if prev != 33 { return 24; }; },
        Err(_) => return 25,
    };
    atomic_i32_drop(a);
    return 0;
}

fn check_u32() -> i64 {
    let a: AtomicU32 = atomic_u32(3);
    if atomic_load_u32(&a, MemOrder::SeqCst) != 3 { return 32; };
    atomic_store_u32(&a, 12, MemOrder::SeqCst);
    if atomic_fetch_add_u32(&a, 4, MemOrder::SeqCst) != 12 { return 33; };
    if atomic_fetch_sub_u32(&a, 1, MemOrder::SeqCst) != 16 { return 34; };
    if atomic_fetch_or_u32(&a, 8, MemOrder::SeqCst) != 15 { return 35; };
    if atomic_fetch_xor_u32(&a, 2, MemOrder::SeqCst) != 15 { return 36; };
    if atomic_fetch_and_u32(&a, 7, MemOrder::SeqCst) != 13 { return 37; };
    if atomic_swap_u32(&a, 21, MemOrder::SeqCst) != 5 { return 38; };
    let r: Result<u32, u32> = atomic_compare_exchange_u32(&a, 21, 22, MemOrder::SeqCst, MemOrder::Relaxed);
    match r {
        Ok(prev) => { if prev != 21 { return 39; }; },
        Err(_) => return 40,
    };
    atomic_u32_drop(a);
    return 0;
}

fn main() -> i32 {
    let mut fails: i64 = 0;
    fails = fails + check_u64();
    fails = fails + check_i32();
    fails = fails + check_u32();
    if fails != 0 { return fails as i32; };
    print("OK rfc0007_atomic_width_wrappers");
    return 0;
}
