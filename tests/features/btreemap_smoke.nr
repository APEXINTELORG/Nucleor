// v0.8.125 stdlib/rods/btreemap.nr first test coverage.
//
// BTreeMap<str, i64> with deterministic iteration order. Sister
// to v0.8.118's collections HashMap coverage, but BTreeMap
// guarantees sorted iteration which collections HashMap does not.
//
// Locks RFC-0017 phase 3 BTreeMap invariants:
//   1. Empty map: len=0, is_empty=1, contains/get on missing.
//   2. Insert + get + contains round-trip.
//   3. Insert updates same key (len constant after re-insert).
//   4. Remove decrements len; removed key reports contains=0.
//   5. clear empties the map.
//   6. get_or default fallback.
//   7. Iteration yields keys in SORTED order (the load-bearing
//      BTreeMap invariant — distinct from HashMap).
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/btreemap.nr"

fn check_empty() -> i64 {
    let m: i64 = btm_new();
    if btm_len(m) != 0 { return 1; };
    if btm_is_empty(m) != 1 { return 2; };
    if btm_contains(m, "missing") != 0 { return 4; };
    return 0;
}

fn check_insert_get_contains() -> i64 {
    let m: i64 = btm_new();
    btm_insert(m, "alpha", 100);
    btm_insert(m, "beta", 200);
    if btm_get(m, "alpha") != 100 { return 8; };
    if btm_get(m, "beta") != 200 { return 16; };
    if btm_contains(m, "alpha") != 1 { return 32; };
    if btm_contains(m, "gamma") != 0 { return 64; };
    if btm_len(m) != 2 { return 128; };
    return 0;
}

fn check_insert_update_same_key() -> i64 {
    let m: i64 = btm_new();
    btm_insert(m, "x", 10);
    btm_insert(m, "x", 20);
    btm_insert(m, "x", 30);
    if btm_get(m, "x") != 30 { return 256; };
    if btm_len(m) != 1 { return 512; };
    return 0;
}

fn check_remove() -> i64 {
    let m: i64 = btm_new();
    btm_insert(m, "a", 1);
    btm_insert(m, "b", 2);
    btm_remove(m, "a");
    if btm_contains(m, "a") != 0 { return 1024; };
    if btm_contains(m, "b") != 1 { return 2048; };
    if btm_len(m) != 1 { return 4096; };
    return 0;
}

fn check_clear() -> i64 {
    let m: i64 = btm_new();
    btm_insert(m, "x", 1);
    btm_insert(m, "y", 2);
    btm_clear(m);
    if btm_len(m) != 0 { return 8192; };
    if btm_contains(m, "x") != 0 { return 16384; };
    return 0;
}

fn check_get_or() -> i64 {
    let m: i64 = btm_new();
    btm_insert(m, "present", 42);
    if btm_get_or(m, "present", 999) != 42 { return 32768; };
    if btm_get_or(m, "missing", 999) != 999 { return 65536; };
    return 0;
}

fn check_sorted_iteration() -> i64 {
    // The load-bearing BTreeMap invariant: positions yield values
    // associated with sorted keys regardless of insertion order.
    // Verified via val_at — apple=1 at pos 0, monkey=2 at pos 1,
    // zebra=3 at pos 2.
    //
    // (btm_key_at returns the i64-handle of the str key, not the
    // str directly — rod surface signature limitation. Sorted-key
    // verification via val_at suffices since values are assigned
    // 1/2/3 in alphabetical order of the keys.)
    let m: i64 = btm_new();
    btm_insert(m, "zebra", 3);
    btm_insert(m, "apple", 1);
    btm_insert(m, "monkey", 2);
    let n: i64 = btm_len(m);
    if n != 3 { return 131072; };
    if btm_val_at(m, 0) != 1 { return 262144; };  // apple
    if btm_val_at(m, 1) != 2 { return 524288; };  // monkey
    if btm_val_at(m, 2) != 3 { return 1048576; }; // zebra
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_get_contains();
    fails = fails + check_insert_update_same_key();
    fails = fails + check_remove();
    fails = fails + check_clear();
    fails = fails + check_get_or();
    fails = fails + check_sorted_iteration();
    return fails;
}
