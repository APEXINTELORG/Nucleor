// v0.8.195 stdlib/rods/queue.nr first test coverage.
//
// FIFO queue backed by Vec. Pre-v0.8.195: zero coverage.
//
// Locks four invariants:
//   1. Empty: len=0, is_empty=1, pop returns 0.
//   2. **FIFO order**: push 1, 2, 3 → pop returns 1, 2, 3.
//   3. **Peek non-destructive**: peek + pop returns same value.
//   4. Length tracking: push grows, pop shrinks.
//
// Expected: rc=0.

import "stdlib/rods/queue.nr"

fn check_empty() -> i64 {
    let q: Vec<i32> = queue_new();
    if queue_len(q) != 0 { return 1; };
    if queue_is_empty(q) != 1 { return 2; };
    return 0;
}

fn check_fifo() -> i64 {
    let q: Vec<i32> = queue_new();
    queue_push(q, 1);
    queue_push(q, 2);
    queue_push(q, 3);
    if queue_len(q) != 3 { return 4; };
    if queue_is_empty(q) != 0 { return 8; };
    if queue_pop(q) != 1 { return 16; };
    if queue_pop(q) != 2 { return 32; };
    if queue_pop(q) != 3 { return 64; };
    if queue_is_empty(q) != 1 { return 128; };
    return 0;
}

fn check_peek_non_destructive() -> i64 {
    let q: Vec<i32> = queue_new();
    queue_push(q, 99);
    if queue_peek(q) != 99 { return 256; };
    if queue_len(q) != 1 { return 512; };
    if queue_pop(q) != 99 { return 1024; };
    return 0;
}

fn check_length_tracking() -> i64 {
    let q: Vec<i32> = queue_new();
    queue_push(q, 5);
    if queue_len(q) != 1 { return 2048; };
    queue_push(q, 6);
    if queue_len(q) != 2 { return 4096; };
    queue_pop(q);
    if queue_len(q) != 1 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_fifo();
    fails = fails + check_peek_non_destructive();
    fails = fails + check_length_tracking();
    return fails;
}
