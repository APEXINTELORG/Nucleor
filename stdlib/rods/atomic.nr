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

// v0.5.4 — ordered swap. Returns the prior value. Lowers to
// `atomicrmw xchg` with the requested ordering.
fn atomic_swap(a: &AtomicI64, value: i64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_swap_relaxed(a.handle, value); };
    if order == MemOrder::Acquire { return atomic_i64_swap_acquire(a.handle, value); };
    if order == MemOrder::Release { return atomic_i64_swap_release(a.handle, value); };
    if order == MemOrder::AcqRel { return atomic_i64_swap_acqrel(a.handle, value); };
    return atomic_i64_swap_seqcst(a.handle, value);
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

// === C-17 typed ordered ops for AtomicU64 / AtomicI32 / AtomicU32 ===
//
// These wrappers close the raw-handle escape hatch for the non-i64 widths.
// Storage remains the existing i64 atomic cell, so this is a typed stdlib
// surface over the current LLVM i64 atomic lowering, not a native narrow-width
// allocation ABI.

fn atomic_load_u64(a: &AtomicU64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_load_relaxed(a.handle) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_load_acquire(a.handle) as u64; };
    return atomic_i64_load_seqcst(a.handle) as u64;
}

fn atomic_store_u64(a: &AtomicU64, value: u64, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_store_relaxed(a.handle, value as i64); };
    if order == MemOrder::Release { return atomic_i64_store_release(a.handle, value as i64); };
    return atomic_i64_store_seqcst(a.handle, value as i64);
}

fn atomic_fetch_add_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_add_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_add_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_fetch_add_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_add_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_fetch_add_seqcst(a.handle, value as i64) as u64;
}

fn atomic_fetch_sub_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_sub_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_sub_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_fetch_sub_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_sub_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_fetch_sub_seqcst(a.handle, value as i64) as u64;
}

fn atomic_fetch_and_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_and_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_and_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_fetch_and_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_and_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_fetch_and_seqcst(a.handle, value as i64) as u64;
}

fn atomic_fetch_or_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_or_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_or_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_fetch_or_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_or_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_fetch_or_seqcst(a.handle, value as i64) as u64;
}

fn atomic_fetch_xor_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_xor_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_xor_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_fetch_xor_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_xor_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_fetch_xor_seqcst(a.handle, value as i64) as u64;
}

fn atomic_swap_u64(a: &AtomicU64, value: u64, order: MemOrder) -> u64 {
    if order == MemOrder::Relaxed { return atomic_i64_swap_relaxed(a.handle, value as i64) as u64; };
    if order == MemOrder::Acquire { return atomic_i64_swap_acquire(a.handle, value as i64) as u64; };
    if order == MemOrder::Release { return atomic_i64_swap_release(a.handle, value as i64) as u64; };
    if order == MemOrder::AcqRel { return atomic_i64_swap_acqrel(a.handle, value as i64) as u64; };
    return atomic_i64_swap_seqcst(a.handle, value as i64) as u64;
}

fn atomic_compare_exchange_u64(a: &AtomicU64, expected: u64, desired: u64, success_order: MemOrder, failure_order: MemOrder) -> Result<u64, u64> {
    let i64_self: AtomicI64 = AtomicI64 { handle: a.handle };
    let r: Result<i64, i64> = atomic_compare_exchange(&i64_self, expected as i64, desired as i64, success_order, failure_order);
    match r {
        Ok(v) => return Ok(v as u64),
        Err(v) => return Err(v as u64),
    }
}

fn atomic_load_i32(a: &AtomicI32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_load_relaxed(a.handle) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_load_acquire(a.handle) as i32; };
    return atomic_i64_load_seqcst(a.handle) as i32;
}

fn atomic_store_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_store_relaxed(a.handle, value as i64); };
    if order == MemOrder::Release { return atomic_i64_store_release(a.handle, value as i64); };
    return atomic_i64_store_seqcst(a.handle, value as i64);
}

fn atomic_fetch_add_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_add_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_add_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_fetch_add_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_add_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_fetch_add_seqcst(a.handle, value as i64) as i32;
}

fn atomic_fetch_sub_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_sub_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_sub_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_fetch_sub_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_sub_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_fetch_sub_seqcst(a.handle, value as i64) as i32;
}

