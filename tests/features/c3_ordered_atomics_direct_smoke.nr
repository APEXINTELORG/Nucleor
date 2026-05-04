// v0.8.86 RFC C-3 regression smoke. The probe finding predicted
// "linker will error out" because the C runtime declares only
// __nucleor_atomic_i64_load (unordered) and not the ordered
// variants (_relaxed, _acquire, _release, _seqcst, _acqrel).
//
// In practice the compiler recognizes the ordered names and
// lowers them to LLVM atomicrmw / load atomic / store atomic
// intrinsics directly, bypassing the C runtime — so linking
// succeeds and runtime semantics are correct.
//
// This fixture exercises every ordered variant (load/store/
// fetch_add/swap across all 5 memory orderings) directly via
// the raw-handle surface from atomic.nr. If a future refactor
// ever drops the intrinsic-emit path, the linker error
// described in the C-3 finding would surface here. Locks the
// current behavior.
//
// Expected: rc=0 (every ordered helper round-trips correctly).

import "stdlib/rods/atomic.nr"

fn main() -> i64 {
    let h: i64 = atomic_i64_new(0);

    let _ = atomic_i64_store_relaxed(h, 10);
    let _ = atomic_i64_store_release(h, 11);
    let _ = atomic_i64_store_seqcst(h, 12);

    let r1: i64 = atomic_i64_load_relaxed(h);
    let r2: i64 = atomic_i64_load_acquire(h);
    let r3: i64 = atomic_i64_load_seqcst(h);
    if r1 != 12 || r2 != 12 || r3 != 12 { return 1; };

    let r4: i64 = atomic_i64_fetch_add_relaxed(h, 5);
    let r5: i64 = atomic_i64_fetch_add_acquire(h, 5);
    let r6: i64 = atomic_i64_fetch_add_release(h, 5);
    let r7: i64 = atomic_i64_fetch_add_acqrel(h, 5);
    let r8: i64 = atomic_i64_fetch_add_seqcst(h, 5);
    if r4 != 12 || r5 != 17 || r6 != 22 || r7 != 27 || r8 != 32 { return 2; };

    let s1: i64 = atomic_i64_swap_relaxed(h, 100);
    let s2: i64 = atomic_i64_swap_acquire(h, 200);
    let s3: i64 = atomic_i64_swap_release(h, 300);
    let s4: i64 = atomic_i64_swap_acqrel(h, 400);
    let s5: i64 = atomic_i64_swap_seqcst(h, 500);
    if s1 != 37 || s2 != 100 || s3 != 200 || s4 != 300 || s5 != 400 { return 3; };

    let _ = atomic_i64_free(h);
    return 0;
}
