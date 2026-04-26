// t408_typed_wrapper_format.nr — v0.3.132 regression fixture.
//
// Pins the v0.3.131 format heuristic's `_f64(` / `_f32(` suffix
// detection. The v0.3.131 ship caught `sqrt(`/`exp(`/`log(`/`tanh(`/
// `f64_*`/`f32_*` prefixes but missed the v0.3.127 typed-wrapper
// SUFFIX form (sqrt_f64, exp_f64, log_f64, tanh_f64, sin_f64,
// cos_f64, pow_f64) — adopters using the math_typed.nr rod inline
// in `println!("{}", sqrt_f64(16.0))` still got the i64 bit
// pattern.
//
// Fix: scan the arg expression for any `_f64(` or `_f32(`
// substring (the call form means the suffix is followed by `(`).
// If found, dispatch as `:f` (f64_to_str).
//
// Documented limitation: variable-form (`let r: f64 = sqrt_f64(x);
// println!("{}", r)`) still falls back to int_to_str — the macro
// expander runs before parse so it can't see r's type. Adopters
// using typed f64 variables should still write `{:f}` explicitly,
// or `f64_to_str(r)` directly.
//
// Returns 0 when both inline-call forms format correctly.

import "stdlib/rods/math_typed.nr"

fn main() -> i64 {
    let s1: str = format!("{}", sqrt_f64(16.0));
    if str_len(s1) != 1 { return 1; };  // "4"

    let s2: str = format!("{}", exp_f64(0.0));
    if str_len(s2) != 1 { return 2; };  // "1"

    return 0;
}
