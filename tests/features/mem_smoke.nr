// v0.8.210 stdlib/rods/mem.nr first test coverage.
//
// Vec memory-management extensions (vec_free, vec_clear,
// vec_mem_bytes). Pre-v0.8.210: zero coverage on the standalone
// rod (the helpers are exercised indirectly by long-running
// experiments but never asserted).
//
// Locks four memory-lifecycle invariants:
//
//   1. **Fresh Vec has positive mem_bytes** — the struct header
//      itself takes space (sizeof(NVec) at minimum).
//   2. **mem_bytes grows after enough pushes** — exceeding the
//      2-element inline buffer triggers heap allocation; bytes
//      strictly increase.
//   3. **vec_clear resets len, preserves bytes** — clear keeps
//      the backing allocation; len == 0; mem_bytes ≥ pre-clear.
//   4. **Cleared Vec is reusable** — push after clear writes at
//      index 0; vec_get returns the new value.
//
// Expected: rc=0.

import "stdlib/rods/mem.nr"

fn check_fresh_positive() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    if vec_mem_bytes(v) <= 0 { return 1; };
    return 0;
}

fn check_bytes_grow() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let b0: i64 = vec_mem_bytes(v);
    let mut i: i64 = 0;
    while i < 64 {
        v.push(i);
        i = i + 1;
    };
    let b1: i64 = vec_mem_bytes(v);
    if b1 <= b0 { return 2; };
    return 0;
}

fn check_clear_resets_len() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 64 {
        v.push(i);
        i = i + 1;
    };
    let bytes_before: i64 = vec_mem_bytes(v);
    vec_clear(v);
    if vec_len(v) != 0 { return 4; };
    if vec_mem_bytes(v) < bytes_before { return 8; };
    return 0;
}

fn check_clear_reuse() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(7);
    v.push(8);
    vec_clear(v);
    v.push(99);
    if vec_len(v) != 1 { return 16; };
    if vec_get(v, 0) != 99 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fresh_positive();
    fails = fails + check_bytes_grow();
    fails = fails + check_clear_resets_len();
    fails = fails + check_clear_reuse();
    return fails;
}
