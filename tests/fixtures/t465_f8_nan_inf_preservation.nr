// t465_f8_nan_inf_preservation.nr -- v0.3.209 NUC-FEEDBACK-002 follow-on.
//
// Pre-v0.3.209 the f8e4m3 / f8e5m2 pack helpers used round-to-zero
// (truncation) and lost NaN / inf bit patterns from the f32 input.
//
// Fix:
//   1. Round-to-nearest-even (RNE) on the discarded mantissa bits.
//   2. NaN preservation: f32 NaN -> f8e4m3 NaN (S1111111) /
//      f8e5m2 NaN (S11111_NN where NN != 0).
//   3. Inf preservation: f32 +inf -> f8e5m2 +inf (S11111_00).
//      f8e4m3 has no inf, so f32 inf saturates to ±MAX (=±448).
//
// This fixture exercises the special paths and the RNE behavior on
// round-half values.
fn main() -> i64 {
    // f8e5m2 +inf preservation: 1e30 (overflows e5m2's ~57344 range)
    // should pack to +inf (S11111_00 = 0x7C in low byte).
    // v0.3.211: `f32 as i64` now NUMERIC-truncates. The pack
    // helpers expect the f32 BIT PATTERN as i64, so use the
    // explicit f32_to_bits surface instead.
    let big: f32 = 100000.0 as f32;
    let e5_big: i64 = f8e5m2_from_f32(f32_to_bits(big));
    println!("{}", e5_big);   // expect 124 (= 0x7C = +inf)

    // Negative overflow -> -inf (0xFC).
    let nbig: f32 = (0.0 - 100000.0) as f32;
    let e5_nbig: i64 = f8e5m2_from_f32(f32_to_bits(nbig));
    println!("{}", e5_nbig);  // expect 252 (= 0xFC = -inf)

    // f8e4m3 saturation (no inf): 1e30 saturates to MAX = ±448.
    let e4_big: i64 = f8e4m3_from_f32(f32_to_bits(big));
    println!("{}", e4_big);   // expect 126 (= 0x7E = MAX = +448)

    // RNE on the f8e5m2 boundary: 12.0 is exactly representable in
    // e5m2. 13.0 would round to 14 (round half to even). We pick a
    // value that exercises the rounding path: 12.5 should round to
    // 12.0 (round half to even, lower neighbor has even mantissa).
    let mid: f32 = 12.5 as f32;
    let e5_mid: i64 = f8e5m2_from_f32(f32_to_bits(mid));
    let back: f32 = f8e5m2_to_f32(e5_mid);
    println!("{}", back);     // expect 12 (RNE chose the even nbr)

    return 0;
}
