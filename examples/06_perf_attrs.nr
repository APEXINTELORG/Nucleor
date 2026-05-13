// 06_perf_attrs.nr - performance attributes: @hot, @law, @const_fn.
// Build: nuc build examples/06_perf_attrs.nr -o perf_demo
// Inspect optimizer behavior: nuc perf examples/06_perf_attrs.nr
//
// @hot          - strict performance enforcement (no heap, no string format,
//                 no indirect dispatch in this function's body).
// @law(...)     - algebraic-law metadata checked by bounded tooling
//                 where supported.
// @const_fn     - function eligible for compile-time evaluation.

@law(commutative, associative, identity=0)
fn add_i64(a: i64, b: i64) -> i64 {
    return a + b;
}

@const_fn
fn square(x: i64) -> i64 {
    return x * x;
}

@hot
fn dot_product(xs: Vec<i32>, ys: Vec<i32>, n: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        acc = acc + vec_get(xs, i) * vec_get(ys, i);
        i = i + 1;
    };
    return acc;
}

fn str_from_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = "";
    let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 {
        let d: i64 = v - (v / 10) * 10;
        s = str_concat(str_substring("0123456789", d, d + 1), s);
        v = v / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn main() -> i64 {
    // This call chain records law metadata. Built-in arithmetic folds still
    // apply inside function bodies; proof and rewrite use are separate tooling.
    let s: i64 = add_i64(add_i64(add_i64(10, 0), 20), add_i64(0, 12));
    print(str_concat("add chain (laws-eligible) = ", str_from_int(s)));

    // square is @const_fn: compile-time evaluation eligible.
    let nine: i64 = square(3);
    print(str_concat("square(3) = ", str_from_int(nine)));

    // @hot dot_product
    let xs: Vec<i32> = Vec::new();
    let ys: Vec<i32> = Vec::new();
    let mut k: i64 = 0;
    while k < 5 {
        xs.push(k + 1);
        ys.push(k + 2);
        k = k + 1;
    };
    let dp: i64 = dot_product(xs, ys, 5);
    print(str_concat("dot([1..5], [2..6]) = ", str_from_int(dp)));
    return 0;
}
