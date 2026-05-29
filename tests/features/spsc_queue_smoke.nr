// v0.8.174 stdlib/rods/spsc_queue.nr first test coverage.
//
// Lock-free single-producer/single-consumer ring buffer
// (Lamport queue). Pre-v0.8.174: zero coverage.
//
// Locks four invariants on a capacity-4 SPSC queue with i64
// payload (single-threaded — concurrent semantics are out of
// smoke scope; here we lock the contract on a fresh queue):
//
//   1. Empty pop returns None.
//   2. Push then pop returns the pushed value via Some.
//   3. FIFO ordering — push 1, 2, 3 → pop returns Some(1),
//      Some(2), Some(3).
//   4. Capacity guard — push beyond capacity returns false;
//      a pop frees a slot allowing a subsequent push.
//
// Expected: rc=0.

import "stdlib/rods/spsc_queue.nr"

fn check_empty_pop() -> i64 {
    let mut q: SpscQueue<i64> = spsc_new<i64>(4);
    let r: Option<i64> = spsc_pop(&mut q);
    match r {
        None => return 0,
        Some(_) => return 1,
    }
}

fn check_push_pop_round_trip() -> i64 {
    let mut q: SpscQueue<i64> = spsc_new<i64>(4);
    if spsc_push(&mut q, 42) != true { return 2; };
    let r: Option<i64> = spsc_pop(&mut q);
    match r {
        None => return 4,
        Some(v) => {
            if v != 42 { return 8; };
            return 0;
        },
    }
}

fn check_fifo() -> i64 {
    let mut q: SpscQueue<i64> = spsc_new<i64>(4);
    spsc_push(&mut q, 1);
    spsc_push(&mut q, 2);
    spsc_push(&mut q, 3);
    let r1: Option<i64> = spsc_pop(&mut q);
    match r1 {
        None => return 16,
        Some(v) => if v != 1 { return 32; },
    };
    let r2: Option<i64> = spsc_pop(&mut q);
    match r2 {
        None => return 64,
        Some(v) => if v != 2 { return 128; },
    };
    let r3: Option<i64> = spsc_pop(&mut q);
    match r3 {
        None => return 256,
        Some(v) => if v != 3 { return 512; },
    };
    return 0;
}

fn check_capacity_guard() -> i64 {
    let mut q: SpscQueue<i64> = spsc_new<i64>(2);
    if spsc_push(&mut q, 1) != true { return 1024; };
    if spsc_push(&mut q, 2) != true { return 2048; };
    // Queue full — should reject
    if spsc_push(&mut q, 3) != false { return 4096; };
    // Pop one slot, then we can push again
    spsc_pop(&mut q);
    if spsc_push(&mut q, 3) != true { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_pop();
    fails = fails + check_push_pop_round_trip();
    fails = fails + check_fifo();
    fails = fails + check_capacity_guard();
    return fails;
}
