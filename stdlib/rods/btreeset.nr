// =====================================================
// rods/btreeset — BTreeSet<str> (RFC-0017 phase 3)
// =====================================================
// Import: import "stdlib/rods/btreeset.nr"
//
// String-keyed ordered set, built atop BTreeMap. Iteration yields
// sorted order via at(pos).
// =====================================================

fn bts_new() -> i64 { return btreeset_new(); }

fn bts_insert(s: i64, k: str) -> i64 { return btreeset_insert(s, k); }
fn bts_remove(s: i64, k: str) -> i64 { return btreeset_remove(s, k); }
fn bts_clear(s: i64) -> i64 { return btreeset_clear(s); }

fn bts_contains(s: i64, k: str) -> i64 { return btreeset_contains(s, k); }
fn bts_len(s: i64) -> i64 { return btreeset_len(s); }
fn bts_is_empty(s: i64) -> i64 {
    if btreeset_len(s) == 0 { return 1; };
    return 0;
}

// Sorted iteration
fn bts_at(s: i64, pos: i64) -> i64 { return btreeset_at(s, pos); }

fn bts_free(s: i64) -> i64 { return btreeset_free(s); }
