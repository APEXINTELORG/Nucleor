// =====================================================
// rods/hashmap_str — HashMap<str, i64> (RFC-0017 phase 2)
// =====================================================
// Import: import "stdlib/rods/hashmap_str.nr"
//
// String-keyed open-addressed hash table with FNV-1a 64-bit hash and
// linear probing. Doubles capacity at 50% load factor. Production-grade
// error handling: missing-key returns 0 (use hms_contains to disambiguate).
//
// For non-string keys, see the existing `hashmap.nr` rod which uses
// nuc_map_* runtime with i64 keys.
// =====================================================

// ---- Constructors ----
fn hms_new() -> i64 { return hashmap_new(); }
fn hms_with_capacity(n: i64) -> i64 { return hashmap_with_capacity(n); }

// ---- Mutation ----
fn hms_insert(m: i64, k: str, v: i64) -> i64 { return hashmap_insert(m, k, v); }
fn hms_remove(m: i64, k: str) -> i64 { return hashmap_remove(m, k); }
fn hms_clear(m: i64) -> i64 { return hashmap_clear(m); }

// ---- Access ----
fn hms_get(m: i64, k: str) -> i64 { return hashmap_get(m, k); }
fn hms_contains(m: i64, k: str) -> i64 { return hashmap_contains(m, k); }

// ---- Default-value accessors ----
fn hms_get_or(m: i64, k: str, default: i64) -> i64 {
    if hashmap_contains(m, k) == 1 { return hashmap_get(m, k); };
    return default;
}

// ---- Metadata ----
fn hms_len(m: i64) -> i64 { return hashmap_len(m); }
fn hms_capacity(m: i64) -> i64 { return hashmap_capacity(m); }
fn hms_is_empty(m: i64) -> i64 {
    if hashmap_len(m) == 0 { return 1; };
    return 0;
}

// ---- Lifecycle ----
fn hms_free(m: i64) -> i64 { return hashmap_free(m); }
