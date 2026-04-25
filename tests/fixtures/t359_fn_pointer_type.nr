// t359_fn_pointer_type.nr — v0.3.83 regression fixture.
//
// Pins fn-pointer type syntax `fn(T1, T2) -> R` in parameter
// positions. Pre-v0.3.83, parse_type didn't recognize the `fn`
// keyword as a type-starter and cascaded into 26+ parse errors
// when seeing `f: fn(i64) -> i64` in a parameter list. Post:
// the fn-type is consumed syntactically and treated as i64 (which
// is how Nucleor stores fn pointers), so callable-via-i64
// dispatch handles the rest correctly.
//
// Returns 0 on success.

fn apply(f: fn(i64) -> i64, x: i64) -> i64 {
    return f(x);
}

fn double(n: i64) -> i64 {
    return n * 2;
}

fn add_with(a: i64, op: fn(i64, i64) -> i64, b: i64) -> i64 {
    return op(a, b);
}

fn sum(x: i64, y: i64) -> i64 {
    return x + y;
}

fn main() -> i64 {
    if apply(double, 7) != 14 { return 91; };
    if add_with(10, sum, 5) != 15 { return 92; };

    // Closure passed to fn-typed param (capture works via AST kind 42 path)
    let factor: i64 = 3;
    if apply(|x| x * factor, 7) != 21 { return 93; };

    return 0;
}
