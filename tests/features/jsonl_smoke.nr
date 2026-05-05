// v0.8.208 stdlib/rods/jsonl.nr first test coverage.
//
// JSONL evidence-emit rod (NUC-IMPROVE-003). Emitters write
// to stdout; the testable surface is `jsonl_quote` which is
// pure (no IO). Pre-v0.8.208: zero coverage on the standalone
// rod.
//
// Locks four jsonl_quote escaping invariants — Python parity
// runners parse via json.loads and break on bad escaping:
//
//   1. **Plain ASCII** — quote("hi") == "\"hi\"".
//   2. **Backslash escape** — quote("a\\b") writes \\ (two
//      backslashes in the JSON output).
//   3. **Double-quote escape** — quote("a\"b") writes \".
//   4. **Newline escape** — quote with embedded \n writes \\n
//      (visible escape, not raw newline).
//
// Expected: rc=0.

import "stdlib/rods/jsonl.nr"

fn check_plain_ascii() -> i64 {
    if str_eq(jsonl_quote("hi"), "\"hi\"") != 1 { return 1; };
    return 0;
}

fn check_backslash_escape() -> i64 {
    // input: a\b → output: "a\\b" (with the \\ being an escaped
    // backslash in the JSON output)
    if str_eq(jsonl_quote("a\\b"), "\"a\\\\b\"") != 1 { return 2; };
    return 0;
}

fn check_quote_escape() -> i64 {
    // input: a"b → output: "a\"b"
    if str_eq(jsonl_quote("a\"b"), "\"a\\\"b\"") != 1 { return 4; };
    return 0;
}

fn check_newline_escape() -> i64 {
    // input: a<newline>b → output: "a\nb" (visible \n escape, not raw newline)
    if str_eq(jsonl_quote("a\nb"), "\"a\\nb\"") != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_plain_ascii();
    fails = fails + check_backslash_escape();
    fails = fails + check_quote_escape();
    fails = fails + check_newline_escape();
    return fails;
}