fn atomic_fetch_and_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_and_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_and_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_fetch_and_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_and_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_fetch_and_seqcst(a.handle, value as i64) as i32;
}

fn atomic_fetch_or_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_or_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_or_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_fetch_or_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_or_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_fetch_or_seqcst(a.handle, value as i64) as i32;
}

fn atomic_fetch_xor_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_xor_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_xor_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_fetch_xor_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_xor_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_fetch_xor_seqcst(a.handle, value as i64) as i32;
}

fn atomic_swap_i32(a: &AtomicI32, value: i32, order: MemOrder) -> i32 {
    if order == MemOrder::Relaxed { return atomic_i64_swap_relaxed(a.handle, value as i64) as i32; };
    if order == MemOrder::Acquire { return atomic_i64_swap_acquire(a.handle, value as i64) as i32; };
    if order == MemOrder::Release { return atomic_i64_swap_release(a.handle, value as i64) as i32; };
    if order == MemOrder::AcqRel { return atomic_i64_swap_acqrel(a.handle, value as i64) as i32; };
    return atomic_i64_swap_seqcst(a.handle, value as i64) as i32;
}

fn atomic_compare_exchange_i32(a: &AtomicI32, expected: i32, desired: i32, success_order: MemOrder, failure_order: MemOrder) -> Result<i32, i32> {
    let i64_self: AtomicI64 = AtomicI64 { handle: a.handle };
    let r: Result<i64, i64> = atomic_compare_exchange(&i64_self, expected as i64, desired as i64, success_order, failure_order);
    match r {
        Ok(v) => return Ok(v as i32),
        Err(v) => return Err(v as i32),
    }
}

fn atomic_load_u32(a: &AtomicU32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_load_relaxed(a.handle) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_load_acquire(a.handle) as u32; };
    return atomic_i64_load_seqcst(a.handle) as u32;
}

fn atomic_store_u32(a: &AtomicU32, value: u32, order: MemOrder) -> i64 {
    if order == MemOrder::Relaxed { return atomic_i64_store_relaxed(a.handle, value as i64); };
    if order == MemOrder::Release { return atomic_i64_store_release(a.handle, value as i64); };
    return atomic_i64_store_seqcst(a.handle, value as i64);
}

fn atomic_fetch_add_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_add_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_add_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_fetch_add_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_add_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_fetch_add_seqcst(a.handle, value as i64) as u32;
}

fn atomic_fetch_sub_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_sub_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_sub_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_fetch_sub_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_sub_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_fetch_sub_seqcst(a.handle, value as i64) as u32;
}

fn atomic_fetch_and_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_and_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_and_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_fetch_and_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_and_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_fetch_and_seqcst(a.handle, value as i64) as u32;
}

fn atomic_fetch_or_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_or_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_or_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_fetch_or_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_or_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_fetch_or_seqcst(a.handle, value as i64) as u32;
}

fn atomic_fetch_xor_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_fetch_xor_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_fetch_xor_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_fetch_xor_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_fetch_xor_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_fetch_xor_seqcst(a.handle, value as i64) as u32;
}

fn atomic_swap_u32(a: &AtomicU32, value: u32, order: MemOrder) -> u32 {
    if order == MemOrder::Relaxed { return atomic_i64_swap_relaxed(a.handle, value as i64) as u32; };
    if order == MemOrder::Acquire { return atomic_i64_swap_acquire(a.handle, value as i64) as u32; };
    if order == MemOrder::Release { return atomic_i64_swap_release(a.handle, value as i64) as u32; };
    if order == MemOrder::AcqRel { return atomic_i64_swap_acqrel(a.handle, value as i64) as u32; };
    return atomic_i64_swap_seqcst(a.handle, value as i64) as u32;
}

fn atomic_compare_exchange_u32(a: &AtomicU32, expected: u32, desired: u32, success_order: MemOrder, failure_order: MemOrder) -> Result<u32, u32> {
    let i64_self: AtomicI64 = AtomicI64 { handle: a.handle };
    let r: Result<i64, i64> = atomic_compare_exchange(&i64_self, expected as i64, desired as i64, success_order, failure_order);
    match r {
        Ok(v) => return Ok(v as u32),
        Err(v) => return Err(v as u32),
    }
}

fn atomic_bool(initial: bool) -> AtomicBool {
    if initial { return AtomicBool { handle: atomic_i64_new(1) }; };
    return AtomicBool { handle: atomic_i64_new(0) };
}

