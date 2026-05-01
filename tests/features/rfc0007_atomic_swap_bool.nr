// stdlib/rods/atomic — AtomicBool ordered swap (v0.5.4).
//
// v0.5.4 closes the deferred note from v0.4.281: AtomicBool
// shipped load/store/CAS but not swap, because the
// `atomic_i64_swap_<order>` runtime helpers didn't yet exist.
// v0.5.4 wires `atomic_i64_swap_<order>` as compiler intrinsics
// that lower to `atomicrmw xchg <ptr>, i64 <v> <order>`, then
// builds `atomic_swap_bool` on top with the same false=0/true=1
// convention used by load/store/CAS.
//
// Also exercises the typed `atomic_swap(&AtomicI64, ..)` helper
// to confirm the ordered xchg lowering round-trips at i64 width.
//
// EXPECT: build success, runtime exit 0, output
// "OK rfc0007_atomic_swap_bool".

import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let b: AtomicBool = atomic_bool(false);

    // Swap false → true. Returns prior (false).
    let p1: bool = atomic_swap_bool(&b, true, MemOrder::SeqCst);
    if p1 { print("FAIL p1 prior should be false"); return 1; };
    let v1: bool = atomic_load_bool(&b, MemOrder::Acquire);
    if !v1 { print("FAIL v1 should be true"); return 1; };

    // Swap true → false (Release ordering). Returns prior (true).
    let p2: bool = atomic_swap_bool(&b, false, MemOrder::Release);
    if !p2 { print("FAIL p2 prior should be true"); return 1; };
    let v2: bool = atomic_load_bool(&b, MemOrder::Acquire);
    if v2 { print("FAIL v2 should be false"); return 1; };

    // Swap false → false (Relaxed). Returns prior (false), state unchanged.
    let p3: bool = atomic_swap_bool(&b, false, MemOrder::Relaxed);
    if p3 { print("FAIL p3 prior should be false"); return 1; };
    let v3: bool = atomic_load_bool(&b, MemOrder::Acquire);
    if v3 { print("FAIL v3 should still be false"); return 1; };

    // Swap with AcqRel ordering across full bool round-trip.
    atomic_store_bool(&b, true, MemOrder::Release);
    let p4: bool = atomic_swap_bool(&b, false, MemOrder::AcqRel);
    if !p4 { print("FAIL p4 prior should be true"); return 1; };

    // Typed AtomicI64 swap surface (delegates through same intrinsic).
    let i: AtomicI64 = atomic_i64(7);
    let prev: i64 = atomic_swap(&i, 99, MemOrder::SeqCst);
    if prev != 7 { print("FAIL prev should be 7"); return 1; };
    let now: i64 = atomic_load(&i, MemOrder::SeqCst);
    if now != 99 { print("FAIL now should be 99"); return 1; };

    // Each ordering should compile + run.
    let r: i64 = atomic_swap(&i, 1, MemOrder::Relaxed);
    if r != 99 { print("FAIL relaxed prev"); return 1; };
    let a: i64 = atomic_swap(&i, 2, MemOrder::Acquire);
    if a != 1 { print("FAIL acquire prev"); return 1; };
    let rl: i64 = atomic_swap(&i, 3, MemOrder::Release);
    if rl != 2 { print("FAIL release prev"); return 1; };
    let ar: i64 = atomic_swap(&i, 4, MemOrder::AcqRel);
    if ar != 3 { print("FAIL acqrel prev"); return 1; };

    atomic_i64_drop(i);
    atomic_bool_drop(b);
    print("OK rfc0007_atomic_swap_bool");
    0
}
