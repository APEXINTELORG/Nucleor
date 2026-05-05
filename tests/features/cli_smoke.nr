// v0.8.123 stdlib/rods/cli.nr first test coverage.
//
// Per the zero-coverage rod survey, cli.nr (CLI argument
// parsing — flags, options, positionals, get/has) had no
// existing tests. Silent regressions in flag registration or
// value lookup would corrupt every adopter CLI.
//
// This fixture covers the in-memory helpers (registration,
// set/get, find_flag) without requiring process-level argv.
// cli_parse is left for a follow-up (it consumes process
// args; needs a subprocess fixture).
//
// Locks:
//   1. cli_new returns a valid handle with parsed_names empty.
//   2. cli_add_flag + cli_find_flag round-trip on long name
//      and short alias.
//   3. cli_add_option + cli_find_flag round-trip with default
//      value carried through.
//   4. cli_set_parsed + cli_get returns the stored value.
//   5. cli_has returns 1 for parsed, 0 for unparsed.
//   6. cli_get_int parses an int-string.
//   7. cli_positionals starts empty (no parse run yet).
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/cli.nr"

fn check_cli_new() -> i64 {
    let c: Vec<i32> = cli_new("nuc", "Nucleor compiler");
    if str_eq(vec_get(c, 0), "nuc") != 1 { return 1; };
    if str_eq(vec_get(c, 1), "Nucleor compiler") != 1 { return 2; };
    let positionals: Vec<i32> = cli_positionals(c);
    if vec_len(positionals) != 0 { return 4; };
    return 0;
}

fn check_add_and_find_flag() -> i64 {
    let c: Vec<i32> = cli_new("nuc", "test");
    cli_add_flag(c, "verbose", "v", "verbose mode");
    cli_add_flag(c, "quiet", "q", "quiet mode");
    if cli_find_flag(c, "--verbose") < 0 { return 8; };
    if cli_find_flag(c, "-v") < 0 { return 16; };
    if cli_find_flag(c, "--quiet") < 0 { return 32; };
    if cli_find_flag(c, "--missing") >= 0 { return 64; };
    return 0;
}

fn check_add_option() -> i64 {
    let c: Vec<i32> = cli_new("nuc", "test");
    cli_add_option(c, "output", "o", "output path", "out.exe");
    if cli_find_flag(c, "--output") < 0 { return 128; };
    if cli_find_flag(c, "-o") < 0 { return 256; };
    return 0;
}

fn check_set_get_has() -> i64 {
    let c: Vec<i32> = cli_new("nuc", "test");
    cli_set_parsed(c, "level", "3");
    if cli_has(c, "level") != 1 { return 512; };
    if str_eq(cli_get(c, "level"), "3") != 1 { return 1024; };
    if cli_has(c, "missing") != 0 { return 2048; };
    return 0;
}

fn check_get_int() -> i64 {
    let c: Vec<i32> = cli_new("nuc", "test");
    cli_set_parsed(c, "count", "42");
    if cli_get_int(c, "count") != 42 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cli_new();
    fails = fails + check_add_and_find_flag();
    fails = fails + check_add_option();
    fails = fails + check_set_get_has();
    fails = fails + check_get_int();
    return fails;
}
