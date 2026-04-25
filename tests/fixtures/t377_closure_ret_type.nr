// t377_closure_ret_type.nr — v0.3.101 regression fixture.
//
// Pins closure literal `-> RetType` annotation parsing. Pre-v0.3.101,
// the closure parser at parse_primary stopped after the closing `|`
// and didn't skip an optional `-> RetType` clause. With Rust-canonical
// source like `let f = |x: i64| -> i64 { return x + n; };`, the
// `->` and `i64` ended up parsed as part of the body — the body
// parser produced an `@i64` global ref, hard-failing at clang link
// with `use of undefined value '@i64'`. Block bodies, expression
// bodies, and zero-param `||` forms were ALL affected when a return
// type was annotated.
//
// Returns 10 = 7 + 3, proving the captured `n` and the parameter
// `x` both reach the body and the `-> i64` annotation is skipped.

fn main() -> i64 {
    let n: i64 = 7;
    let f = |x: i64| -> i64 { return x + n; };
    return f(3);
}
