// =====================================================
// rods/hashset — HashSet<str> (RFC-0017 phase 4)
// =====================================================
// Import: import "stdlib/rods/hashset.nr"
//
// String set built atop HashMap<str, 1>. O(1) average insert/contains/
// remove. For ordered iteration use BTreeSet (rods/btreeset.nr).
// =====================================================

fn hss_new() -> i64 { return hashset_new(); }
fn hss_with_capacity(n: i64) -> i64 { return hashset_with_capacity(n); }

fn hss_insert(s: i64, k: str) -> i64 { return hashset_insert(s, k); }
fn hss_remove(s: i64, k: str) -> i64 { return hashset_remove(s, k); }
fn hss_clear(s: i64) -> i64 { return hashset_clear(s); }

fn hss_contains(s: i64, k: str) -> i64 { return hashset_contains(s, k); }
fn hss_len(s: i64) -> i64 { return hashset_len(s); }
fn hss_is_empty(s: i64) -> i64 {
    if hashset_len(s) == 0 { return 1; };
    return 0;
}

fn hss_free(s: i64) -> i64 { return hashset_free(s); }
