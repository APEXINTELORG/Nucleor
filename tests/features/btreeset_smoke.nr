// v0.8.126 stdlib/rods/btreeset.nr first test coverage.
//
// BTreeSet<str> built atop BTreeMap (RFC-0017 phase 3). Sister
// to v0.8.125's btreemap coverage.
//
// Locks:
//   1. Empty set: len=0, is_empty=1, contains 0 on missing.
//   2. Insert + contains; len reflects unique count.
//   3. Insert duplicate is a no-op (len constant).
//   4. Remove decrements len.
//   5. Clear empties.
//   6. Iteration over set position is well-defined and stable.

import "stdlib/rods/btreeset.nr"

fn check_empty() -> i64 {
    let s: i64 = bts_new();
    if bts_len(s) != 0 { return 1; };
    if bts_is_empty(s) != 1 { return 2; };
    if bts_contains(s, "missing") != 0 { return 4; };
    return 0;
}

fn check_insert_contains() -> i64 {
    let s: i64 = bts_new();
    bts_insert(s, "alpha");
    bts_insert(s, "beta");
    bts_insert(s, "gamma");
    if bts_len(s) != 3 { return 8; };
    if bts_contains(s, "alpha") != 1 { return 16; };
    if bts_contains(s, "delta") != 0 { return 32; };
    return 0;
}

fn check_insert_duplicate() -> i64 {
    let s: i64 = bts_new();
    bts_insert(s, "x");
    bts_insert(s, "x");
    bts_insert(s, "x");
    if bts_len(s) != 1 { return 64; };
    return 0;
}

fn check_remove() -> i64 {
    let s: i64 = bts_new();
    bts_insert(s, "a");
    bts_insert(s, "b");
    bts_remove(s, "a");
    if bts_contains(s, "a") != 0 { return 128; };
    if bts_contains(s, "b") != 1 { return 256; };
    if bts_len(s) != 1 { return 512; };
    return 0;
}

fn check_clear() -> i64 {
    let s: i64 = bts_new();
    bts_insert(s, "x");
    bts_insert(s, "y");
    bts_clear(s);
    if bts_len(s) != 0 { return 1024; };
    return 0;
}

fn check_iteration_count() -> i64 {
    let s: i64 = bts_new();
    bts_insert(s, "zebra");
    bts_insert(s, "apple");
    bts_insert(s, "monkey");
    let n: i64 = bts_len(s);
    if n != 3 { return 2048; };
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let _h: i64 = bts_at(s, i);
        count = count + 1;
        i = i + 1;
    };
    if count != 3 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_contains();
    fails = fails + check_insert_duplicate();
    fails = fails + check_remove();
    fails = fails + check_clear();
    fails = fails + check_iteration_count();
    return fails;
}
