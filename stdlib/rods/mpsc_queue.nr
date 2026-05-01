// =====================================================
// rods/mpsc_queue - lock-free multi-producer/single-consumer queue
// =====================================================
// Import: import "stdlib/rods/mpsc_queue.nr"
//
// Bounded sequence-number ring. Producers reserve slots with CAS on a
// global tail counter; each slot sequence publishes readiness and
// prevents producers from overwriting a slot until the single consumer
// releases it.
// =====================================================

import "stdlib/rods/atomic.nr"

struct MpscQueue<T> {
    buffer: Vec<Option<T>>,
    sequence: Vec<AtomicI64>,
    capacity: i64,
    head: AtomicI64,
    tail: AtomicI64,
}

fn mpsc_normalize_capacity(capacity: i64) -> i64 {
    if capacity <= 0 { return 1; };
    return capacity;
}

fn mpsc_new<T>(capacity: i64) -> MpscQueue<T> {
    let cap: i64 = mpsc_normalize_capacity(capacity);
    let mut buf: Vec<Option<T>> = Vec::new();
    let mut seq: Vec<AtomicI64> = Vec::new();
    let mut i: i64 = 0;
    while i < cap {
        let empty: Option<T> = None;
        buf.push(empty);
        seq.push(atomic_i64(i));
        i = i + 1;
    };
    return MpscQueue<T> { buffer: buf, sequence: seq, capacity: cap, head: atomic_i64(0), tail: atomic_i64(0) };
}

fn mpsc_try_reserve<T>(q: &MpscQueue<T>) -> i64 {
    while true {
        let tail: i64 = atomic_load(&q.tail, MemOrder::Acquire);
        let slot: i64 = tail % q.capacity;
        let seq_cell: AtomicI64 = q.sequence.get(slot);
        let seq: i64 = atomic_load(&seq_cell, MemOrder::Acquire);
        let diff: i64 = seq - tail;
        if diff == 0 {
            let cas: Result<i64, i64> = atomic_compare_exchange(&q.tail, tail, tail + 1, MemOrder::AcqRel, MemOrder::Acquire);
            match cas {
                Ok(prev) => {
                    if prev == tail { return tail; };
                },
                Err(_) => { },
            };
        } else {
            if diff < 0 { return 0 - 1; };
        };
    };
    return 0 - 1;
}

fn mpsc_push_shared<T>(q: &MpscQueue<T>, val: T) -> bool {
    let ticket: i64 = mpsc_try_reserve(q);
    if ticket < 0 { return false; };
    let slot: i64 = ticket % q.capacity;
    q.buffer.set(slot, Some(val));
    let seq_cell: AtomicI64 = q.sequence.get(slot);
    atomic_store(&seq_cell, ticket + 1, MemOrder::Release);
    return true;
}

fn mpsc_push<T>(q: &mut MpscQueue<T>, val: T) -> bool {
    return mpsc_push_shared(q, val);
}

fn mpsc_pop_shared<T>(q: &MpscQueue<T>) -> Option<T> {
    let head: i64 = atomic_load(&q.head, MemOrder::Relaxed);
    let slot: i64 = head % q.capacity;
    let seq_cell: AtomicI64 = q.sequence.get(slot);
    let seq: i64 = atomic_load(&seq_cell, MemOrder::Acquire);
    if seq - (head + 1) != 0 { return None; };

    let item: Option<T> = q.buffer.get(slot);
    let empty: Option<T> = None;
    q.buffer.set(slot, empty);
    atomic_store(&q.head, head + 1, MemOrder::Release);
    atomic_store(&seq_cell, head + q.capacity, MemOrder::Release);
    return item;
}

fn mpsc_pop<T>(q: &mut MpscQueue<T>) -> Option<T> {
    return mpsc_pop_shared(q);
}

fn mpsc_len<T>(q: &MpscQueue<T>) -> i64 {
    let head: i64 = atomic_load(&q.head, MemOrder::Acquire);
    let tail: i64 = atomic_load(&q.tail, MemOrder::Acquire);
    return tail - head;
}

fn mpsc_capacity<T>(q: &MpscQueue<T>) -> i64 {
    return q.capacity;
}
