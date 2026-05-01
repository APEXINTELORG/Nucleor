// EXPECT: ATOMIC-005 invalid memory ordering for atomic_load
import "stdlib/rods/atomic.nr"

fn main() -> i64 {
    let a: AtomicI64 = atomic_i64(0);
    let _ = atomic_load(&a, MemOrder::Release);
    atomic_i64_drop(a);
    return 0;
}
