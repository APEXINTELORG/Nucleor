// v0.8.179 stdlib/rods/strings.nr first test coverage.
//
// String manipulation — contains, starts_with, ends_with,
// index_of, split, join, trim, to_upper/lower, replace, repeat,
// pad. Pre-v0.8.179: zero coverage on the standalone strings rod.
//
// Locks eight invariants:
//   1. contains / starts_with / ends_with truthy + falsey
//   2. index_of: present (returns position), absent (returns -1)
//   3. split: "a,b,c" by "," → 3 parts
//   4. join: ["a","b","c"] by "-" → "a-b-c"
//   5. trim: "  hi  " → "hi"
//   6. to_upper / to_lower
//   7. replace: "hello" world → "HELLO world"  (replaces all)
//   8. repeat: "ab" * 3 → "ababab"
//
// Expected: rc=0.

import "stdlib/rods/strings.nr"

fn check_contains_predicates() -> i64 {
    if strings_contains("hello world", "lo wo") != 1 { return 1; };
    if strings_contains("hello", "xyz") != 0 { return 2; };
    if strings_starts_with("hello", "hell") != 1 { return 4; };
    if strings_starts_with("hello", "world") != 0 { return 8; };
    if strings_ends_with("hello", "llo") != 1 { return 16; };
    if strings_ends_with("hello", "world") != 0 { return 32; };
    return 0;
}

fn check_index_of() -> i64 {
    if strings_index_of("hello world", "world") != 6 { return 64; };
    if strings_index_of("hello", "xyz") != 0 - 1 { return 128; };
    return 0;
}

fn check_split() -> i64 {
    let parts: Vec<i32> = strings_split("a,b,c", ",");
    if vec_len(parts) != 3 { return 256; };
    return 0;
}

fn check_join() -> i64 {
    let mut parts: Vec<i32> = Vec::new();
    parts.push("a");
    parts.push("b");
    parts.push("c");
    let s: str = strings_join(parts, "-");
    if str_eq(s, "a-b-c") != 1 { return 512; };
    return 0;
}

fn check_trim() -> i64 {
    let s: str = strings_trim("  hi  ");
    if str_eq(s, "hi") != 1 { return 1024; };
    return 0;
}

fn check_case() -> i64 {
    if str_eq(strings_to_upper("hello"), "HELLO") != 1 { return 2048; };
    if str_eq(strings_to_lower("HELLO"), "hello") != 1 { return 4096; };
    return 0;
}

fn check_replace() -> i64 {
    if str_eq(strings_replace("hello world", "hello", "HELLO"), "HELLO world") != 1 { return 8192; };
    return 0;
}

fn check_repeat() -> i64 {
    if str_eq(strings_repeat("ab", 3), "ababab") != 1 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_contains_predicates();
    fails = fails + check_index_of();
    fails = fails + check_split();
    fails = fails + check_join();
    fails = fails + check_trim();
    fails = fails + check_case();
    fails = fails + check_replace();
    fails = fails + check_repeat();
    return fails;
}
