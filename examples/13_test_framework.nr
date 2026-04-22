// examples/13_test_framework.nr — RFC-0021 test framework demo
// Run with: nuc test examples/13_test_framework.nr
// Or via the legacy main() entry: nuc build examples/13_test_framework.nr

#[test]
fn arithmetic_basics() {
    assert_eq(2 + 2, 4);
    assert_eq(10 * 7, 70);
    assert_eq(100 - 1, 99);
    assert_ne(1, 2);
}

#[test]
fn integer_overflow_modes() {
    // wrapping_add / checked_add etc. ship in v0.2.0 with RFC-0015
    // phase 4. For now just exercise basic arithmetic.
    let a: i64 = 1000;
    let b: i64 = 2000;
    assert_eq(a + b, 3000);
    assert_eq(b - a, 1000);
}

#[test]
fn enum_match() {
    let x: i64 = 42;
    let mut tag: i64 = 0;
    if x > 0 { tag = 1; };
    assert_eq(tag, 1);
}

#[test]
fn vec_operations() {
    let mut v: Vec<i32> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    assert_eq(v.get(0) + v.get(1) + v.get(2), 60);
}

fn main() -> i32 {
    // Standalone-execution path: run all #[test] fns sequentially.
    // `nuc test` does the same via test_harness synthesis.
    arithmetic_basics();
    integer_overflow_modes();
    enum_match();
    vec_operations();
    print("OK 13_test_framework\n");
    return 0;
}
