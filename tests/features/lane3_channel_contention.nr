// Lane 3 (F-CONC-016): channel contention smoke test.
//
// 4 producers × 4 consumers × 10000 messages each.
// Each producer pushes 10000 distinct ints; each consumer pulls 10000.
// Total send count = total recv count = 40000.

import "stdlib/rods/concurrency.nr"
import "stdlib/rods/atomic.nr"

struct ChannelShared {
    channel: i64,
    produced: AtomicI64,
    consumed: AtomicI64,
    failures: AtomicI64,
    per_worker: i64,
}

fn producer(shared: &ChannelShared) -> i64 {
    let mut i: i64 = 0;
    while i < shared.per_worker {
        conc_send(shared.channel, i + 1);
        atomic_fetch_add(&shared.produced, 1, MemOrder::SeqCst);
        i = i + 1;
    };
    return 0;
}

fn consumer(shared: &ChannelShared) -> i64 {
    let mut i: i64 = 0;
    while i < shared.per_worker {
        let v: i64 = conc_recv(shared.channel);
        if v <= 0 {
            atomic_fetch_add(&shared.failures, 1, MemOrder::SeqCst);
        };
        atomic_fetch_add(&shared.consumed, 1, MemOrder::SeqCst);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    // Capacity 64: forces real producer-consumer interleaving (not just
    // a queued buffer drain).
    let ch: i64 = conc_channel(64);
    let shared: ChannelShared = ChannelShared {
        channel: ch,
        produced: atomic_i64(0),
        consumed: atomic_i64(0),
        failures: atomic_i64(0),
        per_worker: 10000,
    };
    let p0: i64 = thread_spawn(producer, &shared);
    let p1: i64 = thread_spawn(producer, &shared);
    let p2: i64 = thread_spawn(producer, &shared);
    let p3: i64 = thread_spawn(producer, &shared);
    let c0: i64 = thread_spawn(consumer, &shared);
    let c1: i64 = thread_spawn(consumer, &shared);
    let c2: i64 = thread_spawn(consumer, &shared);
    let c3: i64 = thread_spawn(consumer, &shared);
    thread_join(p0);
    thread_join(p1);
    thread_join(p2);
    thread_join(p3);
    thread_join(c0);
    thread_join(c1);
    thread_join(c2);
    thread_join(c3);
    let produced: i64 = atomic_load(&shared.produced, MemOrder::SeqCst);
    let consumed: i64 = atomic_load(&shared.consumed, MemOrder::SeqCst);
    let failures: i64 = atomic_load(&shared.failures, MemOrder::SeqCst);
    atomic_i64_drop(shared.produced);
    atomic_i64_drop(shared.consumed);
    atomic_i64_drop(shared.failures);
    if produced != 40000 || consumed != 40000 || failures != 0 {
        return 1;
    };
    print("OK lane3_channel_contention");
    return 0;
}
