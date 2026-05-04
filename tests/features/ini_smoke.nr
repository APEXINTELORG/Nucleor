// v0.8.103 stdlib/rods/ini.nr first test coverage.
//
// Per the zero-coverage rod survey, ini.nr (INI config parser
// — sections, comments, key=value) had no existing tests.
// Silent regressions in line-type classification or value
// trimming would propagate into adopter config-loading code
// invisibly.
//
// Locks INI parser invariants:
//   1. ini_is_comment: ; and # comment markers detected with
//      and without leading whitespace.
//   2. ini_is_section: [section] detected; [bad pattern fails.
//   3. ini_parse_line: empty / comment / section / key=value
//      classification, with trimmed names + values.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/ini.nr"

fn check_is_comment() -> i64 {
    if ini_is_comment("; this is a comment") != 1 { return 1; };
    if ini_is_comment("# also a comment") != 1 { return 2; };
    if ini_is_comment("    ; indented comment") != 1 { return 4; };
    if ini_is_comment("key=value") != 0 { return 8; };
    if ini_is_comment("[section]") != 0 { return 16; };
    if ini_is_comment("") != 0 { return 32; };
    return 0;
}

fn check_is_section() -> i64 {
    if ini_is_section("[main]") != 1 { return 64; };
    if ini_is_section("  [main]  ") != 1 { return 128; };
    if ini_is_section("[no closing") != 0 { return 256; };
    if ini_is_section("not a section") != 0 { return 512; };
    if ini_is_section("; comment") != 0 { return 1024; };
    return 0;
}

fn check_parse_empty() -> i64 {
    let r: Vec<i32> = ini_parse_line("");
    if vec_get(r, 0) != 0 { return 2048; };
    return 0;
}

fn check_parse_comment() -> i64 {
    let r: Vec<i32> = ini_parse_line("; hello");
    if vec_get(r, 0) != 1 { return 4096; };
    return 0;
}

fn check_parse_section() -> i64 {
    let r: Vec<i32> = ini_parse_line("[server]");
    if vec_get(r, 0) != 2 { return 8192; };
    if str_eq(vec_get(r, 1), "server") != 1 { return 16384; };
    // Whitespace inside brackets is trimmed.
    let r2: Vec<i32> = ini_parse_line("[ server ]");
    if vec_get(r2, 0) != 2 { return 32768; };
    if str_eq(vec_get(r2, 1), "server") != 1 { return 65536; };
    return 0;
}

fn check_parse_kv() -> i64 {
    let r: Vec<i32> = ini_parse_line("port = 8080");
    if vec_get(r, 0) != 3 { return 131072; };
    if str_eq(vec_get(r, 1), "port") != 1 { return 262144; };
    if str_eq(vec_get(r, 2), "8080") != 1 { return 524288; };
    // No spaces around =.
    let r2: Vec<i32> = ini_parse_line("name=alice");
    if vec_get(r2, 0) != 3 { return 1048576; };
    if str_eq(vec_get(r2, 1), "name") != 1 { return 2097152; };
    if str_eq(vec_get(r2, 2), "alice") != 1 { return 4194304; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_is_comment();
    fails = fails + check_is_section();
    fails = fails + check_parse_empty();
    fails = fails + check_parse_comment();
    fails = fails + check_parse_section();
    fails = fails + check_parse_kv();
    return fails;
}
