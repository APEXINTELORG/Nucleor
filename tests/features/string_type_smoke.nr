// v0.8.178 stdlib/rods/string_type.nr first test coverage.
//
// Heap-allocated String type (RFC-0017) — growable, length-
// tracked UTF-8 byte buffer. Distinct from `str` (immutable
// view). Pre-v0.8.178: zero coverage on the wrapper rod.
//
// Locks five textbook String invariants:
//   1. **Empty**: `string_make()` → length 0.
//   2. **Make-from-str**: `string_of("hello")` → length 5.
//   3. **Concat str literal**: `make` + push("hi") → length 2,
//      equals_str("hi").
//   4. **Push byte**: empty string + push_byte('A'=65) →
//      length 1, byte_at(0)==65.
//   5. **Predicate (has_prefix)**: `string_of("hello world")`
//      has_prefix("hello") == 1; has_prefix("xyz") == 0.
//
// Expected: rc=0.

import "stdlib/rods/string_type.nr"

fn check_empty() -> i64 {
    let s: i64 = string_make();
    if string_length(s) != 0 { string_drop(s); return 1; };
    string_drop(s);
    return 0;
}

fn check_make_from_str() -> i64 {
    let s: i64 = string_of("hello");
    if string_length(s) != 5 { string_drop(s); return 2; };
    if string_equals_str(s, "hello") != 1 { string_drop(s); return 4; };
    string_drop(s);
    return 0;
}

fn check_concat_str_literal() -> i64 {
    let s: i64 = string_make();
    string_concat_str(s, "hi");
    if string_length(s) != 2 { string_drop(s); return 8; };
    if string_equals_str(s, "hi") != 1 { string_drop(s); return 16; };
    string_drop(s);
    return 0;
}

fn check_push_byte() -> i64 {
    let s: i64 = string_make();
    string_push_byte_v(s, 65); // 'A'
    if string_length(s) != 1 { string_drop(s); return 32; };
    if string_byte_at(s, 0) != 65 { string_drop(s); return 64; };
    string_drop(s);
    return 0;
}

fn check_predicates() -> i64 {
    let s: i64 = string_of("hello world");
    if string_has_prefix(s, "hello") != 1 { string_drop(s); return 128; };
    if string_has_prefix(s, "xyz") != 0 { string_drop(s); return 256; };
    if string_has_suffix(s, "world") != 1 { string_drop(s); return 512; };
    if string_has_substr(s, "lo wo") != 1 { string_drop(s); return 1024; };
    string_drop(s);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_make_from_str();
    fails = fails + check_concat_str_literal();
    fails = fails + check_push_byte();
    fails = fails + check_predicates();
    return fails;
}
