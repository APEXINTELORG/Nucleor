// v0.3.0 (T3.1) smoke: #[deadline = N] runtime checks.
// Each fn annotated with `#[deadline = N]` (microseconds) is
// wrapped at compile time:
//   - body renamed to __nuc_dl_inner_<id>
//   - new outer fn captures start time, calls inner, calls
//     deadline_check(start, N), returns inner's result
// On overrun, the runtime aborts with `error[RT-004]` to stderr
// and exit 1. Pass cases (fn finishes within budget) work
// transparently — same return value, same observable behavior.

#[deadline = 100000]
fn fast_add(a: i64, b: i64) -> i64 {
    return a + b;
}

#[deadline = 100000]
fn fast_mul(a: i64, b: i64) -> i64 {
    return a * b;
}

#[deadline = 100000]
fn fast_no_args() -> i64 {
    return 42;
}

#[deadline = 100000]
fn fast_chained(n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < 100 {
        acc = acc + i;
        i = i + 1;
    };
    return acc + n;
}

#[test]
fn test_deadline_pass_simple_add() {
    // 100 ms budget, simple add — passes trivially.
    assert_eq(fast_add(10, 20), 30);
}

#[test]
fn test_deadline_pass_simple_mul() {
    assert_eq(fast_mul(7, 6), 42);
}

#[test]
fn test_deadline_pass_no_args() {
    assert_eq(fast_no_args(), 42);
}

#[test]
fn test_deadline_pass_with_loop() {
    // 100-iteration loop + add — well within 100 ms.
    // Sum of 0..99 = 4950, plus n = 4950 + 5 = 4955.
    assert_eq(fast_chained(5), 4955);
}
