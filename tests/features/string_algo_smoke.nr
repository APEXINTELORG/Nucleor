// v0.8.168 stdlib/rods/string_algo.nr first test coverage.
//
// Advanced string algorithms: KMP search, Levenshtein edit
// distance, prefix trie. Pre-v0.8.168: zero coverage.
//
// Locks textbook invariants for all three:
//
//   KMP search (returns Vec<i64> of match positions):
//     1. Found: `kmp("hello world", "world")` → 1 match at pos 6.
//     2. Not found: `kmp("abc", "xyz")` → empty vec.
//     3. Multiple matches: `kmp("ababab", "ab")` → 3 matches.
//
//   Levenshtein:
//     4. Identity: `lev("kitten", "kitten") == 0`.
//     5. Classic textbook: `lev("kitten", "sitting") == 3`
//        (k→s substitution, e→i substitution, +g insertion).
//
//   Trie:
//     6. Insert + contains round-trip.
//     7. starts_with: prefix lookup is true even when full
//        word isn't inserted.
//     8. count_prefix: counts inserted words sharing prefix.
//
// Expected: rc=0.

import "stdlib/rods/string_algo.nr"

fn check_kmp() -> i64 {
    let m1: i64 = str_kmp("hello world", "world");
    if vec_len(m1) != 1 { return 1; };
    if vec_get(m1, 0) != 6 { return 2; };
    let m2: i64 = str_kmp("abc", "xyz");
    if vec_len(m2) != 0 { return 4; };
    let m3: i64 = str_kmp("ababab", "ab");
    if vec_len(m3) != 3 { return 8; };
    if vec_get(m3, 0) != 0 { return 16; };
    if vec_get(m3, 1) != 2 { return 32; };
    if vec_get(m3, 2) != 4 { return 64; };
    return 0;
}

fn check_levenshtein() -> i64 {
    if str_levenshtein("kitten", "kitten") != 0 { return 128; };
    // Classic textbook example
    if str_levenshtein("kitten", "sitting") != 3 { return 256; };
    // Insertion-only
    if str_levenshtein("", "abc") != 3 { return 512; };
    return 0;
}

fn check_trie() -> i64 {
    let t: i64 = trie_new();
    trie_insert(t, "apple");
    trie_insert(t, "app");
    trie_insert(t, "apricot");
    trie_insert(t, "banana");
    if trie_contains(t, "apple") != 1 { trie_free(t); return 1024; };
    if trie_contains(t, "appl") != 0 { trie_free(t); return 2048; };
    if trie_starts_with(t, "appl") != 1 { trie_free(t); return 4096; };
    if trie_starts_with(t, "xyz") != 0 { trie_free(t); return 8192; };
    if trie_count_prefix(t, "ap") != 3 { trie_free(t); return 16384; };
    if trie_count_prefix(t, "apr") != 1 { trie_free(t); return 32768; };
    trie_free(t);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_kmp();
    fails = fails + check_levenshtein();
    fails = fails + check_trie();
    return fails;
}
