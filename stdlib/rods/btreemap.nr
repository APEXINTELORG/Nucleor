// =====================================================
// rods/btreemap — BTreeMap<str, i64> (RFC-0017 phase 3)
// =====================================================
// Import: import "stdlib/rods/btreemap.nr"
//
// String-keyed ordered associative map. Keys stored sorted; iteration
// via key_at(pos)/val_at(pos) yields sorted order. O(log n) lookup,
// O(n) insert (linear shift). Real B-tree (O(log n) insert) lands in
// v0.4 RFC-0017 full impl with shape-stable API.
//
// Use BTreeMap when you need:
//   - deterministic iteration order (replay debugging, reproducible builds)
//   - sorted-range scans (forthcoming)
// Use HashMap when you need raw speed without ordering.
// =====================================================

fn btm_new() -> i64 { return btreemap_new(); }

fn btm_insert(m: i64, k: str, v: i64) -> i64 { return btreemap_insert(m, k, v); }
fn btm_remove(m: i64, k: str) -> i64 { return btreemap_remove(m, k); }
fn btm_clear(m: i64) -> i64 { return btreemap_clear(m); }

fn btm_get(m: i64, k: str) -> i64 { return btreemap_get(m, k); }
fn btm_contains(m: i64, k: str) -> i64 { return btreemap_contains(m, k); }

fn btm_get_or(m: i64, k: str, default: i64) -> i64 {
    if btreemap_contains(m, k) == 1 { return btreemap_get(m, k); };
    return default;
}

fn btm_len(m: i64) -> i64 { return btreemap_len(m); }
fn btm_is_empty(m: i64) -> i64 {
    if btreemap_len(m) == 0 { return 1; };
    return 0;
}

// Ordered iteration — positions yield sorted-key order.
fn btm_key_at(m: i64, pos: i64) -> i64 { return btreemap_key_at(m, pos); }
fn btm_val_at(m: i64, pos: i64) -> i64 { return btreemap_val_at(m, pos); }

fn btm_free(m: i64) -> i64 { return btreemap_free(m); }
