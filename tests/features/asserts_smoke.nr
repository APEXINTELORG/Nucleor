// v0.8.137 stdlib/rods/asserts.nr first test coverage.
//
// RFC-0021 assertion + debug wrappers. Pre-v0.8.137 the rod
// shipped with no fixture.
//
// Locks: passing assertions (cond=true / a==b / a!=b) do NOT
// abort the program, debug helpers return their argument
// untouched, and the convenience `check_with(true, _)` returns 0.
//
// Failing assertions panic and are out of scope for a smoke
// fixture (would terminate the process); negative-path is
// covered by the language test-suite for the underlying
// `__nucleor_assert*` builtins.
//
// Expected: rc=0.

import "stdlib/rods/asserts.nr"

fn check_passing_check() -> i64 {
    let r: i64 = check(1);
    if r != 0 { return 1; };
    return 0;
}

fn check_passing_eq() -> i64 {
    let r: i64 = check_eq(42, 42);
    if r != 0 { return 2; };
    return 0;
}

fn check_passing_ne() -> i64 {
    let r: i64 = check_ne(1, 2);
    if r != 0 { return 4; };
    return 0;
}

fn check_dbg_passthrough() -> i64 {
    // dbg(v) returns v untouched.
    let r: i64 = debug_int(99);
    if r != 99 { return 8; };
    return 0;
}

fn check_with_true() -> i64 {
    let r: i64 = check_with(1, "should not panic");
    if r != 0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_passing_check();
    fails = fails + check_passing_eq();
    fails = fails + check_passing_ne();
    fails = fails + check_dbg_passthrough();
    fails = fails + check_with_true();
    return fails;
}
