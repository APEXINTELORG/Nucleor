fn wrap_mix0(x: i64) -> i64 {
    let a: i64 = wrapping { x + 17 };
    let b: i64 = wrapping { a * 3 };
    let c: i64 = wrapping { b - 11 };
    let d: i64 = wrapping { c / 2 };
    return wrapping { d + c };
}

fn wrap_mix1(x: i64) -> i64 {
    let a: i64 = wrapping { x + 29 };
    let b: i64 = wrapping { a * 5 };
    let c: i64 = wrapping { b - 19 };
    let d: i64 = wrapping { c / 3 };
    return wrapping { d + c };
}

fn wrap_mix2(x: i64) -> i64 {
    let a: i64 = wrapping { x + 43 };
    let b: i64 = wrapping { a * 7 };
    let c: i64 = wrapping { b - 23 };
    let d: i64 = wrapping { c / 5 };
    return wrapping { d + c };
}

fn wrap_mix3(x: i64) -> i64 {
    let a: i64 = wrapping { x + 59 };
    let b: i64 = wrapping { a * 11 };
    let c: i64 = wrapping { b - 31 };
    let d: i64 = wrapping { c / 7 };
    return wrapping { d + c };
}

fn wrap_mix4(x: i64) -> i64 {
    let a: i64 = wrapping { x + 71 };
    let b: i64 = wrapping { a * 13 };
    let c: i64 = wrapping { b - 37 };
    let d: i64 = wrapping { c / 11 };
    return wrapping { d + c };
}

fn wrap_mix5(x: i64) -> i64 {
    let a: i64 = wrapping { x + 89 };
    let b: i64 = wrapping { a * 17 };
    let c: i64 = wrapping { b - 41 };
    let d: i64 = wrapping { c / 13 };
    return wrapping { d + c };
}

fn wrap_mix6(x: i64) -> i64 {
    let a: i64 = wrapping { x + 97 };
    let b: i64 = wrapping { a * 19 };
    let c: i64 = wrapping { b - 47 };
    let d: i64 = wrapping { c / 17 };
    return wrapping { d + c };
}

fn wrap_mix7(x: i64) -> i64 {
    let a: i64 = wrapping { x + 109 };
    let b: i64 = wrapping { a * 23 };
    let c: i64 = wrapping { b - 53 };
    let d: i64 = wrapping { c / 19 };
    return wrapping { d + c };
}

fn main() -> i64 {
    let mut acc: i64 = 0;
    acc = wrapping { acc + wrap_mix0(1) };
    acc = wrapping { acc + wrap_mix1(acc) };
    acc = wrapping { acc + wrap_mix2(acc) };
    acc = wrapping { acc + wrap_mix3(acc) };
    acc = wrapping { acc + wrap_mix4(acc) };
    acc = wrapping { acc + wrap_mix5(acc) };
    acc = wrapping { acc + wrap_mix6(acc) };
    acc = wrapping { acc + wrap_mix7(acc) };
    if acc == 0 { return 1; };
    return 0;
}
