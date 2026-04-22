// closures.nr — anonymous functions and indirect calls
fn apply(f: i64, x: i64) -> i64 {
    return f(x);
}

fn apply2(f: i64, a: i64, b: i64) -> i64 {
    return f(a, b);
}

fn main() -> i64 {
    let mut fail: i64 = 0;

    let double: i64 = |x| x * 2;
    if double(21) != 42 { print("FAIL closures: basic"); fail = fail + 1; };

    let add: i64 = |a, b| a + b;
    if add(17, 25) != 42 { print("FAIL closures: two-param"); fail = fail + 1; };

    let always42: i64 = || 42;
    if always42() != 42 { print("FAIL closures: zero-param"); fail = fail + 1; };

    let triple: i64 = |x| x * 3;
    if apply(triple, 14) != 42 { print("FAIL closures: higher-order"); fail = fail + 1; };

    if apply(|x| x + 1, 41) != 42 { print("FAIL closures: literal pass"); fail = fail + 1; };

    let mul: i64 = |a, b| a * b;
    if apply2(mul, 6, 7) != 42 { print("FAIL closures: two-param higher-order"); fail = fail + 1; };

    if fail == 0 { print("OK closures"); return 0; };
    return 1;
}
