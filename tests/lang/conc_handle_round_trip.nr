// Lane 2 positive (concurrency handle round-trip): legitimate
// usage of the AtomicI64 surface via the public constructor +
// accessor fns. The opaque-handle gate must not regress this
// canonical pattern.
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let a: AtomicI64 = atomic_i64(7);
    let v: i64 = atomic_load(&a, MemOrder::SeqCst);
    atomic_i64_drop(a);
    if v == 7 { print("OK conc_handle_round_trip\n"); 0 } else { 1 }
}
