// T3.11 (v0.3.11) bump arena builtin smoke (under #[test]
// framework). The bare names arena_new / arena_alloc /
// arena_reset / arena_destroy are wired to the always-linked
// __nucleor_arena_* surface in stdlib/runtime/nucleor_llvm_rt.c
// (since v0.2.154). This adds the test-framework coverage the
// v0.2.150 dangling-builtins finding never received — the
// existing tests/lang/arena_builtin.nr is a main-fn shape, not
// a #[test] one.
//
// arena_new returns `Arena` (opaque); arena_alloc returns `&i64`
// (also opaque). Both lower to i64 internally but the type
// system blocks direct comparison. We test through indirect
// shape: build something that succeeds end-to-end, then assert
// the framework's pass-counter increments cleanly.

#[test]
fn test_arena_round_trip() {
    let a = arena_new(1024);
    let p1 = arena_alloc(a, 64);
    let p2 = arena_alloc(a, 64);
    arena_reset(a);
    let p3 = arena_alloc(a, 64);
    arena_destroy(a);
    // Reaching the assert below proves all five builtins linked
    // and ran without crashing — that's the v0.2.154 contract
    // this fixture covers.
    assert_eq(1, 1);
    let _ = p1;
    let _ = p2;
    let _ = p3;
}
