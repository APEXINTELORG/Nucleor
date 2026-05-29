// v0.8.206 stdlib/rods/hashmap.nr first test coverage.
//
// String-keyed hash map (i64 values; f64 setter via bitcast).
// Pre-v0.8.206: zero coverage on the standalone rod (separate
// from `hashmap_str` and the compiler-builtin HashMap).
//
// Locks four lifecycle/semantics invariants:
//
//   1. Empty map — map_new → len 0; missing key → has 0.
//   2. Set tracks get + len — set 3 distinct keys → len 3,
//      each get returns its set value.
//   3. Overwrite same key — set "k" twice → len stays 1,
//      get returns latest value.
//   4. Delete removes key — del flips has to 0 and drops
//      len by 1.
//
// Expected: rc=0.

import "stdlib/rods/hashmap.nr"

fn check_empty() -> i64 {
    let m: i64 = map_new();
    if map_len(m) != 0 { map_free(m); return 1; };
    if map_has(m, "absent") != 0 { map_free(m); return 2; };
    map_free(m);
    return 0;
}

fn check_set_get_len() -> i64 {
    let m: i64 = map_new();
    map_set(m, "a", 1);
    map_set(m, "b", 22);
    map_set(m, "c", 333);
    if map_len(m) != 3 { map_free(m); return 4; };
    if map_get(m, "a") != 1 { map_free(m); return 8; };
    if map_get(m, "b") != 22 { map_free(m); return 16; };
    if map_get(m, "c") != 333 { map_free(m); return 32; };
    map_free(m);
    return 0;
}

fn check_overwrite() -> i64 {
    let m: i64 = map_new();
    map_set(m, "k", 100);
    map_set(m, "k", 200);
    if map_len(m) != 1 { map_free(m); return 64; };
    if map_get(m, "k") != 200 { map_free(m); return 128; };
    map_free(m);
    return 0;
}

fn check_delete() -> i64 {
    let m: i64 = map_new();
    map_set(m, "x", 7);
    map_set(m, "y", 8);
    map_del(m, "x");
    if map_has(m, "x") != 0 { map_free(m); return 256; };
    if map_len(m) != 1 { map_free(m); return 512; };
    if map_has(m, "y") != 1 { map_free(m); return 1024; };
    map_free(m);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_set_get_len();
    fails = fails + check_overwrite();
    fails = fails + check_delete();
    return fails;
}