fn atomic_bool_drop(a: AtomicBool) -> i64 {
    return atomic_i64_free(a.handle);
}

// === AtomicBool ordered ops (v0.4.281) ===
//
// AtomicBool ships with constructor + drop helpers; adopters constructing
// AtomicBool can't load/store/CAS without dropping to the
// raw handle. Wrappers here delegate to AtomicI64's ordered
// ops via the underlying i64 handle, with bool ↔ i64
// conversion at each boundary (false=0, true=non-zero).

fn atomic_load_bool(a: &AtomicBool, order: MemOrder) -> bool {
    let v: i64 = if order == MemOrder::Relaxed { atomic_i64_load_relaxed(a.handle) }
        else if order == MemOrder::Acquire { atomic_i64_load_acquire(a.handle) }
        else { atomic_i64_load_seqcst(a.handle) };
    return v != 0;
}

fn atomic_store_bool(a: &AtomicBool, value: bool, order: MemOrder) -> i64 {
    let v: i64 = if value { 1 } else { 0 };
    if order == MemOrder::Relaxed { return atomic_i64_store_relaxed(a.handle, v); };
    if order == MemOrder::Release { return atomic_i64_store_release(a.handle, v); };
    return atomic_i64_store_seqcst(a.handle, v);
}

// v0.5.4 — atomic_swap_bool now ships. The compiler intrinsically
// lowers `atomic_i64_swap_<order>` to `atomicrmw xchg ptr, i64 v
// <order>` with no runtime extern hop, so the AtomicBool wrapper
// just delegates through the AtomicI64 ordered swap helper with
// bool ↔ i64 conversion at the boundary (false=0, true=non-zero).
fn atomic_swap_bool(a: &AtomicBool, value: bool, order: MemOrder) -> bool {
    let v: i64 = if value { 1 } else { 0 };
    let prev: i64 = if order == MemOrder::Relaxed { atomic_i64_swap_relaxed(a.handle, v) }
        else if order == MemOrder::Acquire { atomic_i64_swap_acquire(a.handle, v) }
        else if order == MemOrder::Release { atomic_i64_swap_release(a.handle, v) }
        else if order == MemOrder::AcqRel { atomic_i64_swap_acqrel(a.handle, v) }
        else { atomic_i64_swap_seqcst(a.handle, v) };
    return prev != 0;
}

fn atomic_compare_exchange_bool(a: &AtomicBool, expected: bool, desired: bool,
    success_order: MemOrder, failure_order: MemOrder) -> Result<bool, bool>
{
    let exp_i: i64 = if expected { 1 } else { 0 };
    let des_i: i64 = if desired { 1 } else { 0 };
    let i64_self: AtomicI64 = AtomicI64 { handle: a.handle };
    let r: Result<i64, i64> = atomic_compare_exchange(&i64_self, exp_i, des_i, success_order, failure_order);
    match r {
        Ok(v) => return Ok(v != 0),
        Err(v) => return Err(v != 0),
    }
}

// === Atomic rod limitations ===
fn atomic_limitations() -> str {
    return "Atomic rod limitations: (1) WIDTHS: AtomicI64 / AtomicU64 / AtomicI32 / AtomicU32 / AtomicBool shipped. AtomicU64/AtomicI32/AtomicU32 now expose typed load/store/fetch/swap/CAS wrappers over the existing i64 atomic storage cell; NO native narrow-width allocation ABI, AtomicI16 / AtomicU16 / AtomicI8 / AtomicU8 / AtomicUsize / AtomicPtr. (2) NO ATOMIC FLOATS: no AtomicF32 / AtomicF64 (Rust core lacks these too — workaround is bits-in-AtomicU64 via to_bits/from_bits). (3) MEMORY ORDERS: Relaxed/Acquire/Release/AcqRel/SeqCst all lower correctly to LLVM intrinsics; Consume is NOT a separate variant (LLVM treats Consume as Acquire — matches C++20 std::memory_order). (4) NO FETCH-MIN/MAX yet — adopter must compose via compare_exchange loop. (5) WAIT/NOTIFY (`atomic_wait` / `atomic_notify_one` / `atomic_notify_all` futex-style) NOT shipped. Future work wires platform futex / WaitOnAddress support.";
}
