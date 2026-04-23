// rods/allocator — verify rod wrapper compiles + links (v0.2.150 wrap)
import "stdlib/rods/allocator.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Arena (bump)
    let a: i64 = allocator_arena_new(4096);
    if a == 0 { print("FAIL allocator_arena_new"); return 1; };
    if allocator_arena_capacity(a) != 4096 { fail = fail + 1; print("FAIL allocator_arena_capacity"); };
    let p1: i64 = allocator_arena_alloc(a, 64);
    let p2: i64 = allocator_arena_alloc(a, 128);
    if p1 == 0 || p2 == 0 { fail = fail + 1; print("FAIL allocator_arena_alloc"); };
    if allocator_arena_used(a) < 192 { fail = fail + 1; print("FAIL allocator_arena_used"); };
    allocator_arena_reset(a);
    if allocator_arena_used(a) != 0 { fail = fail + 1; print("FAIL allocator_arena_reset"); };
    allocator_arena_free(a);

    // Object pool
    let pl: i64 = allocator_pool_new(32, 16);
    if pl == 0 { print("FAIL allocator_pool_new"); return 1; };
    if allocator_pool_capacity(pl) != 16 { fail = fail + 1; print("FAIL allocator_pool_capacity"); };
    let s1: i64 = allocator_pool_alloc(pl);
    if s1 == 0 { fail = fail + 1; print("FAIL allocator_pool_alloc"); };
    if allocator_pool_used(pl) != 1 { fail = fail + 1; print("FAIL allocator_pool_used"); };
    allocator_pool_free_slot(pl, s1);
    allocator_pool_free(pl);

    // Stack allocator
    let sa: i64 = allocator_stack_new(1024);
    if sa == 0 { print("FAIL allocator_stack_new"); return 1; };
    allocator_stack_mark(sa);
    let _x: i64 = allocator_stack_push(sa, 64);
    let _y: i64 = allocator_stack_push(sa, 64);
    allocator_stack_pop(sa);
    allocator_stack_free(sa);

    if fail == 0 { print("OK allocator_smoke"); };
    return fail;
}
