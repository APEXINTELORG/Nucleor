// closure_capture_recursive_call.nr — re-entering a capturing-closure-producing fn does not stomp prior captures.

fn apply(f: i64, x: i64) -> i64 { return f(x); }

fn make_adder(k: i64) -> i64 {
    let g: i64 = |x| x + k;
    return g;
}

fn use_both(f1: i64, f2: i64) -> i64 {
    let r1: i64 = apply(f1, 1);
    let r2: i64 = apply(f2, 1);
    return r1 * 100 + r2;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    let add1:   i64 = make_adder(1);
    let add50:  i64 = make_adder(50);

    let r: i64 = use_both(add1, add50);
    if r != 200 + 51 {
        print("FAIL closure_capture_recursive_call: expected (1+1)*100 + (50+1) = 251");
        fail = fail + 1;
    };

    if fail == 0 { print("OK closure_capture_recursive_call"); return 0; };
    return 1;
}
