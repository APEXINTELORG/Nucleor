// v0.8.160 stdlib/rods/allocator.nr first test coverage.
//
// Three allocator flavors: bump arena, object pool, stack
// (mark/pop) allocator. Foundational for any per-frame /
// per-request memory model. Pre-v0.8.160: zero coverage.
//
// Locks invariants for all three:
//
//   Arena (bump):
//     1. Fresh arena: used=0, peak=0.
//     2. After alloc(n): used == n, peak == n.
//     3. After reset: used == 0, peak unchanged (peak is high-water).
//     4. capacity matches what was requested at new().
//
//   Object Pool:
//     5. Fresh pool: used=0, available=capacity.
//     6. After alloc: used+1, available-1.
//     7. After free_slot: counts return to fresh state.
//
//   Stack (bump + mark/pop):
//     8. push grows the high-water; mark + push + pop returns
//        to the marked state (used: implicit via pointer
//        arithmetic — we just verify push returns a valid
//        non-zero pointer and that mark/pop don't fault).
//
// Expected: rc=0.

import "stdlib/rods/allocator.nr"

fn check_arena_basic() -> i64 {
    let a: i64 = allocator_arena_new(1024);
    if allocator_arena_capacity(a) != 1024 { allocator_arena_free(a); return 1; };
    if allocator_arena_used(a) != 0 { allocator_arena_free(a); return 2; };
    let p1: i64 = allocator_arena_alloc(a, 64);
    if p1 == 0 { allocator_arena_free(a); return 4; };
    if allocator_arena_used(a) != 64 { allocator_arena_free(a); return 8; };
    if allocator_arena_peak(a) != 64 { allocator_arena_free(a); return 16; };
    let p2: i64 = allocator_arena_alloc(a, 32);
    if p2 == 0 { allocator_arena_free(a); return 32; };
    if allocator_arena_used(a) != 96 { allocator_arena_free(a); return 64; };
    allocator_arena_reset(a);
    if allocator_arena_used(a) != 0 { allocator_arena_free(a); return 128; };
    // Peak is high-water, should not reset.
    if allocator_arena_peak(a) != 96 { allocator_arena_free(a); return 256; };
    allocator_arena_free(a);
    return 0;
}

fn check_pool_basic() -> i64 {
    let p: i64 = allocator_pool_new(64, 8);
    if allocator_pool_capacity(p) != 8 { allocator_pool_free(p); return 512; };
    if allocator_pool_used(p) != 0 { allocator_pool_free(p); return 1024; };
    if allocator_pool_available(p) != 8 { allocator_pool_free(p); return 2048; };
    let s1: i64 = allocator_pool_alloc(p);
    if s1 == 0 { allocator_pool_free(p); return 4096; };
    if allocator_pool_used(p) != 1 { allocator_pool_free(p); return 8192; };
    if allocator_pool_available(p) != 7 { allocator_pool_free(p); return 16384; };
    allocator_pool_free_slot(p, s1);
    if allocator_pool_used(p) != 0 { allocator_pool_free(p); return 32768; };
    if allocator_pool_available(p) != 8 { allocator_pool_free(p); return 65536; };
    allocator_pool_free(p);
    return 0;
}

fn check_stack_basic() -> i64 {
    let s: i64 = allocator_stack_new(1024);
    let p1: i64 = allocator_stack_push(s, 64);
    if p1 == 0 { allocator_stack_free(s); return 131072; };
    allocator_stack_mark(s);
    let p2: i64 = allocator_stack_push(s, 128);
    if p2 == 0 { allocator_stack_free(s); return 262144; };
    allocator_stack_pop(s);
    // Re-push from the marked point — must succeed.
    let p3: i64 = allocator_stack_push(s, 256);
    if p3 == 0 { allocator_stack_free(s); return 524288; };
    allocator_stack_free(s);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_arena_basic();
    fails = fails + check_pool_basic();
    fails = fails + check_stack_basic();
    return fails;
}
