// closure_capture_pass_back.nr — capturing closures survive across other closures from the same literal.

fn apply(f: i64, x: i64) -> i64 { return f(x); }

fn make_scaler(k: i64) -> i64 {
    let g: i64 = |x| x * k;
    return g;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let s2: i64 = make_scaler(2);
    let s3: i64 = make_scaler(3);
    let s5: i64 = make_scaler(5);

    let r1: i64 = apply(s2, 10);
    let r2: i64 = apply(s3, 10);
    let r3: i64 = apply(s5, 10);

    if r1 != 20 { print("FAIL closure_capture_pass_back: s2(10) = 20"); fail = fail + 1; };
    if r2 != 30 { print("FAIL closure_capture_pass_back: s3(10) = 30"); fail = fail + 1; };
    if r3 != 50 { print("FAIL closure_capture_pass_back: s5(10) = 50"); fail = fail + 1; };

    let again: i64 = apply(s2, 100);
    if again != 200 { print("FAIL closure_capture_pass_back: s2(100) re-call = 200"); fail = fail + 1; };

    if fail == 0 { print("OK closure_capture_pass_back"); return 0; };
    return 1;
}
