// RFC-0002 phase 1 — bare arena builtins (v0.2.154).
//
// Exercise the s1's pre-declared `arena_new` / `arena_alloc` /
// `arena_reset` / `arena_destroy` builtins WITHOUT importing
// `stdlib/rods/allocator.nr`. Before v0.2.154 this file would
// link-fail because `__nucleor_arena_*` symbols were dangling;
// the v0.2.154 main-runtime impls close that trap.

fn main() -> i64 {
    let mut fail: i64 = 0;

    let a = arena_new(4096);
    let p1 = arena_alloc(a, 64);
    if p1 == 0 { fail = fail + 1; print("FAIL alloc 1"); };

    let p2 = arena_alloc(a, 128);
    if p2 == 0 { fail = fail + 1; print("FAIL alloc 2"); };

    // Aligned 64+128 = 192; both addresses must be inside the arena
    // and p2 must be strictly above p1.
    if p2 <= p1 { fail = fail + 1; print("FAIL alloc ordering"); };

    arena_reset(a);
    let p3 = arena_alloc(a, 64);
    // After reset, the next alloc should land at the same address
    // p1 originally had — confirms the offset really went to 0.
    if p3 != p1 { fail = fail + 1; print("FAIL reset"); };

    arena_destroy(a);

    if fail == 0 { print("OK arena_builtin"); };
    return fail;
}
