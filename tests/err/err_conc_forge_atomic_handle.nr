// EXPECT: CONC-G6-OPAQUE-HANDLE AtomicI64
// Lane 2 audit fix (F-CONC-001, 2026-05-08): concurrency-handle
// encapsulation. Pre-fix `AtomicI64 { handle: 12345 }` from a
// fabricated i64 produced a "valid"-looking handle that
// crashed the process via SEGV / UAF when passed to
// atomic_load/store. Now: struct-literal construction outside
// the rod's constructor fns is a hard error.
import "stdlib/rods/atomic.nr"

fn main() -> i32 {
    let forged: AtomicI64 = AtomicI64 { handle: 12345 };
    0
}
