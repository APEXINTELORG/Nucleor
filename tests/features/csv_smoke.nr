// v0.8.105 stdlib/rods/csv.nr — full coverage post parse_line fix.
//
// The v0.8.104 fixture documented a pre-existing bug:
// csv_parse_line emitted a trailing empty field for any line
// not ending with a comma. v0.8.105 fixes the bug in
// stdlib/rods/csv.nr (loop condition + last_was_comma tracker)
// and updates this fixture to lock the corrected behavior.
//
// Locks (post-fix):
//   1. simple line yields exactly N fields for N-comma input
//      ("alpha,beta,gamma" → 3 fields).
//   2. trailing comma yields N+1 fields with last empty
//      ("a,b," → ["a", "b", ""]).
//   3. single token yields 1 field.
//   4. quoted-field with embedded comma — quoted parse works.
//   5. escaped-quote inside quoted field: `"a""b"` → `a"b`.
//   6. csv_escape: plain field unchanged; field with comma
//      quoted; field with quote double-escaped.
//   7. format_line round-trips through parse_line.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/csv.nr"

fn check_parse_simple() -> i64 {
    let r: Vec<i32> = csv_parse_line("alpha,beta,gamma");
    if vec_len(r) != 3 { return 1; };
    if str_eq(vec_get(r, 0), "alpha") != 1 { return 2; };
    if str_eq(vec_get(r, 1), "beta") != 1 { return 4; };
    if str_eq(vec_get(r, 2), "gamma") != 1 { return 8; };
    return 0;
}

fn check_parse_trailing_comma() -> i64 {
    let r: Vec<i32> = csv_parse_line("a,b,");
    if vec_len(r) != 3 { return 16; };
    if str_eq(vec_get(r, 0), "a") != 1 { return 32; };
    if str_eq(vec_get(r, 1), "b") != 1 { return 64; };
    if str_eq(vec_get(r, 2), "") != 1 { return 128; };
    return 0;
}

fn check_parse_single() -> i64 {
    let r: Vec<i32> = csv_parse_line("only");
    if vec_len(r) != 1 { return 256; };
    if str_eq(vec_get(r, 0), "only") != 1 { return 512; };
    return 0;
}

fn check_parse_quoted_with_comma() -> i64 {
    let r: Vec<i32> = csv_parse_line("\"hello, world\",ok");
    if vec_len(r) != 2 { return 1024; };
    if str_eq(vec_get(r, 0), "hello, world") != 1 { return 2048; };
    if str_eq(vec_get(r, 1), "ok") != 1 { return 4096; };
    return 0;
}

fn check_parse_escaped_quote() -> i64 {
    // "a""b"  →  a"b
    let r: Vec<i32> = csv_parse_line("\"a\"\"b\"");
    if vec_len(r) != 1 { return 8192; };
    if str_eq(vec_get(r, 0), "a\"b") != 1 { return 16384; };
    return 0;
}

fn check_escape_plain() -> i64 {
    if str_eq(csv_escape("plain"), "plain") != 1 { return 32768; };
    return 0;
}

fn check_escape_with_comma() -> i64 {
    if str_eq(csv_escape("a,b"), "\"a,b\"") != 1 { return 65536; };
    return 0;
}

fn check_escape_with_quote() -> i64 {
    if str_eq(csv_escape("a\"b"), "\"a\"\"b\"") != 1 { return 131072; };
    return 0;
}

fn check_format_parse_round_trip() -> i64 {
    let mut fields: Vec<i32> = Vec::new();
    fields.push("alpha");
    fields.push("a,b");
    fields.push("she said \"hi\"");
    let line: str = csv_format_line(fields);
    let parsed: Vec<i32> = csv_parse_line(line);
    if vec_len(parsed) != 3 { return 262144; };
    if str_eq(vec_get(parsed, 0), "alpha") != 1 { return 524288; };
    if str_eq(vec_get(parsed, 1), "a,b") != 1 { return 1048576; };
    if str_eq(vec_get(parsed, 2), "she said \"hi\"") != 1 { return 2097152; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_parse_simple();
    fails = fails + check_parse_trailing_comma();
    fails = fails + check_parse_single();
    fails = fails + check_parse_quoted_with_comma();
    fails = fails + check_parse_escaped_quote();
    fails = fails + check_escape_plain();
    fails = fails + check_escape_with_comma();
    fails = fails + check_escape_with_quote();
    fails = fails + check_format_parse_round_trip();
    return fails;
}
