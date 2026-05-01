// EXPECT: build fails with ATOMIC-006.
// RFC-0007 — atomic helpers inside closure bodies must reject
// at compile time (ATOMIC-006).
//
// v0.4.280 closes compiler-meltdown filed by probe agent
// 2026-05-01: closures whose body calls atomic_* helpers crashed
// the compiler with `vec_get OOB: index <huge>, len 919`. The
// closure-lowering path doesn't yet inherit the parent fn's
// enum-variant scope, so `MemOrder::SeqCst` dispatch falls into
// the unsupported-associated-fn-call branch and panics with bad
// state. Real fix needs sym-table inheritance (multi-cycle).
// ATOMIC-006 catches the dangerous pattern at parse-time and
// halts cleanly with a message naming the limitation + workaround.
//
// EXPECT: build fails with ATOMIC-006.

import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let a: AtomicI64 = atomic_i64(0);
    let inc = || atomic_fetch_add(&a, 1, MemOrder::SeqCst);
    let _: i64 = inc();
    0
}
