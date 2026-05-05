// v0.8.205 stdlib/rods/hashset.nr first test coverage.
//
// HashSet<str> on top of HashMap<str, 1> (RFC-0017 phase 4).
// Pre-v0.8.205: zero coverage on the standalone rod.
//
// Locks four set-semantics invariants:
//
//   1. **Empty set** — hss_new() → len 0, is_empty 1.
//   2. **Insert tracks contains** — insert "alpha", contains
//      returns 1; non-inserted "beta" returns 0.
//   3. **Duplicate insert is no-op** — inserting "x" twice
//      leaves len == 1 (set semantics).
//   4. **Remove flips contains** — insert+remove → contains 0.
//
// Expected: rc=0.

import "stdlib/rods/hashset.nr"

fn check_empty() -> i64 {
    let s: i64 = hss_new();
    if hss_len(s) != 0 { hss_free(s); return 1; };
    if hss_is_empty(s) != 1 { hss_free(s); return 2; };
    hss_free(s);
    return 0;
}

fn check_insert_contains() -> i64 {
    let s: i64 = hss_new();
    hss_insert(s, "alpha");
    if hss_contains(s, "alpha") != 1 { hss_free(s); return 4; };
    if hss_contains(s, "beta") != 0 { hss_free(s); return 8; };
    hss_free(s);
    return 0;
}

fn check_duplicate_noop() -> i64 {
    let s: i64 = hss_new();
    hss_insert(s, "x");
    hss_insert(s, "x");
    if hss_len(s) != 1 { hss_free(s); return 16; };
    hss_free(s);
    return 0;
}

fn check_remove_flips_contains() -> i64 {
    let s: i64 = hss_new();
    hss_insert(s, "key");
    hss_remove(s, "key");
    if hss_contains(s, "key") != 0 { hss_free(s); return 32; };
    if hss_len(s) != 0 { hss_free(s); return 64; };
    hss_free(s);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_contains();
    fails = fails + check_duplicate_noop();
    fails = fails + check_remove_flips_contains();
    return fails;
}
