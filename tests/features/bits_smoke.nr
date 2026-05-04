// v0.8.112 stdlib/rods/bits.nr first test coverage.
//
// Per the zero-coverage rod survey, bits.nr (popcount, leading/
// trailing zeros, byte_swap, rotate, msb/lsb_index, power-of-two
// helpers) had no existing tests. These are correctness-critical
// for compression, checksums, low-level encoding.
//
// Locks textbook bit-twiddling invariants:
//   1. popcount of known values matches.
//   2. leading_zeros and trailing_zeros for canonical inputs.
//   3. byte_swap is involutive: bs(bs(v)) == v.
//   4. rotate_left + rotate_right with the same n compose to id.
//   5. msb_index / lsb_index of single-bit values match.
//   6. is_power_of_two for 0/1/2/3/4/255/256.
//   7. next_power_of_two for arbitrary inputs.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bits.nr"

fn check_popcount() -> i64 {
    if bits_popcount(0) != 0 { return 1; };
    if bits_popcount(1) != 1 { return 2; };
    if bits_popcount(7) != 3 { return 4; };           // 0b111
    if bits_popcount(255) != 8 { return 8; };          // 0b11111111
    if bits_popcount(0 - 1) != 64 { return 16; };      // all ones (i64)
    return 0;
}

fn check_leading_trailing_zeros() -> i64 {
    if bits_leading_zeros(0) != 64 { return 32; };
    if bits_leading_zeros(1) != 63 { return 64; };
    if bits_trailing_zeros(0) != 64 { return 128; };
    if bits_trailing_zeros(1) != 0 { return 256; };
    if bits_trailing_zeros(8) != 3 { return 512; };    // 0b1000
    return 0;
}

fn check_byte_swap_involutive() -> i64 {
    let v: i64 = 1234567890;
    if bits_byte_swap(bits_byte_swap(v)) != v { return 1024; };
    let w: i64 = 0 - 42;
    if bits_byte_swap(bits_byte_swap(w)) != w { return 2048; };
    return 0;
}

fn check_rotate_round_trip() -> i64 {
    let v: i64 = 0x123456789ABCDEF0;
    if bits_rotate_right(bits_rotate_left(v, 7), 7) != v { return 4096; };
    if bits_rotate_right(bits_rotate_left(v, 31), 31) != v { return 8192; };
    return 0;
}

fn check_msb_lsb_index() -> i64 {
    if bits_msb_index(0) != 0 - 1 { return 16384; };
    if bits_msb_index(1) != 0 { return 32768; };
    if bits_msb_index(8) != 3 { return 65536; };       // 0b1000 → bit 3
    if bits_lsb_index(0) != 0 - 1 { return 131072; };
    if bits_lsb_index(1) != 0 { return 262144; };
    if bits_lsb_index(8) != 3 { return 524288; };
    return 0;
}

fn check_is_power_of_two() -> i64 {
    if bits_is_power_of_two(0) != 0 { return 1048576; };
    if bits_is_power_of_two(1) != 1 { return 2097152; };
    if bits_is_power_of_two(2) != 1 { return 4194304; };
    if bits_is_power_of_two(3) != 0 { return 8388608; };
    if bits_is_power_of_two(4) != 1 { return 16777216; };
    if bits_is_power_of_two(255) != 0 { return 33554432; };
    if bits_is_power_of_two(256) != 1 { return 67108864; };
    return 0;
}

fn check_next_power_of_two() -> i64 {
    if bits_next_power_of_two(1) != 1 { return 134217728; };
    if bits_next_power_of_two(2) != 2 { return 268435456; };
    if bits_next_power_of_two(3) != 4 { return 536870912; };
    if bits_next_power_of_two(5) != 8 { return 1073741824; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_popcount();
    fails = fails + check_leading_trailing_zeros();
    fails = fails + check_byte_swap_involutive();
    fails = fails + check_rotate_round_trip();
    fails = fails + check_msb_lsb_index();
    fails = fails + check_is_power_of_two();
    fails = fails + check_next_power_of_two();
    return fails;
}
