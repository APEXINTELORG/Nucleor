// =====================================================
// rods/string_type — Heap-allocated String type (RFC-0017)
// =====================================================
// Import: import "stdlib/rods/string_type.nr"
//
// This rod wraps the v0.1.27 String runtime: a growable, heap-allocated,
// length-tracked, UTF-8 byte buffer. Distinct from `str` which is a
// borrowed view into static or owned storage.
//
// Use String when you need:
//   - mutation (push, push_str, clear)
//   - dynamic concatenation
//   - owned ownership semantics for crossing function boundaries
//
// Use str when you need:
//   - immutable views
//   - zero-allocation inspection
//   - interop with str_concat / str_substring / str_eq builtins
//
// Generic-monomorphization in v0.4 RFC-0024 will introduce
// `String<A: Allocator>` so users can pick the allocator (Arena/Pool/
// TLSF/Global) per RFC-0002.
// =====================================================

// ---- Constructors ----
fn string_make() -> i64 { return string_new(); }
fn string_with_cap(n: i64) -> i64 { return string_with_capacity(n); }
fn string_of(s: str) -> i64 { return string_from_str(s); }

// ---- Mutation ----
fn string_push_byte_v(s: i64, b: i64) -> i64 { return string_push_byte(s, b); }
fn string_concat_str(s: i64, addition: str) -> i64 { return string_push_str(s, addition); }
fn string_reset(s: i64) -> i64 { return string_clear(s); }

// ---- Access ----
fn string_length(s: i64) -> i64 { return string_len(s); }
fn string_byte_at(s: i64, i: i64) -> i64 { return string_get_byte(s, i); }
fn string_cstr(s: i64) -> i64 { return string_as_ptr(s); }

// ---- Predicates ----
fn string_equals(a: i64, b: i64) -> i64 { return string_eq(a, b); }
fn string_equals_str(s: i64, lit: str) -> i64 { return string_eq_str(s, lit); }
fn string_has_prefix(s: i64, prefix: str) -> i64 { return string_starts_with(s, prefix); }
fn string_has_suffix(s: i64, suffix: str) -> i64 { return string_ends_with(s, suffix); }
fn string_has_substr(s: i64, needle: str) -> i64 { return string_contains(s, needle); }

// ---- Lifecycle ----
fn string_copy(s: i64) -> i64 { return string_clone(s); }
fn string_drop(s: i64) -> i64 { return string_free(s); }
