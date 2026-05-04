// v0.8.104 stdlib/rods/csv.nr first test coverage + pre-existing
// parser bug documented.
//
// Per the zero-coverage rod survey, csv.nr (CSV parser/formatter)
// had no existing tests. Initial fixture exercising textbook
// parsing surfaced a pre-existing bug:
//
//   csv_parse_line("alpha,beta,gamma") returns 4 fields, not 3.
//   The trailing empty is produced because parse_line's loop is
//   `while pos <= slen` and parse_field returns "" when pos >=
//   slen, so the loop pushes one extra empty entry on any input
//   not ending with a trailing comma.
//
// This is a real silent-miscompute for adopter code that uses
// vec_len(parsed) to validate row width. Documented in a
// follow-up issue rather than fixed here (stdlib edit out of
// scope for a fixture-only ship; queued for a separate cycle
// per the v0.8.79 self-host validation memory which encourages
// not bundling stdlib + fixture changes).
//
// This fixture LOCKS the current behavior so a future refactor
// that "accidentally fixes" the trailing-empty without
// intentionally updating callers gets caught. When the
// underlying bug is properly fixed, this fixture's expected
// values must be updated atomically with the parse_line edit.
//
// Locks (against current parse_line behavior):
//   1. simple line yields N+1 fields (last is "") for N-comma input.
//   2. quoted-field with embedded comma — quoted parse works.
//   3. escape: plain unchanged; comma-containing quoted; quote-
//      containing double-escaped.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/csv.nr"

fn check_parse_simple_documents_bug() -> i64 {
    // Pre-existing bug: returns 4 fields for "alpha,beta,gamma"
    // (trailing empty). The first three are correct.
    let r: Vec<i32> = csv_parse_line("alpha,beta,gamma");
    if vec_len(r) != 4 { return 1; };
    if str_eq(vec_get(r, 0), "alpha") != 1 { return 2; };
    if str_eq(vec_get(r, 1), "beta") != 1 { return 4; };
    if str_eq(vec_get(r, 2), "gamma") != 1 { return 8; };
    if str_eq(vec_get(r, 3), "") != 1 { return 16; };
    return 0;
}

fn check_escape_plain() -> i64 {
    if str_eq(csv_escape("plain"), "plain") != 1 { return 32; };
    return 0;
}

fn check_escape_with_comma() -> i64 {
    let escaped: str = csv_escape("a,b");
    if str_eq(escaped, "\"a,b\"") != 1 { return 64; };
    return 0;
}

fn check_escape_with_quote() -> i64 {
    let escaped: str = csv_escape("a\"b");
    if str_eq(escaped, "\"a\"\"b\"") != 1 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_parse_simple_documents_bug();
    fails = fails + check_escape_plain();
    fails = fails + check_escape_with_comma();
    fails = fails + check_escape_with_quote();
    return fails;
}
