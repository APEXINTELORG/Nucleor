// =====================================================
// rods/atomic — AtomicI64 (RFC-0007 partial)
// =====================================================
// Import: import "stdlib/rods/atomic.nr"
//
// 64-bit atomic integer with sequentially-consistent memory ordering.
// Backed by Win32 Interlocked* (msvc) or C11 stdatomic (POSIX);
// portable across both.
//
// Use cases:
//   - Lock-free counters across threads
//   - Spinlocks via CAS
//   - Atomic flag toggles in ISRs (RFC-0008)
//
// Relaxed/Acquire/Release ordering variants ship with full RFC-0007
// in v0.5.
// =====================================================

// ---- Lifecycle ----
fn atomic_new(initial: i64) -> i64 { return atomic_i64_new(initial); }
fn atomic_drop(h: i64) -> i64 { return atomic_i64_free(h); }

// ---- Load / Store ----
fn atomic_load_v(h: i64) -> i64 { return atomic_i64_load(h); }
fn atomic_store_v(h: i64, v: i64) -> i64 { return atomic_i64_store(h, v); }

// ---- Read-modify-write (returns prior value) ----
fn atomic_add(h: i64, v: i64) -> i64 { return atomic_i64_fetch_add(h, v); }
fn atomic_sub(h: i64, v: i64) -> i64 { return atomic_i64_fetch_sub(h, v); }
fn atomic_and_v(h: i64, v: i64) -> i64 { return atomic_i64_fetch_and(h, v); }
fn atomic_or_v(h: i64, v: i64) -> i64 { return atomic_i64_fetch_or(h, v); }
fn atomic_xor_v(h: i64, v: i64) -> i64 { return atomic_i64_fetch_xor(h, v); }
fn atomic_swap_v(h: i64, v: i64) -> i64 { return atomic_i64_swap(h, v); }

// ---- Compare-and-swap ----
// Returns previous value. Compare to `expected` to detect success.
fn atomic_cas_raw(h: i64, expected: i64, desired: i64) -> i64 {
    return atomic_i64_cas(h, expected, desired);
}
// Returns 1 on success, 0 on fail (mismatch). Convenient for spin loops.
fn atomic_cas_ok(h: i64, expected: i64, desired: i64) -> i64 {
    if atomic_i64_cas(h, expected, desired) == expected { return 1; };
    return 0;
}

// ---- Convenience: atomic counter ----
fn atomic_inc(h: i64) -> i64 { return atomic_i64_fetch_add(h, 1); }
fn atomic_dec(h: i64) -> i64 { return atomic_i64_fetch_sub(h, 1); }
