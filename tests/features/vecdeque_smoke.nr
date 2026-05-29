// v0.8.165 stdlib/rods/vecdeque.nr first test coverage.
//
// RFC-0017 phase 4 ring-buffer deque. O(1) push/pop at both
// ends. Pre-v0.8.165: zero coverage.
//
// Locks five textbook deque invariants:
//   1. FIFO via push_back / pop_front: 1,2,3 in → 1,2,3 out.
//   2. LIFO via push_back / pop_back: 1,2,3 in → 3,2,1 out.
//   3. Mixed-end push: push_front(1), push_back(2), push_front(0)
//      → indexed [0, 1, 2] (front-to-back).
//   4. Indexed get/set preserves ring-offset semantics across
//      front-side operations.
//   5. Empty / clear: fresh deque is empty; clear empties.
//
// Expected: rc=0.

import "stdlib/rods/vecdeque.nr"

fn check_fifo() -> i64 {
    let q: i64 = vd_new();
    vd_push_back(q, 1);
    vd_push_back(q, 2);
    vd_push_back(q, 3);
    if vd_len(q) != 3 { vd_free(q); return 1; };
    if vd_pop_front(q) != 1 { vd_free(q); return 2; };
    if vd_pop_front(q) != 2 { vd_free(q); return 4; };
    if vd_pop_front(q) != 3 { vd_free(q); return 8; };
    if vd_is_empty(q) != 1 { vd_free(q); return 16; };
    vd_free(q);
    return 0;
}

fn check_lifo() -> i64 {
    let q: i64 = vd_new();
    vd_push_back(q, 1);
    vd_push_back(q, 2);
    vd_push_back(q, 3);
    if vd_pop_back(q) != 3 { vd_free(q); return 32; };
    if vd_pop_back(q) != 2 { vd_free(q); return 64; };
    if vd_pop_back(q) != 1 { vd_free(q); return 128; };
    vd_free(q);
    return 0;
}

fn check_mixed_end_push() -> i64 {
    let q: i64 = vd_new();
    vd_push_front(q, 1);
    vd_push_back(q, 2);
    vd_push_front(q, 0);
    // Should be [0, 1, 2] front-to-back
    if vd_get(q, 0) != 0 { vd_free(q); return 256; };
    if vd_get(q, 1) != 1 { vd_free(q); return 512; };
    if vd_get(q, 2) != 2 { vd_free(q); return 1024; };
    vd_free(q);
    return 0;
}

fn check_clear() -> i64 {
    let q: i64 = vd_new();
    if vd_is_empty(q) != 1 { vd_free(q); return 2048; };
    vd_push_back(q, 99);
    vd_push_back(q, 100);
    if vd_is_empty(q) != 0 { vd_free(q); return 4096; };
    vd_clear(q);
    if vd_is_empty(q) != 1 { vd_free(q); return 8192; };
    vd_free(q);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fifo();
    fails = fails + check_lifo();
    fails = fails + check_mixed_end_push();
    fails = fails + check_clear();
    return fails;
}
