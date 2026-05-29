// v0.8.221 stdlib/rods/pqueue.nr first test coverage.
//
// Priority queue — binary min/max-heap with decrease-key.
// Pre-v0.8.221: zero coverage on the standalone rod (sister
// to queue.nr FIFO; both wrap stdlib/runtime/queue_rt.c).
//
// Locks four invariants:
//
//   1. Empty heap — pq_size == 0; pq_empty == 1.
//   2. Min-heap pops smallest key first — push (5, 'a'),
//      (1, 'b'), (3, 'c') → pop order 'b', 'c', 'a'.
//   3. Max-heap pops largest key first — same data → pop
//      order 'a', 'c', 'b'.
//   4. Push tracks size, peek does not consume — 3 pushes
//      → size=3; peek returns top without changing size.
//
// Expected: rc=0.

import "stdlib/rods/pqueue.nr"

fn check_empty() -> i64 {
    let h: i64 = pq_min();
    if pq_size(h) != 0 { pq_free(h); return 1; };
    if pq_empty(h) != 1 { pq_free(h); return 2; };
    pq_free(h);
    return 0;
}

fn check_min_heap_order() -> i64 {
    let h: i64 = pq_min();
    pq_push(h, 5, 100);
    pq_push(h, 1, 200);
    pq_push(h, 3, 300);
    if pq_pop(h) != 200 { pq_free(h); return 4; };
    if pq_pop(h) != 300 { pq_free(h); return 8; };
    if pq_pop(h) != 100 { pq_free(h); return 16; };
    pq_free(h);
    return 0;
}

fn check_max_heap_order() -> i64 {
    let h: i64 = pq_max();
    pq_push(h, 5, 100);
    pq_push(h, 1, 200);
    pq_push(h, 3, 300);
    if pq_pop(h) != 100 { pq_free(h); return 32; };
    if pq_pop(h) != 300 { pq_free(h); return 64; };
    if pq_pop(h) != 200 { pq_free(h); return 128; };
    pq_free(h);
    return 0;
}

fn check_size_and_peek() -> i64 {
    let h: i64 = pq_min();
    pq_push(h, 10, 1);
    pq_push(h, 5, 2);
    pq_push(h, 7, 3);
    if pq_size(h) != 3 { pq_free(h); return 256; };
    let peek1: i64 = pq_peek(h);
    if pq_size(h) != 3 { pq_free(h); return 512; };
    let peek2: i64 = pq_peek(h);
    if peek1 != peek2 { pq_free(h); return 1024; };
    if peek1 != 2 { pq_free(h); return 2048; };
    pq_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_min_heap_order();
    fails = fails + check_max_heap_order();
    fails = fails + check_size_and_peek();
    return fails;
}
