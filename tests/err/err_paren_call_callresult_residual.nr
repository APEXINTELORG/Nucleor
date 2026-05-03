// EXPECT: ERROR: `(expr)(args)` direct-call form not yet supported for IIFE
// err_paren_call_callresult_residual — v0.6.28 negative fixture
// closes probe finding 2026-05-02-paren-call-still-miscomputes-on-
// iife-call-result-cast (Case 2 — call result returning fn-ptr).

fn dbl(x: i64) -> i64 { x * 2 }
fn get_handler() -> fn(i64) -> i64 { return dbl; }

fn main() -> i32 {
    print_int((get_handler())(21) as i32);
    0
}
