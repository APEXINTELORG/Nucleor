// const_fn.nr — @const_fn marks a function as compile-time evaluable
@const_fn
fn square(x: i64) -> i64 {
    return x * x;
}

@const_fn
fn cube(x: i64) -> i64 {
    return x * square(x);
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    if square(7) != 49 { print("FAIL const_fn: square"); fail = fail + 1; };
    if cube(3) != 27 { print("FAIL const_fn: cube"); fail = fail + 1; };
    // Const calls must give same result at runtime as compile-time evaluation.
    let s: i64 = square(11);
    if s != 121 { print("FAIL const_fn: runtime"); fail = fail + 1; };
    if fail == 0 { print("OK const_fn"); return 0; };
    return 1;
}
