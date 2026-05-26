// closure_capture_nested.nr — inner closure captures from outer closure's scope.

fn make_outer(a: i64) -> i64 {
    let outer: i64 = |b| {
        let inner: i64 = |c| a + b + c;
        return inner(100);
    };
    return outer;
}

fn apply1(f: i64, x: i64) -> i64 { return f(x); }

fn main() -> i64 {
    let mut fail: i64 = 0;
    let f: i64 = make_outer(1);
    let g: i64 = make_outer(10);

    if apply1(f, 2)  != 103 { print("FAIL closure_capture_nested: f(2) = 1+2+100 = 103"); fail = fail + 1; };
    if apply1(g, 20) != 130 { print("FAIL closure_capture_nested: g(20) = 10+20+100 = 130"); fail = fail + 1; };

    if fail == 0 { print("OK closure_capture_nested"); return 0; };
    return 1;
}
