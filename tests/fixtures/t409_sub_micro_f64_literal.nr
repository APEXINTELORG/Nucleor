// t409_sub_micro_f64_literal.nr — v0.3.133 NUC-FEEDBACK-006 fixture.
//
// Pins sub-micro f64 literal lexing. v0.3.130's truncate-to-6-digits
// fix handled long literals where the meaningful digits were in the
// first 6 fractional positions. But for SUB-MICRO literals like
// `0.00000001` (= 1e-8, used as the canonical AdamW eps), the first
// 6 frac digits are all '0' and truncation still produces zero —
// the agent's PyTorch AdamW classifier loop saw NaN on the second
// optimizer step because `0 / (sqrt(0) + 0) = 0/0`.
//
// Fix: detect when raw_frac_len > 6 AND the first 6 frac digits are
// all '0' (i.e. the value is below the scaled-int's 1e-6 precision
// floor). In that case, fall back to `__nucleor_str_to_f64` at lex
// time to get the actual i64 bit pattern via the C runtime's
// `strtod`. Emit a new token kind 124 (raw-bits f64 literal); parse
// emits AST kind 72; lower_expr emits the bit pattern as a direct
// `const_int` (no scaled-int divide needed, since the value IS the
// f64 bit pattern at the runtime ABI level).
//
// The scaled-int path is preserved for normal-range literals
// (≥ 1e-6) so the existing fast-path stays hot.
//
// Returns 42 when `eps + sqrt(0.0) > 0.0` — proving 1e-8 is
// non-zero, the canonical AdamW denominator pattern produces a
// finite value instead of `0/0 = NaN`.

fn main() -> i64 {
    let eps: f64 = 0.00000001;
    let denom: f64 = sqrt(0.0) + eps;
    if denom > 0.0 { return 42; };
    return 0;
}
