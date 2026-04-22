// atomic_bit_ops.nr — RFC-0007 partial AtomicI64 + bit-twiddling
// Single-threaded test verifies semantics; cross-thread races
// validated under #[atomic] when v0.5 ships.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // AtomicI64: load / store
    let a: i64 = atomic_i64_new(42);
    if atomic_i64_load(a) != 42 { fail = fail + 1; print("FAIL atomic load init\n"); };

    atomic_i64_store(a, 100);
    if atomic_i64_load(a) != 100 { fail = fail + 1; print("FAIL atomic store-load\n"); };

    // fetch_add returns prior value
    let prev: i64 = atomic_i64_fetch_add(a, 50);
    if prev != 100 { fail = fail + 1; print("FAIL fetch_add prior\n"); };
    if atomic_i64_load(a) != 150 { fail = fail + 1; print("FAIL fetch_add result\n"); };

    // fetch_sub
    let prev2: i64 = atomic_i64_fetch_sub(a, 50);
    if prev2 != 150 { fail = fail + 1; print("FAIL fetch_sub prior\n"); };
    if atomic_i64_load(a) != 100 { fail = fail + 1; print("FAIL fetch_sub result\n"); };

    // CAS success
    let was: i64 = atomic_i64_cas(a, 100, 200);
    if was != 100 { fail = fail + 1; print("FAIL cas-success returns prev\n"); };
    if atomic_i64_load(a) != 200 { fail = fail + 1; print("FAIL cas-success new value\n"); };

    // CAS failure (expected mismatch — value unchanged)
    let was2: i64 = atomic_i64_cas(a, 99, 0);
    if was2 != 200 { fail = fail + 1; print("FAIL cas-fail returns current\n"); };
    if atomic_i64_load(a) != 200 { fail = fail + 1; print("FAIL cas-fail kept value\n"); };

    // swap
    let old: i64 = atomic_i64_swap(a, 7);
    if old != 200 { fail = fail + 1; print("FAIL swap prior\n"); };
    if atomic_i64_load(a) != 7 { fail = fail + 1; print("FAIL swap new\n"); };

    // bitwise atomics
    atomic_i64_store(a, 0xFF00);
    atomic_i64_fetch_or(a, 0x000F);
    if atomic_i64_load(a) != 0xFF0F { fail = fail + 1; print("FAIL atomic or\n"); };

    atomic_i64_fetch_and(a, 0x0F0F);
    if atomic_i64_load(a) != 0x0F0F { fail = fail + 1; print("FAIL atomic and\n"); };

    atomic_i64_fetch_xor(a, 0xFFFF);
    if atomic_i64_load(a) != 0xF0F0 { fail = fail + 1; print("FAIL atomic xor\n"); };

    atomic_i64_free(a);

    // === Bit-twiddling ===
    if popcount(0) != 0 { fail = fail + 1; print("FAIL popcount 0\n"); };
    if popcount(0xFF) != 8 { fail = fail + 1; print("FAIL popcount 0xFF\n"); };
    if popcount(0xFFFFFFFFFFFFFFFF) != 64 { fail = fail + 1; print("FAIL popcount all\n"); };

    if leading_zeros(0) != 64 { fail = fail + 1; print("FAIL lz 0\n"); };
    if leading_zeros(1) != 63 { fail = fail + 1; print("FAIL lz 1\n"); };
    if leading_zeros(0xFF) != 56 { fail = fail + 1; print("FAIL lz 0xFF\n"); };

    if trailing_zeros(0) != 64 { fail = fail + 1; print("FAIL tz 0\n"); };
    if trailing_zeros(1) != 0 { fail = fail + 1; print("FAIL tz 1\n"); };
    if trailing_zeros(8) != 3 { fail = fail + 1; print("FAIL tz 8\n"); };

    if byte_swap(0xCAFEBABE) != 0xBEBAFECA00000000 { fail = fail + 1; print("FAIL bswap\n"); };

    if rotate_left(1, 4) != 16 { fail = fail + 1; print("FAIL rotl 1<<4\n"); };
    if rotate_right(16, 4) != 1 { fail = fail + 1; print("FAIL rotr 16>>4\n"); };

    if fail == 0 { print("OK atomic_bit_ops\n"); return 0; };
    return 1;
}
