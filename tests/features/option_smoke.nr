// v0.8.217 stdlib/rods/option.nr first test coverage.
//
// Option<T> type (Some/None) — v0.1 stub via Vec<i32> tag union;
// full RFC-0016 compiler-integrated `Option<T>` ships in v0.2.
// Pre-v0.8.217: zero coverage on the standalone rod.
//
// Locks four invariants that Phase B compiler ADT must NOT
// regress when it replaces this stub:
//
//   1. **Tag stability** — Some=1, None=0 (wire format).
//   2. **Predicates** — is_some(Some(x)) = 1, is_none(Some(x)) = 0;
//      is_some(None) = 0, is_none(None) = 1.
//   3. **unwrap_or default** — None.unwrap_or(99) = 99;
//      Some(7).unwrap_or(99) = 7.
//   4. **unwrap on Some returns payload** — option_unwrap(Some(42)) = 42.
//
// Expected: rc=0.

import "stdlib/rods/option.nr"

fn check_tags() -> i64 {
    let s: Vec<i32> = option_some(42);
    let n: Vec<i32> = option_none();
    if option_get_tag(s) != 1 { return 1; };
    if option_get_tag(n) != 0 { return 2; };
    return 0;
}

fn check_predicates() -> i64 {
    let s: Vec<i32> = option_some(42);
    let n: Vec<i32> = option_none();
    if option_is_some(s) != 1 { return 4; };
    if option_is_none(s) != 0 { return 8; };
    if option_is_some(n) != 0 { return 16; };
    if option_is_none(n) != 1 { return 32; };
    return 0;
}

fn check_unwrap_or() -> i64 {
    let s: Vec<i32> = option_some(7);
    let n: Vec<i32> = option_none();
    if option_unwrap_or(s, 99) != 7 { return 64; };
    if option_unwrap_or(n, 99) != 99 { return 128; };
    return 0;
}

fn check_unwrap_some() -> i64 {
    let s: Vec<i32> = option_some(42);
    if option_unwrap(s) != 42 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_tags();
    fails = fails + check_predicates();
    fails = fails + check_unwrap_or();
    fails = fails + check_unwrap_some();
    return fails;
}
