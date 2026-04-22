// =====================================================
// rods/bits — Bit-twiddling primitives
// =====================================================
// Import: import "stdlib/rods/bits.nr"
//
// Wraps the v0.1.44 bit-twiddling builtins. Useful for compression,
// checksums, low-level encoding, and CPU-feature emulation.
// =====================================================

// Count of 1-bits in v.
fn bits_popcount(v: i64) -> i64 { return popcount(v); }

// Number of leading zero bits (MSB-side). Returns 64 for v == 0.
fn bits_leading_zeros(v: i64) -> i64 { return leading_zeros(v); }

// Number of trailing zero bits (LSB-side). Returns 64 for v == 0.
fn bits_trailing_zeros(v: i64) -> i64 { return trailing_zeros(v); }

// Endian flip — reverses the 8 bytes of v.
fn bits_byte_swap(v: i64) -> i64 { return byte_swap(v); }

// Barrel rotate. n masked to 0..63; safe for any input.
fn bits_rotate_left(v: i64, n: i64) -> i64 { return rotate_left(v, n); }
fn bits_rotate_right(v: i64, n: i64) -> i64 { return rotate_right(v, n); }

// Convenience: highest-set-bit index, or -1 if v == 0.
fn bits_msb_index(v: i64) -> i64 {
    if v == 0 { return 0 - 1; };
    return 63 - leading_zeros(v);
}

// Lowest-set-bit index, or -1 if v == 0.
fn bits_lsb_index(v: i64) -> i64 {
    if v == 0 { return 0 - 1; };
    return trailing_zeros(v);
}

// Power-of-two test (true for 0 by convention; tweak if you need strict).
fn bits_is_power_of_two(v: i64) -> i64 {
    if v <= 0 { return 0; };
    if popcount(v) == 1 { return 1; };
    return 0;
}

// Round up to next power of two.
fn bits_next_power_of_two(v: i64) -> i64 {
    if v <= 1 { return 1; };
    let bits: i64 = 64 - leading_zeros(v - 1);
    return rotate_left(1, bits);
}
