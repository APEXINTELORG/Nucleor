// v0.8.115 stdlib/rods/bitwise.nr first test coverage.
//
// Per the zero-coverage rod survey, bitwise.nr (and/or/xor/not,
// shifts, bit_test/set/clear) had no existing tests. Same risk
// class as bits.nr — silent regression in any operator
// corrupts every consumer.
//
// Locks textbook bitwise invariants:
//   1. AND/OR/XOR identities: a & a == a, a | a == a, a ^ a == 0
//   2. NOT involutive: bit_not(bit_not(a)) == a
//   3. XOR self-inverse: (a ^ b) ^ b == a
//   4. Shift-left and unsigned-right-shift inverse for non-negative values:
//      shift_right(shift_left(a, n), n) == a
//   5. bit_test on bit i after bit_set(0, i) returns 1
//   6. bit_clear undoes bit_set: bit_test(bit_clear(bit_set(0, i), i), i) == 0
//   7. arithmetic right shift sign-extends: shift_right_signed(-1, 5) == -1
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bitwise.nr"

fn check_bit_and_or_xor_identities() -> i64 {
    if bit_and(0xCAFE, 0xCAFE) != 0xCAFE { return 1; };
    if bit_or(0xCAFE, 0xCAFE) != 0xCAFE { return 2; };
    if bit_xor(0xCAFE, 0xCAFE) != 0 { return 4; };
    if bit_and(0xFF, 0x0F) != 0x0F { return 8; };
    if bit_or(0xF0, 0x0F) != 0xFF { return 16; };
    return 0;
}

fn check_bit_not_involutive() -> i64 {
    let a: i64 = 0x123456789ABCDEF0;
    if bit_not(bit_not(a)) != a { return 32; };
    let b: i64 = 0;
    if bit_not(bit_not(b)) != b { return 64; };
    return 0;
}

fn check_xor_self_inverse() -> i64 {
    let a: i64 = 0xCAFEBABE;
    let b: i64 = 0xDEADBEEF;
    if bit_xor(bit_xor(a, b), b) != a { return 128; };
    return 0;
}

fn check_shift_round_trip_unsigned() -> i64 {
    // For non-negative inputs that don't shift past the sign bit,
    // unsigned right shift inverts left shift.
    let a: i64 = 0x12345678;
    if bit_shift_right(bit_shift_left(a, 4), 4) != a { return 256; };
    if bit_shift_right(bit_shift_left(a, 8), 8) != a { return 512; };
    return 0;
}

fn check_bit_test_set_clear() -> i64 {
    let mut v: i64 = 0;
    v = bit_set(v, 5);
    if bit_test(v, 5) != 1 { return 1024; };
    if bit_test(v, 4) != 0 { return 2048; };
    v = bit_clear(v, 5);
    if bit_test(v, 5) != 0 { return 4096; };
    return 0;
}

fn check_arithmetic_right_shift() -> i64 {
    // -1 = 0xFFFFFFFFFFFFFFFF; arithmetic shift preserves sign.
    if bit_shift_right_signed(0 - 1, 5) != 0 - 1 { return 8192; };
    // 16 >> 2 = 4 (non-negative, both shifts agree)
    if bit_shift_right_signed(16, 2) != 4 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_bit_and_or_xor_identities();
    fails = fails + check_bit_not_involutive();
    fails = fails + check_xor_self_inverse();
    fails = fails + check_shift_round_trip_unsigned();
    fails = fails + check_bit_test_set_clear();
    fails = fails + check_arithmetic_right_shift();
    return fails;
}
