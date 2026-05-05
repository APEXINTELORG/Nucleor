// v0.8.220 stdlib/rods/numeric.nr first test coverage.
//
// RFC-0015 numeric type operations — explicit-overflow integer
// arithmetic, narrow truncation, f32/bf16/f16/f8 software math.
// Pre-v0.8.220: zero coverage on the standalone rod.
//
// Locks four invariants:
//
//   1. **Saturating add at i64 max** — n_saturating_add(max, 1)
//      stays at max (no wrap).
//   2. **Truncation casts mask correctly** — n_as_u8(257) ==
//      257 mod 256 = 1; n_as_u16(0x10001) == 1.
//   3. **f32 round-trip via f32_from_int / f32_to_int** —
//      f32(7) → f32_int → 7.
//   4. **bf16 round-trip preserves small ints** — bf16(42) →
//      bf16_int → 42 (bf16 has integer precision up to 256).
//
// Print/display surfaces are not tested (stdout side-effect).
//
// Expected: rc=0.

import "stdlib/rods/numeric.nr"

fn check_saturating_max() -> i64 {
    let max: i64 = 9223372036854775807;
    if n_saturating_add(max, 1) != max { return 1; };
    return 0;
}

fn check_truncation_casts() -> i64 {
    if n_as_u8(257) != 1 { return 2; };
    if n_as_u16(65537) != 1 { return 4; };
    if n_as_u8(0) != 0 { return 8; };
    if n_as_u8(255) != 255 { return 16; };
    return 0;
}

fn check_f32_round_trip() -> i64 {
    let a: i64 = f32(7);
    if f32_int(a) != 7 { return 32; };
    let b: i64 = f32(0 - 12);
    if f32_int(b) != (0 - 12) { return 64; };
    return 0;
}

fn check_bf16_round_trip() -> i64 {
    let a: i64 = bf16(42);
    if bf16_int(a) != 42 { return 128; };
    let b: i64 = bf16(0);
    if bf16_int(b) != 0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_saturating_max();
    fails = fails + check_truncation_casts();
    fails = fails + check_f32_round_trip();
    fails = fails + check_bf16_round_trip();
    return fails;
}
