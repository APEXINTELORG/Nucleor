// v0.8.118 stdlib/rods/collections.nr first test coverage.
//
// Per the zero-coverage rod survey, collections.nr (string-keyed
// open-addressing HashMap + Vec utilities) had no existing
// tests. Silent regressions in hash, probing, or grow would
// silently lose entries — a load-bearing risk class for any
// adopter using map_set/get for state.
//
// Locks textbook collections invariants:
//   1. Empty map: map_len == 0; map_has returns 0 for any key.
//   2. set + get: stored value retrievable.
//   3. set updates: replacing same key keeps map_len constant.
//   4. set + remove: removed key reports has=0; len decremented.
//   5. map_clear empties map_len and clears keys.
//   6. vec_contains / vec_index_of / vec_reverse / vec_clone
//      basic correctness.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/collections.nr"

fn check_map_empty() -> i64 {
    let m: Vec<i32> = map_new();
    if map_len(m) != 0 { return 1; };
    if map_has(m, "missing") != 0 { return 2; };
    if map_get(m, "missing") != 0 { return 4; };
    return 0;
}

fn check_map_set_get() -> i64 {
    let m: Vec<i32> = map_new();
    map_set(m, "alpha", 100);
    map_set(m, "beta", 200);
    if map_get(m, "alpha") != 100 { return 8; };
    if map_get(m, "beta") != 200 { return 16; };
    if map_has(m, "alpha") != 1 { return 32; };
    if map_has(m, "gamma") != 0 { return 64; };
    if map_len(m) != 2 { return 128; };
    return 0;
}

fn check_map_update_same_key() -> i64 {
    let m: Vec<i32> = map_new();
    map_set(m, "x", 10);
    map_set(m, "x", 20);
    map_set(m, "x", 30);
    if map_get(m, "x") != 30 { return 256; };
    if map_len(m) != 1 { return 512; };
    return 0;
}

fn check_map_remove() -> i64 {
    let m: Vec<i32> = map_new();
    map_set(m, "a", 1);
    map_set(m, "b", 2);
    map_remove(m, "a");
    if map_has(m, "a") != 0 { return 1024; };
    if map_has(m, "b") != 1 { return 2048; };
    if map_len(m) != 1 { return 4096; };
    return 0;
}

fn check_map_clear() -> i64 {
    let m: Vec<i32> = map_new();
    map_set(m, "x", 1);
    map_set(m, "y", 2);
    map_clear(m);
    if map_len(m) != 0 { return 8192; };
    if map_has(m, "x") != 0 { return 16384; };
    return 0;
}

fn check_vec_helpers() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    if vec_contains(v, 20) != 1 { return 32768; };
    if vec_contains(v, 99) != 0 { return 65536; };
    if vec_index_of(v, 30) != 2 { return 131072; };
    if vec_index_of(v, 99) != 0 - 1 { return 262144; };
    let cloned: Vec<i32> = vec_clone(v);
    if vec_len(cloned) != 3 { return 524288; };
    if vec_get(cloned, 1) != 20 { return 1048576; };
    vec_reverse(v);
    if vec_get(v, 0) != 30 { return 2097152; };
    if vec_get(v, 2) != 10 { return 4194304; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_map_empty();
    fails = fails + check_map_set_get();
    fails = fails + check_map_update_same_key();
    fails = fails + check_map_remove();
    fails = fails + check_map_clear();
    fails = fails + check_vec_helpers();
    return fails;
}
