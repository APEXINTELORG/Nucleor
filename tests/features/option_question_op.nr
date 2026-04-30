// v0.4.225 regression-guard: `?` operator on Option<T>.
//
// Pre-fix Some(x)? early-returned the whole Option Vec instead of
// extracting x, AND None? OOB'd the length-1 None Vec at runtime
// with `vec_get OOB: index 1, len 1`. Root cause: the kind-122 ?
// lowering used a fixed `tag == 0 → err` check (the Result tag
// convention), but Option uses inverted tags: Some=0 (ok), None=1
// (err). v0.4.225 detects Option vs Result via expr_full_type_from_sym
// and dispatches to the correct err-tag sentinel.
//
// Result-side `?` was always correct (verified separately by
// tests/fixtures/t367_question_op_chain.nr).

fn safe_div(a: i32, b: i32) -> Option<i32> {
    if b == 0 { None } else { Some(a / b) }
}

fn double_safe(a: i32, b: i32) -> Option<i32> {
    let v: i32 = safe_div(a, b)?;
    Some(v * 2)
}

fn chain_three(a: i32, b: i32, c: i32) -> Option<i32> {
    let v1: i32 = safe_div(a, b)?;
    let v2: i32 = safe_div(v1, c)?;
    Some(v2 + 1)
}

fn main() -> i32 {
    // Some path: 20/4=5, doubled = 10.
    match double_safe(20, 4) {
        Some(v) => if v != 10 { print("FAIL Some(10)"); return 1; },
        None => { print("FAIL expected Some(10)"); return 1; },
    };

    // None path: 20/0 = None, propagated through ?.
    match double_safe(20, 0) {
        Some(_) => { print("FAIL expected None"); return 1; },
        None => { },
    };

    // Chained ? with all Some: 60/2=30, 30/3=10, +1 = 11.
    match chain_three(60, 2, 3) {
        Some(v) => if v != 11 { print("FAIL chain Some(11)"); return 1; },
        None => { print("FAIL chain expected Some(11)"); return 1; },
    };

    // Chained ? with first None.
    match chain_three(60, 0, 3) {
        Some(_) => { print("FAIL chain1 expected None"); return 1; },
        None => { },
    };

    // Chained ? with second None.
    match chain_three(60, 2, 0) {
        Some(_) => { print("FAIL chain2 expected None"); return 1; },
        None => { },
    };

    print("OK option_question_op");
    0
}
