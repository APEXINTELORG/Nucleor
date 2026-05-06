// v0836 C-10 - thread barrier smoke.
//
// Four OS threads rendezvous twice on a reusable barrier. Each worker proves
// that every peer reached the first barrier before any worker advances past it.

import "stdlib/rods/thread.nr"
import "stdlib/rods/atomic.nr"

struct BarrierShared {
    barrier: i64,
    parties: i64,
    before: AtomicI64,
    after: AtomicI64,
    failures: AtomicI64,
}

fn barrier_worker(shared: &BarrierShared) -> i64 {
    atomic_fetch_add(&shared.before, 1, MemOrder::SeqCst);
    let first: i64 = thread_barrier_wait(shared.barrier);
    if first < 0 {
        atomic_fetch_add(&shared.failures, 1, MemOrder::SeqCst);
        return 1;
    };

    if atomic_load(&shared.before, MemOrder::SeqCst) != shared.parties {
        atomic_fetch_add(&shared.failures, 1, MemOrder::SeqCst);
    };

    atomic_fetch_add(&shared.after, 1, MemOrder::SeqCst);
    let second: i64 = thread_barrier_wait(shared.barrier);
    if second < 0 {
        atomic_fetch_add(&shared.failures, 1, MemOrder::SeqCst);
        return 2;
    };

    if atomic_load(&shared.after, MemOrder::SeqCst) != shared.parties {
        atomic_fetch_add(&shared.failures, 1, MemOrder::SeqCst);
    };
    return 0;
}

fn main() -> i64 {
    if thread_barrier_new(0) != 0 { return 1; };

    let parties: i64 = 4;
    let b: i64 = thread_barrier_new(parties);
    if b == 0 { return 2; };

    let shared: BarrierShared = BarrierShared {
        barrier: b,
        parties: parties,
        before: atomic_i64(0),
        after: atomic_i64(0),
        failures: atomic_i64(0),
    };

    let h0: i64 = thread_spawn(barrier_worker, &shared);
    let h1: i64 = thread_spawn(barrier_worker, &shared);
    let h2: i64 = thread_spawn(barrier_worker, &shared);
    let h3: i64 = thread_spawn(barrier_worker, &shared);
    thread_join(h0);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);

    let failures: i64 = atomic_load(&shared.failures, MemOrder::SeqCst);
    let before: i64 = atomic_load(&shared.before, MemOrder::SeqCst);
    let after: i64 = atomic_load(&shared.after, MemOrder::SeqCst);

    thread_barrier_free(b);
    atomic_i64_drop(shared.before);
    atomic_i64_drop(shared.after);
    atomic_i64_drop(shared.failures);

    if failures != 0 { return 4; };
    if before != parties { return 8; };
    if after != parties { return 16; };
    return 0;
}
