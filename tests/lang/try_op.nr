// try_op — RFC-0016 phase 1: ? postfix operator.
//
// Inner expression must be a Result<T,E> stub (Vec<i32> with [tag, payload]).
// On Err (tag 0) the function returns the entire Result early; on Ok (tag 1)
// the expression evaluates to the payload.

import "stdlib/rods/result.nr"

fn divide(a: i64, b: i64) -> Vec<i32> {
    if b == 0 { return result_err(99); };
    return result_ok(a / b);
}

// Returns Ok(a/b/c) or propagates the first divide-by-zero Err.
fn divide_chain(a: i64, b: i64, c: i64) -> Vec<i32> {
    let q1: i64 = divide(a, b)?;
    let q2: i64 = divide(q1, c)?;
    return result_ok(q2);
}

fn main() -> i64 {
    let mut fail: i64 = 0;

    // 100 / 5 / 2 = 10 — both divides ok.
    let r1: Vec<i32> = divide_chain(100, 5, 2);
    if result_is_ok(r1) != 1 { fail = fail + 1; print("FAIL chain ok tag"); };
    if result_unwrap(r1) != 10 { fail = fail + 1; print("FAIL chain ok value"); };

    // 100 / 0 — first divide errors; ? propagates.
    let r2: Vec<i32> = divide_chain(100, 0, 2);
    if result_is_err(r2) != 1 { fail = fail + 1; print("FAIL chain err1 tag"); };
    if result_unwrap_err(r2) != 99 { fail = fail + 1; print("FAIL chain err1 payload"); };

    // 100 / 5 / 0 — second divide errors; ? propagates.
    let r3: Vec<i32> = divide_chain(100, 5, 0);
    if result_is_err(r3) != 1 { fail = fail + 1; print("FAIL chain err2 tag"); };
    if result_unwrap_err(r3) != 99 { fail = fail + 1; print("FAIL chain err2 payload"); };

    if fail == 0 { print("OK try_op"); return 0; };
    return 1;
}
