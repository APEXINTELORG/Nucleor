// =====================================================
// rods/atomic - RFC-0007 atomics
// =====================================================
// Import: import "stdlib/rods/atomic.nr"
//
// The legacy handle API below remains for compatibility. The typed
// AtomicI64 + MemOrder surface is the RFC-0007 public API; ordered ops
// lower directly to LLVM load/store/cmpxchg/atomicrmw instructions.
// =====================================================

struct AtomicI64 { handle: i64 }
struct AtomicU64 { handle: i64 }
struct AtomicI32 { handle: i64 }
struct AtomicU32 { handle: i64 }
struct AtomicBool { handle: i64 }

enum MemOrder {
    Relaxed,
    Acquire,
    Release,
    AcqRel,
    SeqCst,
}

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

// ---- RFC-0007 typed AtomicI64 surface ----
fn atomic_i64(initial: i64) -> AtomicI64 {
    return AtomicI64 { handle: atomic_i64_new(initial) };
}

fn atomic_i64_drop(a: AtomicI64) -> i64 {
    return atomic_i64_free(a.handle);
}

fn atomic_load(a: &AtomicI64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_load_relaxed(a.handle); };
    if order == MemOrder::Acquire { return atomic_i64_load_acquire(a.handle); };
    if order == MemOrder::SeqCst { return atomic_i64_load_seqcst(a.handle); };
    return atomic_i64_load_seqcst(a.handle);
}

fn atomic_store(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_store_relaxed(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_store_release(a.handle, value); };
    if order == MemOrder::SeqCst { return atomic_i64_store_seqcst(a.handle, value); };
    return atomic_i64_store_seqcst(a.handle, value);
}

fn atomic_fetch_add(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_add_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_fetch_add_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_fetch_add_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_add_acqrel(a.handle, value); };
    return atomic_i64_fetch_add_seqcst(a.handle, value);
}

fn atomic_fetch_sub(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_sub_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_fetch_sub_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_fetch_sub_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_sub_acqrel(a.handle, value); };
    return atomic_i64_fetch_sub_seqcst(a.handle, value);
}

fn atomic_fetch_and(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_and_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_fetch_and_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_fetch_and_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_and_acqrel(a.handle, value); };
    return atomic_i64_fetch_and_seqcst(a.handle, value);
}

fn atomic_fetch_or(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_or_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_fetch_or_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_fetch_or_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_or_acqrel(a.handle, value); };
    return atomic_i64_fetch_or_seqcst(a.handle, value);
}

fn atomic_fetch_xor(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_xor_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_fetch_xor_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_fetch_xor_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_xor_acqrel(a.handle, value); };
    return atomic_i64_fetch_xor_seqcst(a.handle, value);
}

fn atomic_compare_exchange_result(prev: i64, expected: i64) -> Result<i64, i64> {
    if prev == expected { return Ok(prev); };
    return Err(prev);
}

fn atomic_compare_exchange(a: &AtomicI64, expected: i64, desired: i64, success_order: MemOrder, failure_order: MemOrder) -> Result<i64, i64> {
    if success_order == MemOrder::Relaxed {
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_relaxed_relaxed(a.handle, expected, desired), expected);
    };
    if success_order == MemOrder::Acquire {
        if failure_order == MemOrder::Acquire {
            return atomic_compare_exchange_result(atomic_i64_compare_exchange_acquire_acquire(a.handle, expected, desired), expected);
        };
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_acquire_relaxed(a.handle, expected, desired), expected);
    };
    if success_order == MemOrder::Release {
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_release_relaxed(a.handle, expected, desired), expected);
    };
    if success_order == MemOrder::AcqRel {
        if failure_order == MemOrder::Acquire {
            return atomic_compare_exchange_result(atomic_i64_compare_exchange_acqrel_acquire(a.handle, expected, desired), expected);
        };
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_acqrel_relaxed(a.handle, expected, desired), expected);
    };
    if failure_order == MemOrder::SeqCst {
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_seqcst_seqcst(a.handle, expected, desired), expected);
    };
    if failure_order == MemOrder::Acquire {
        return atomic_compare_exchange_result(atomic_i64_compare_exchange_seqcst_acquire(a.handle, expected, desired), expected);
    };
    return atomic_compare_exchange_result(atomic_i64_compare_exchange_seqcst_relaxed(a.handle, expected, desired), expected);
}

// ---- Concrete-width shapes backed by the i64 atomic storage cell ----
fn atomic_u64(initial: u64) -> AtomicU64 {
    return AtomicU64 { handle: atomic_i64_new(initial as i64) };
}

fn atomic_u64_drop(a: AtomicU64) -> i64 {
    return atomic_i64_free(a.handle);
}

fn atomic_i32(initial: i32) -> AtomicI32 {
    return AtomicI32 { handle: atomic_i64_new(initial as i64) };
}

fn atomic_i32_drop(a: AtomicI32) -> i64 {
    return atomic_i64_free(a.handle);
}

fn atomic_u32(initial: u32) -> AtomicU32 {
    return AtomicU32 { handle: atomic_i64_new(initial as i64) };
}

fn atomic_u32_drop(a: AtomicU32) -> i64 {
    return atomic_i64_free(a.handle);
}

fn atomic_bool(initial: bool) -> AtomicBool {
    if initial { return AtomicBool { handle: atomic_i64_new(1) }; };
    return AtomicBool { handle: atomic_i64_new(0) };
}

fn atomic_bool_drop(a: AtomicBool) -> i64 {
    return atomic_i64_free(a.handle);
}
