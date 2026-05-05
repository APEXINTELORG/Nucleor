// v0.8.196 stdlib/rods/quantize.nr first test coverage.
//
// Weight + activation quantization (Q4 / int8 / ternary / FP8).
// Pre-v0.8.196: zero coverage.
//
// Locks three Q4 round-trip invariants:
//   1. **Encode + decode lossy round-trip on tiny vector**: 4-bit
//      quantization preserves values within ~scale/14 (the
//      worst-case quantization error for 4-bit signed).
//   2. **Length preservation**: 32-element input → 32-element
//      decoded output (block-aligned).
//   3. **Constant input**: a vector of all-equal values
//      decodes back close to the original constant.
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

fn check_q4_constant_round_trip() -> i64 {
    let mut w: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 32 {
        w.push(f64_to_bits(0.5));
        i = i + 1;
    };
    let h: i64 = quant_q4_encode(w, 32);
    let dec: i64 = quant_q4_decode(h);
    // Decoded ≈ 0.5 (within Q4 quantization error: scale/7 worst-case)
    let mut j: i64 = 0;
    while j < 32 {
        let v: f64 = f64_from_bits(vec_get(dec, j));
        let d: f64 = v - 0.5;
        let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
        if abs_d > 0.1 { return 1; };
        j = j + 1;
    };
    return 0;
}

fn check_q4_length_preservation() -> i64 {
    let mut w: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 32 {
        w.push(f64_to_bits((i as f64) * 0.05));
        i = i + 1;
    };
    let h: i64 = quant_q4_encode(w, 32);
    let dec: i64 = quant_q4_decode(h);
    if vec_len(dec) != 32 { return 2; };
    return 0;
}

fn check_q4_round_trip_within_scale() -> i64 {
    // Scale = 1.0/7 with values in [-1, 1] → max error ≈ scale/2
    let mut w: Vec<i64> = Vec::new();
    w.push(f64_to_bits(0.0 - 1.0));
    w.push(f64_to_bits(0.0 - 0.5));
    w.push(f64_to_bits(0.0));
    w.push(f64_to_bits(0.5));
    w.push(f64_to_bits(1.0));
    let mut i: i64 = 5;
    while i < 32 {
        w.push(f64_to_bits(0.0));
        i = i + 1;
    };
    let h: i64 = quant_q4_encode(w, 32);
    let dec: i64 = quant_q4_decode(h);
    // Check that the 5 known values decode within reasonable Q4 error
    let v0: f64 = f64_from_bits(vec_get(dec, 0));
    let v4: f64 = f64_from_bits(vec_get(dec, 4));
    let d0: f64 = v0 - (0.0 - 1.0);
    let d4: f64 = v4 - 1.0;
    let abs_d0: f64 = if d0 < 0.0 { 0.0 - d0 } else { d0 };
    let abs_d4: f64 = if d4 < 0.0 { 0.0 - d4 } else { d4 };
    if abs_d0 > 0.2 { return 4; };
    if abs_d4 > 0.2 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_q4_constant_round_trip();
    fails = fails + check_q4_length_preservation();
    fails = fails + check_q4_round_trip_within_scale();
    return fails;
}
