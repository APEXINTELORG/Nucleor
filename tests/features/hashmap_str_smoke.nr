// v0.8.209 stdlib/rods/hashmap_str.nr first test coverage.
//
// HashMap<str, i64> (RFC-0017 phase 2) — open-addressed
// FNV-1a + linear probing. Pre-v0.8.209: zero coverage on the
// standalone rod (sister to hashmap.nr which uses nuc_map_*).
//
// Locks four lifecycle/semantics invariants:
//
//   1. Empty map — hms_new → len 0, is_empty 1, contains
//      missing 0.
//   2. Insert tracks contains + len — 3 distinct keys → len 3,
//      each get returns its set value.
//   3. get_or returns default for missing — non-inserted key
//      → default value.
//   4. Remove flips contains + drops len — insert+remove →
//      contains 0, len decreases by 1.
//
// Expected: rc=0.

import "stdlib/rods/hashmap_str.nr"

fn check_empty() -> i64 {
    let m: i64 = hms_new();
    if hms_len(m) != 0 { hms_free(m); return 1; };
    if hms_is_empty(m) != 1 { hms_free(m); return 2; };
    if hms_contains(m, "absent") != 0 { hms_free(m); return 4; };
    hms_free(m);
    return 0;
}

fn check_insert_get() -> i64 {
    let m: i64 = hms_new();
    hms_insert(m, "alpha", 11);
    hms_insert(m, "beta", 22);
    hms_insert(m, "gamma", 33);
    if hms_len(m) != 3 { hms_free(m); return 8; };
    if hms_get(m, "alpha") != 11 { hms_free(m); return 16; };
    if hms_get(m, "beta") != 22 { hms_free(m); return 32; };
    if hms_get(m, "gamma") != 33 { hms_free(m); return 64; };
    hms_free(m);
    return 0;
}

fn check_get_or_default() -> i64 {
    let m: i64 = hms_new();
    hms_insert(m, "present", 100);
    if hms_get_or(m, "present", 999) != 100 { hms_free(m); return 128; };
    if hms_get_or(m, "absent", 999) != 999 { hms_free(m); return 256; };
    hms_free(m);
    return 0;
}

fn check_remove() -> i64 {
    let m: i64 = hms_new();
    hms_insert(m, "k1", 1);
    hms_insert(m, "k2", 2);
    hms_remove(m, "k1");
    if hms_contains(m, "k1") != 0 { hms_free(m); return 512; };
    if hms_len(m) != 1 { hms_free(m); return 1024; };
    if hms_get(m, "k2") != 2 { hms_free(m); return 2048; };
    hms_free(m);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_get();
    fails = fails + check_get_or_default();
    fails = fails + check_remove();
    return fails;
}
