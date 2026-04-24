// rods/bitwise runtime — Bitwise operations for Nucleor
// Nucleor doesn't have bitwise operators, so these are provided via C FFI

long long rods_bit_and(long long a, long long b) {
    return a & b;
}

long long rods_bit_or(long long a, long long b) {
    return a | b;
}

long long rods_bit_xor(long long a, long long b) {
    return a ^ b;
}

long long rods_bit_not(long long a) {
    return ~a;
}

long long rods_bit_shift_left(long long a, long long n) {
    return a << n;
}

long long rods_bit_shift_right(long long a, long long n) {
    return (unsigned long long)a >> n;
}

// T1.1 Phase 6: arithmetic (sign-preserving) right shift.
// Pairs with the logical shift above so users can opt in
// to either based on signedness of the operand.
long long rods_bit_shift_right_signed(long long a, long long n) {
    return a >> n;
}

long long rods_bit_test(long long val, long long bit) {
    return (val >> bit) & 1;
}

long long rods_bit_set(long long val, long long bit) {
    return val | (1LL << bit);
}

long long rods_bit_clear(long long val, long long bit) {
    return val & ~(1LL << bit);
}
