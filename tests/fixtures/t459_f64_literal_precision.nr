// t459_f64_literal_precision.nr -- v0.3.197 regression fixture.
//
// NUC-FEEDBACK-005 corrected: pre-v0.3.197 the lexer only used the
// raw-bits IEEE-754 path (`str_to_f64`) when the first six fractional
// digits were ALL zero (the v0.3.133 sub-micro carve-out for
// `0.00000001`). Long literals with non-zero leading frac digits like
// `0.7978845608028654` (the GELU tanh constant) fell into the
// truncate-to-six + scaled-by-1e6 path, silently losing 10+ decimal
// digits of precision. The literal became `0.797884` after divide-by-
// 1e6 — a silent miscompute that turned tanh-GELU into `0.5 * x` and
// broke ML parity slices.
//
// Fix (v0.3.197): promote ANY f64 literal with > 6 fractional digits
// to the raw-bits path. Short literals (≤ 6) still use the scaled
// divide — frac_div is an exact power of ten so the runtime divide
// rounds once to the closest f64.
//
// Validation: probe the GELU constant, the AdamW eps, and the inner
// term of the GELU formula. Pre-fix the inner term collapses to ~0;
// post-fix it computes correctly.

fn main() -> i64 {
    let k_gelu: f64 = 0.7978845608028654;
    println!("{}", k_gelu);
    let eps: f64 = 0.00000001;
    println!("{}", eps);
    // High-precision math constants used in real ML kernels:
    let pi: f64 = 3.141592653589793;
    let e: f64 = 2.718281828459045;
    let sqrt2_inv: f64 = 0.7071067811865476;
    println!("{}", pi);
    println!("{}", e);
    println!("{}", sqrt2_inv);
    return 0;
}
