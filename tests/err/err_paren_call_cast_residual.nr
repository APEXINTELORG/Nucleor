// EXPECT: ERROR: `(expr)(args)` direct-call form not yet supported for IIFE
// err_paren_call_cast_residual — v0.6.28 negative fixture
// closes probe finding 2026-05-02-paren-call-still-miscomputes-on-
// iife-call-result-cast (Case 3 — `as` cast inner expression).

fn dbl(x: i64) -> i64 { x * 2 }

fn main() -> i32 {
    let p: i64 = dbl as i64;
    print_int((p as fn(i64) -> i64)(21) as i32);
    0
}
