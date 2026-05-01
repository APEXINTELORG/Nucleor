// =====================================================
// rods/spsc_queue - lock-free single-producer/single-consumer queue
// =====================================================
// Import: import "stdlib/rods/spsc_queue.nr"
//
// Bounded Lamport ring buffer. Head and tail are monotonically
// increasing AtomicI64 counters; slots hold Option<T> so construction
// does not need a synthetic T value.
// =====================================================

import "stdlib/rods/atomic.nr"

struct SpscQueue<T> {
    buffer: Vec<Option<T>>,
    capacity: i64,
    head: AtomicI64,
    tail: AtomicI64,
}

fn spsc_normalize_capacity(capacity: i64) -> i64 {
    if capacity <= 0 { return 1; };
    return capacity;
}

fn spsc_new<T>(capacity: i64) -> SpscQueue<T> {
    let cap: i64 = spsc_normalize_capacity(capacity);
    let mut buf: Vec<Option<T>> = Vec::new();
    let mut i: i64 = 0;
    while i < cap {
        let empty: Option<T> = None;
        buf.push(empty);
        i = i + 1;
    };
    return SpscQueue<T> { buffer: buf, capacity: cap, head: atomic_i64(0), tail: atomic_i64(0) };
}

fn spsc_push<T>(q: &mut SpscQueue<T>, val: T) -> bool {
    let tail: i64 = atomic_load(&q.tail, MemOrder::Relaxed);
    let head: i64 = atomic_load(&q.head, MemOrder::Acquire);
    if tail - head >= q.capacity { return false; };

    let slot: i64 = tail % q.capacity;
    q.buffer.set(slot, Some(val));
    atomic_store(&q.tail, tail + 1, MemOrder::Release);
    return true;
}

fn spsc_pop<T>(q: &mut SpscQueue<T>) -> Option<T> {
    let head: i64 = atomic_load(&q.head, MemOrder::Relaxed);
    let tail: i64 = atomic_load(&q.tail, MemOrder::Acquire);
    if head >= tail { return None; };

    let slot: i64 = head % q.capacity;
    let item: Option<T> = q.buffer.get(slot);
    let empty: Option<T> = None;
    q.buffer.set(slot, empty);
    atomic_store(&q.head, head + 1, MemOrder::Release);
    return item;
}

fn spsc_len<T>(q: &SpscQueue<T>) -> i64 {
    let head: i64 = atomic_load(&q.head, MemOrder::Acquire);
    let tail: i64 = atomic_load(&q.tail, MemOrder::Acquire);
    return tail - head;
}

fn spsc_capacity<T>(q: &SpscQueue<T>) -> i64 {
    return q.capacity;
}
