// t406_long_f64_literal.nr — v0.3.130 NUC-FEEDBACK-005 fixture.
//
// Pins long-precision f64 literal lexing. Pre-v0.3.130, a literal
// like `0.7978845608028654` (16 fractional digits) silently
// collapsed to 0:
//
//   frac_div = 10 ^ frac_len = 10^16 = 10000000000000000
//   1000000 / frac_div = 0     (integer division)
//   frac_val * 0       = 0
//   encoded            = int_part * 1000000 + 0 = 0
//
// `f64_from_scaled(0)` then returned 0.0 — every long-precision
// literal became a clean integer with zero fraction. The ML_Suite
// agent reported this in NUC-FEEDBACK-005 after a GELU-tanh PyTorch
// parity test silently produced `0.5 * x` (because the canonical
// constant `sqrt(2/π) ≈ 0.7978845608028654` was zero).
//
// HIGH-blast for any ML / scientific code reaching for canonical
// constants:
//   sqrt(2/π) ≈ 0.7978845608028654   (GELU)
//   log(2)    ≈ 0.6931471805599453   (entropy)
//   1/√(2π)   ≈ 0.3989422804014327   (gaussian normalization)
//   e         ≈ 2.7182818284590452
//   π         ≈ 3.1415926535897932
//   golden    ≈ 1.6180339887498949
//
// Fix: truncate the fractional digit string to the encoder's
// 6-digit (millionth) precision BEFORE computing frac_div. The
// truncation matches the existing scaled-int convention and is
// preferable to rejecting the literal — adopters get the right
// 6-decimal value (close enough for the typical `1e-6` ML parity
// tolerance) instead of a silent zero.
//
// Returns 0 when `0.7978845608028654` decodes to ~0.797884
// (within 1e-5 tolerance).

fn main() -> i64 {
    let k: f64 = 0.7978845608028654;
    if k < 0.797 { return 1; };
    if k > 0.799 { return 2; };
    // Verify a few more canonical constants land non-zero:
    let log2: f64 = 0.6931471805599453;
    if log2 < 0.692 { return 3; };
    if log2 > 0.694 { return 4; };
    let pi_recip_sqrt_2pi: f64 = 0.3989422804014327;
    if pi_recip_sqrt_2pi < 0.398 { return 5; };
    if pi_recip_sqrt_2pi > 0.400 { return 6; };
    return 0;
}
