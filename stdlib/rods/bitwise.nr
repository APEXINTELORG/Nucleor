// =====================================================
// rods/bitwise — Bitwise operations (via C FFI)
// =====================================================
// Import: import "stdlib/rods/bitwise.nr"
// Provides: bit_and, bit_or, bit_xor, bit_not, bit_shift_left,
//   bit_shift_right, bit_test, bit_set, bit_clear
// =====================================================

#cfile "bitwise_rt.c"

extern fn rods_bit_and(a: i64, b: i64) -> i64;
extern fn rods_bit_or(a: i64, b: i64) -> i64;
extern fn rods_bit_xor(a: i64, b: i64) -> i64;
extern fn rods_bit_not(a: i64) -> i64;
extern fn rods_bit_shift_left(a: i64, n: i64) -> i64;
extern fn rods_bit_shift_right(a: i64, n: i64) -> i64;
// T1.1 Phase 6: arithmetic (sign-preserving) right shift companion.
extern fn rods_bit_shift_right_signed(a: i64, n: i64) -> i64;
extern fn rods_bit_test(val: i64, bit: i64) -> i64;
extern fn rods_bit_set(val: i64, bit: i64) -> i64;
extern fn rods_bit_clear(val: i64, bit: i64) -> i64;

// Bitwise AND
fn bit_and(a: i64, b: i64) -> i64 {
    return rods_bit_and(a, b);
}

// Bitwise OR
fn bit_or(a: i64, b: i64) -> i64 {
    return rods_bit_or(a, b);
}

// Bitwise XOR
fn bit_xor(a: i64, b: i64) -> i64 {
    return rods_bit_xor(a, b);
}

// Bitwise NOT (one's complement)
fn bit_not(a: i64) -> i64 {
    return rods_bit_not(a);
}

// Left shift: a << n
fn bit_shift_left(a: i64, n: i64) -> i64 {
    return rods_bit_shift_left(a, n);
}

// Logical right shift: a >> n (unsigned)
fn bit_shift_right(a: i64, n: i64) -> i64 {
    return rods_bit_shift_right(a, n);
}

// T1.1 Phase 6: arithmetic right shift (sign-preserving).
// Use for signed types where you want -8 >> 1 = -4 instead
// of the giant unsigned result the logical shift gives.
fn bit_shift_right_signed(a: i64, n: i64) -> i64 {
    return rods_bit_shift_right_signed(a, n);
}

// Test if bit at position is set (returns 0 or 1)
fn bit_test(val: i64, bit_pos: i64) -> i64 {
    return rods_bit_test(val, bit_pos);
}

// Set bit at position (return new value)
fn bit_set(val: i64, bit_pos: i64) -> i64 {
    return rods_bit_set(val, bit_pos);
}

// Clear bit at position (return new value)
fn bit_clear(val: i64, bit_pos: i64) -> i64 {
    return rods_bit_clear(val, bit_pos);
}
