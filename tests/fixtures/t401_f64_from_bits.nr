// t401_f64_from_bits.nr — v0.3.125 NUC-IMPROVE-004 fixture.
//
// Pins the explicit reinterpret helpers `f64_from_bits` /
// `f64_to_bits` / `f32_from_bits` / `f32_to_bits`. Pre-v0.3.125,
// the canonical adopter pattern for parsing decimal text into
// typed `f64`:
//
//   data.push(str_to_f64(cell) as f64);
//
// silently miscomputed: `str_to_f64("1.25")` returns the i64 BIT
// PATTERN of 1.25 (per Nucleor's runtime convention), and `as f64`
// then NUMERICALLY converts that large integer (~4.6e18) into a
// large floating value rather than reinterpreting the bits as a
// typed f64. Result: `1.25` printed as `4608308318706860032.000000`.
//
// ML_Suite agent reported this in NUC-IMPROVE-004 with a request
// for `f64_from_bits(bits: i64) -> f64` as the explicit
// reinterpret. The helper is identity at the runtime ABI level
// (Nucleor's f64 IS the i64 bit pattern), but the named entry
// documents intent and gives adopters the right primitive to
// reach for.
//
// Returns 0 when `f64_from_bits(str_to_f64("1.25"))` decodes
// correctly to 1.25 (within tolerance). Non-zero diagnostic codes
// pinpoint the failure mode.

fn main() -> i64 {
    let bits: i64 = str_to_f64("1.25");
    let v: f64 = f64_from_bits(bits);
    if v < 1.24 { return 1; };
    if v > 1.26 { return 2; };
    // Round-trip: bits → typed → bits MUST be the same i64.
    let back: i64 = f64_to_bits(v);
    if back != bits { return 3; };
    return 0;
}
