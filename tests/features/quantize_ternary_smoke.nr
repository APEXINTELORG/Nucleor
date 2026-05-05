// v0.8.256 stdlib/rods/quantize.nr ternary GEMV arity drift FIX coverage.
//
// Pre-v0.8.256 the rod declared `nuc_quant_ternary_gemv` 3-arg
// `(tw, x, rows)` but C runtime took 4 `(tw, x, rows, cols)`. The
// 3-arg call site read garbage from the un-pushed cols slot —
// inner loop bounds were random, causing segfault or truncated
// output. MLV/MGN ternary inference miscomputed today.
//
// Same bug class as v0.8.45 ML-1, v0.8.252 kv_cache, v0.8.254
// transformer, v0.8.255 bayesian. Surfaced by parallel-agent
// TRACK A `extern_arity_drift_quantize_2026-05-05`.
//
// Fix (Plan B, non-breaking):
// - C `nuc_quant_ternary_gemv` 4-arg renamed to `_full`.
// - New 3-arg `nuc_quant_ternary_gemv(tw, x, rows)` recovers
//   `cols` from `x->len` (the input vector length is the matrix's
//   column count by definition) and calls `_full(tw, x, rows, cols)`.
// - 4-arg `tw, x, rows, cols` form exposed in the rod as
//   `quant_ternary_gemv_full` for callers that want explicit cols
//   (e.g., when x is a slice or padded).
//
// Locks textbook ternary GEMV invariants on a 2×2 identity-like
// matrix ([4, 0; 0, 4]) — trits [+1, 0, 0, +1], absmean = 2.0:
//
//   1. **3-arg shim recovers cols correctly** — y = [+1*1 + 0*2,
//      0*1 + +1*2] * absmean = [2.0, 4.0] for x=[1.0, 2.0].
//   2. **3-arg matches 4-arg `_full`** — bit-identical output when
//      cols passed explicitly.
//
// Expected: rc=0.

import "stdlib/rods/quantize.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_w_2x2() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(4.0));
    return v;
}

fn make_x() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    return v;
}

fn check_3arg_recovers_cols() -> i64 {
    let w: Vec<i64> = make_w_2x2();
    let tw: i64 = quant_ternary_encode(w, 4);
    if tw == 0 { return 1; };
    let x: Vec<i64> = make_x();
    let y: i64 = quant_ternary_gemv(tw, x, 2);
    if y == 0 { return 2; };
    if vec_len(y) != 2 { return 4; };
    if close(vec_get(y, 0), f64_to_bits(2.0), 1e-9) != 1 { return 8; };
    if close(vec_get(y, 1), f64_to_bits(4.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_3arg_matches_4arg() -> i64 {
    let w: Vec<i64> = make_w_2x2();
    let tw: i64 = quant_ternary_encode(w, 4);
    let x1: Vec<i64> = make_x();
    let y3: i64 = quant_ternary_gemv(tw, x1, 2);
    let x2: Vec<i64> = make_x();
    let y4: i64 = quant_ternary_gemv_full(tw, x2, 2, 2);
    if vec_len(y3) != vec_len(y4) { return 32; };
    if vec_get(y3, 0) != vec_get(y4, 0) { return 64; };
    if vec_get(y3, 1) != vec_get(y4, 1) { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_3arg_recovers_cols();
    fails = fails + check_3arg_matches_4arg();
    return fails;
}
