// v0.8.194 stdlib/rods/result.nr first test coverage.
//
// Result<T, E> tag-union (1=Ok, 0=Err). Pre-v0.8.194: zero
// coverage on the rod itself.
//
// Locks five invariants:
//   1. Ok constructor + predicate: ok(42) → is_ok=1, is_err=0.
//   2. Err constructor + predicate: err(99) → is_ok=0, is_err=1.
//   3. unwrap_or default: Err → default; Ok → payload.
//   4. unwrap on Ok returns payload.
//   5. to_option: Ok(42) → Some(42); Err(_) → None.
//
// Expected: rc=0.

import "stdlib/rods/result.nr"

fn check_ok() -> i64 {
    let r: Vec<i32> = result_ok(42);
    if result_is_ok(r) != 1 { return 1; };
    if result_is_err(r) != 0 { return 2; };
    if result_get_tag(r) != 1 { return 4; };
    if result_get_payload(r) != 42 { return 8; };
    return 0;
}

fn check_err() -> i64 {
    let r: Vec<i32> = result_err(99);
    if result_is_ok(r) != 0 { return 16; };
    if result_is_err(r) != 1 { return 32; };
    if result_get_tag(r) != 0 { return 64; };
    if result_get_payload(r) != 99 { return 128; };
    return 0;
}

fn check_unwrap_or() -> i64 {
    let ok: Vec<i32> = result_ok(7);
    if result_unwrap_or(ok, 100) != 7 { return 256; };
    let err: Vec<i32> = result_err(0);
    if result_unwrap_or(err, 100) != 100 { return 512; };
    return 0;
}

fn check_unwrap() -> i64 {
    let ok: Vec<i32> = result_ok(123);
    if result_unwrap(ok) != 123 { return 1024; };
    return 0;
}

fn check_to_option() -> i64 {
    let ok: Vec<i32> = result_ok(42);
    let some: Vec<i32> = result_to_option(ok);
    if some.get(0) != 1 { return 2048; };
    if some.get(1) != 42 { return 4096; };
    let err: Vec<i32> = result_err(99);
    let none: Vec<i32> = result_to_option(err);
    if none.get(0) != 0 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_ok();
    fails = fails + check_err();
    fails = fails + check_unwrap_or();
    fails = fails + check_unwrap();
    fails = fails + check_to_option();
    return fails;
}
