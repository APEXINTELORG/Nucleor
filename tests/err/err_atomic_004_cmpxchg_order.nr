// EXPECT: ATOMIC-004 mismatched orderings in compare_exchange
import "stdlib/rods/atomic.nr"

fn main() -> i64 {
    let a: AtomicI64 = atomic_i64(0);
    let _ = atomic_compare_exchange(&a, 0, 1, MemOrder::Relaxed, MemOrder::Acquire);
    atomic_i64_drop(a);
    return 0;
}
