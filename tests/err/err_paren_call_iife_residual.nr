// EXPECT: ERROR: `(expr)(args)` direct-call form not yet supported for IIFE
// err_paren_call_iife_residual — v0.6.28 negative fixture
// closes probe finding 2026-05-02-paren-call-still-miscomputes-on-
// iife-call-result-cast (Case 1 — IIFE). v0.6.12 closed the
// kind-9/10/8 inner-expression shapes (struct field, vec_get, method-
// call); v0.6.28 extends the same halt to kind 42 (closure literal),
// kind 7 (call result), and kind 99 (`as` cast). Pre-fix all three
// silently returned the inner expression's *value* (closure address,
// fn-pointer, or cast result) instead of CALLING it — adopters got
// giant address-like numbers where they expected the call result.
//
// EXPECT: build halts with workaround pointer.

fn main() -> i32 {
    print_int((|x: i64| x * 2)(21) as i32);
    0
}
