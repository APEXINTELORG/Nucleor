// RFC-0001 phase 1 (v0.2.157) — `#[no_alloc]` positive case.
//
// Asserts that a fn marked #[no_alloc] which actually performs no
// allocation compiles + runs cleanly. The companion negative test
// is `tests/err/err_no_alloc_violation.nr`.

#[no_alloc]
fn add(a: i64, b: i64) -> i64 {
    return a + b;
}

#[no_alloc]
fn double(x: i64) -> i64 {
    let y: i64 = x;
    return y + y;
}

fn main() -> i64 {
    let s: i64 = add(2, 3);
    let d: i64 = double(7);
    if s != 5 { print("FAIL add"); return 1; };
    if d != 14 { print("FAIL double"); return 1; };
    print("OK no_alloc_clean");
    return 0;
}
