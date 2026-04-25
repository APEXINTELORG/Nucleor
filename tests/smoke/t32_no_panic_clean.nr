// T3.2 (v0.3.1) smoke: #[no_panic] passes when the body has
// no panic-prone calls. Mirrors the existing #[no_alloc]
// source-level v1 check pattern. RT-002 fires when forbidden
// calls (panic, assert_eq, assert_ne, unwrap, expect) appear
// inside a #[no_panic] fn — see tests/err/err_no_panic_violation.nr
// for the negative case.

#[no_panic]
fn safe_add(a: i64, b: i64) -> i64 {
    return a + b;
}

#[no_panic]
fn safe_loop(n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        acc = acc + i;
        i = i + 1;
    };
    return acc;
}

#[test]
fn test_no_panic_pure_arithmetic() {
    assert_eq(safe_add(10, 20), 30);
}

#[test]
fn test_no_panic_loop_with_arithmetic() {
    // 0 + 1 + 2 + 3 + 4 = 10
    assert_eq(safe_loop(5), 10);
}
