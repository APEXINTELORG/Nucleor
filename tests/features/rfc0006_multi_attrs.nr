// RFC-0006 Design by Contract — multiple #[require(...)] and
// #[ensure(...)] attributes per fn.
//
// v0.4.250: scanner advances past the closing `]` (not past the
// fn name), so subsequent attributes preceding the same fn get
// captured in a second outer-loop iteration. lower_fn walks ALL
// matching entries in require_exprs / ensure_exprs and emits one
// contract_require / contract_ensure call per attribute.
//
// Adopters can now attach multiple preconditions and/or
// postconditions to a single fn. All preconditions are conjuncted
// (any violation panics); all postconditions are checked (any
// violation panics).
//
// EXPECT: build success, runtime exit 0, output "OK rfc0006_multi_attrs".

#[require(x > 0)]
#[require(x < 100)]
fn bounded_double(x: i64) -> i64 {
    x * 2
}

#[ensure(result >= 0)]
#[ensure(result < 10000)]
fn bounded_square(x: i64) -> i64 {
    x * x
}

#[require(n >= 0)]
#[require(n < 20)]
#[ensure(result >= 1)]
#[ensure(result < 1000000)]
fn factorial_bounded(n: i64) -> i64 {
    let mut result: i64 = 1;
    let mut i: i64 = 1;
    while i <= n {
        result = result * i;
        i = i + 1;
    };
    result
}

fn main() -> i64 {
    let a: i64 = bounded_double(50);
    if a != 100 { print("FAIL bounded_double(50)"); return 1; };

    let b: i64 = bounded_square(50);
    if b != 2500 { print("FAIL bounded_square(50)"); return 1; };

    let c: i64 = factorial_bounded(0);
    if c != 1 { print("FAIL factorial_bounded(0)"); return 1; };

    let d: i64 = factorial_bounded(5);
    if d != 120 { print("FAIL factorial_bounded(5)"); return 1; };

    print("OK rfc0006_multi_attrs");
    0
}
