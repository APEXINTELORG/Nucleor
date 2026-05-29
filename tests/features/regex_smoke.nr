// v0.8.194 stdlib/rods/regex.nr first test coverage.
//
// Simple pattern matching: digit / alpha / any / literal +
// pattern-driven find_first with `\d` `\a` `.` escapes.
// Pre-v0.8.194: zero coverage.
//
// Locks five textbook regex invariants:
//   1. Digit predicate: `'5'` matches; `'a'` doesn't.
//   2. Alpha predicate: `'a'/'Z'` match; `'5'` doesn't.
//   3. Literal match: `regex_match_literal("hello", 1, "ello")`
//      → 1; mismatched literal → 0.
//   4. find_first with `\d`: `"abc123"` × `"\d"` → 3 (first digit).
//   5. find_first with literal: `"abcabc"` × `"bca"` → 1.
//
// Expected: rc=0.

import "stdlib/rods/regex.nr"

fn check_digit_predicate() -> i64 {
    if regex_match_digit("5", 0) != 1 { return 1; };
    if regex_match_digit("a", 0) != 0 { return 2; };
    if regex_match_digit("9", 0) != 1 { return 4; };
    if regex_match_digit("0", 0) != 1 { return 8; };
    return 0;
}

fn check_alpha_predicate() -> i64 {
    if regex_match_alpha("a", 0) != 1 { return 16; };
    if regex_match_alpha("Z", 0) != 1 { return 32; };
    if regex_match_alpha("5", 0) != 0 { return 64; };
    if regex_match_alpha(".", 0) != 0 { return 128; };
    return 0;
}

fn check_literal_match() -> i64 {
    if regex_match_literal("hello", 1, "ello") != 1 { return 256; };
    if regex_match_literal("hello", 0, "world") != 0 { return 512; };
    return 0;
}

fn check_find_first_digit() -> i64 {
    if regex_find_first("abc123", "\\d") != 3 { return 1024; };
    if regex_find_first("hello", "\\d") != 0 - 1 { return 2048; };
    return 0;
}

fn check_find_first_literal() -> i64 {
    if regex_find_first("abcabc", "bca") != 1 { return 4096; };
    if regex_find_first("hello", "xyz") != 0 - 1 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_digit_predicate();
    fails = fails + check_alpha_predicate();
    fails = fails + check_literal_match();
    fails = fails + check_find_first_digit();
    fails = fails + check_find_first_literal();
    return fails;
}
