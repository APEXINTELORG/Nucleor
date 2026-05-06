// R06 Phase 2c — broader rust_bridge string-return ownership repeat fixture.
//
// The original rust_bridge_string_free_smoke.nr covers the reclaim path through
// rust_to_uppercase and rust_regex_find. This fixture covers all seven
// string-returning Rust bridge functions that transfer CString::into_raw()
// ownership to the caller and must be paired with rust_free_str.
//
// Expected: rc=0.

import "stdlib/rods/rust.nr"

fn check_regex_find() -> i64 {
    let s: str = rust_regex_find("[0-9]+", "abc 42 def");
    if str_eq(s, "42") != 1 { return 1; };
    rust_free_str(s);
    return 0;
}

fn check_regex_replace_all() -> i64 {
    let s: str = rust_regex_replace_all("[0-9]+", "abc 42 def", "N");
    if str_eq(s, "abc N def") != 1 { return 2; };
    rust_free_str(s);
    return 0;
}

fn check_sort_ints() -> i64 {
    let s: str = rust_sort_ints("3,1,2");
    if str_eq(s, "1,2,3") != 1 { return 4; };
    rust_free_str(s);
    return 0;
}

fn check_sort_strings() -> i64 {
    let s: str = rust_sort_strings("pear,apple,banana");
    if str_eq(s, "apple,banana,pear") != 1 { return 8; };
    rust_free_str(s);
    return 0;
}

fn check_uppercase() -> i64 {
    let s: str = rust_to_uppercase("hello");
    if str_eq(s, "HELLO") != 1 { return 16; };
    rust_free_str(s);
    return 0;
}

fn check_base64_encode() -> i64 {
    let s: str = rust_base64_encode("hello");
    if str_eq(s, "aGVsbG8=") != 1 { return 32; };
    rust_free_str(s);
    return 0;
}

fn check_base64_decode() -> i64 {
    let s: str = rust_base64_decode("aGVsbG8=");
    if str_eq(s, "hello") != 1 { return 64; };
    rust_free_str(s);
    return 0;
}

fn check_all_string_returns_once() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_regex_find();
    fails = fails + check_regex_replace_all();
    fails = fails + check_sort_ints();
    fails = fails + check_sort_strings();
    fails = fails + check_uppercase();
    fails = fails + check_base64_encode();
    fails = fails + check_base64_decode();
    return fails;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    let mut i: i64 = 0;
    while i < 100 {
        fails = fails + check_all_string_returns_once();
        i = i + 1;
    };
    return fails;
}
