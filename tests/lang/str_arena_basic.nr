// RFC-0030 phase 1 (v0.2.165) — string arena.
//
// Allocate transient strings against an arena, free them all in
// one shot. Useful for "build a bunch of intermediate strings,
// use them, throw them all away" patterns where the caller
// doesn't want to track per-string lifetimes.

fn main() -> i64 {
    let mut fail: i64 = 0;

    let arena: i64 = str_arena_new();
    if arena == 0 { print("FAIL str_arena_new"); return 1; };

    // Build some strings against the arena.
    let s1: str = str_arena_concat(arena, "hello, ", "world");
    if str_eq(s1, "hello, world") == 0 { fail = fail + 1; print("FAIL arena concat 1"); print(s1); };

    let s2: str = str_arena_concat(arena, "foo", "bar");
    if str_eq(s2, "foobar") == 0 { fail = fail + 1; print("FAIL arena concat 2"); print(s2); };

    let s3: str = str_arena_substring(arena, "abcdef", 2, 5);
    if str_eq(s3, "cde") == 0 { fail = fail + 1; print("FAIL arena substring"); print(s3); };

    // Bytes accounted: 13 + 7 + 4 = 24 bytes (with null terminators).
    let used: i64 = str_arena_bytes(arena);
    if used < 24 { fail = fail + 1; print("FAIL arena bytes accounting"); };

    // One free reclaims everything.
    str_arena_free(arena);

    if fail == 0 { print("OK str_arena_basic"); };
    return fail;
}
