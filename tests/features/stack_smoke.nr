// v0.8.167 stdlib/rods/stack.nr first test coverage.
//
// Pure Vec-backed LIFO stack. Pre-v0.8.167: zero coverage.
//
// Locks four invariants:
//   1. Empty stack: len=0, is_empty=1, pop returns -1.
//   2. push/pop is LIFO: push 1,2,3 → pop returns 3,2,1.
//   3. peek does not consume: pop after peek returns same value.
//   4. push grows length, pop shrinks it.
//
// Expected: rc=0.

import "stdlib/rods/stack.nr"

fn check_empty() -> i64 {
    let s: Vec<i32> = stack_new();
    if stack_len(s) != 0 { return 1; };
    if stack_is_empty(s) != 1 { return 2; };
    if stack_pop(s) != 0 - 1 { return 4; };
    return 0;
}

fn check_lifo() -> i64 {
    let s: Vec<i32> = stack_new();
    stack_push(s, 1);
    stack_push(s, 2);
    stack_push(s, 3);
    if stack_len(s) != 3 { return 8; };
    if stack_is_empty(s) != 0 { return 16; };
    if stack_pop(s) != 3 { return 32; };
    if stack_pop(s) != 2 { return 64; };
    if stack_pop(s) != 1 { return 128; };
    if stack_is_empty(s) != 1 { return 256; };
    return 0;
}

fn check_peek_non_destructive() -> i64 {
    let s: Vec<i32> = stack_new();
    stack_push(s, 42);
    if stack_peek(s) != 42 { return 512; };
    if stack_len(s) != 1 { return 1024; };
    // pop after peek returns same value
    if stack_pop(s) != 42 { return 2048; };
    return 0;
}

fn check_length_tracking() -> i64 {
    let s: Vec<i32> = stack_new();
    stack_push(s, 10);
    if stack_len(s) != 1 { return 4096; };
    stack_push(s, 20);
    if stack_len(s) != 2 { return 8192; };
    stack_pop(s);
    if stack_len(s) != 1 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_lifo();
    fails = fails + check_peek_non_destructive();
    fails = fails + check_length_tracking();
    return fails;
}
