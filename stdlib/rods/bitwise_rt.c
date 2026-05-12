// rods/bitwise runtime — Bitwise operations for Nucleor
// Nucleor doesn't have bitwise operators, so these are provided via C FFI
//
// Every shift / bit-position helper bounds-checks the count against
// [0, 63] before using C shifts. Invalid counts emit a deterministic
// panic via `nuc_bit_shift_panic`.

#include <stdio.h>
#include <stdlib.h>

static void nuc_bit_shift_panic(const char *fn, long long n) {
    fprintf(stderr,
            "PANIC: %s shift count %lld out of range [0, 63] (BIT-001)\n",
            fn, n);
    fflush(stderr);
    exit(1);
}

// Returns 1 if `n` is a legal i64 shift count, 0 otherwise.
static int nuc_bit_shift_count_ok(long long n) {
    return n >= 0 && n < 64;
}

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
    if (!nuc_bit_shift_count_ok(n)) nuc_bit_shift_panic("bit_shift_left", n);
    /* Cast to unsigned to avoid signed-overflow UB on the shift itself. */
    return (long long)((unsigned long long)a << n);
}

long long rods_bit_shift_right(long long a, long long n) {
    if (!nuc_bit_shift_count_ok(n)) nuc_bit_shift_panic("bit_shift_right", n);
    return (long long)((unsigned long long)a >> n);
}

// T1.1 Phase 6: arithmetic (sign-preserving) right shift.
// Pairs with the logical shift above so users can opt in
// to either based on signedness of the operand.
long long rods_bit_shift_right_signed(long long a, long long n) {
    if (!nuc_bit_shift_count_ok(n)) nuc_bit_shift_panic("bit_shift_right_signed", n);
    return a >> n;
}

long long rods_bit_test(long long val, long long bit) {
    if (!nuc_bit_shift_count_ok(bit)) nuc_bit_shift_panic("bit_test", bit);
    return ((unsigned long long)val >> bit) & 1;
}

long long rods_bit_set(long long val, long long bit) {
    if (!nuc_bit_shift_count_ok(bit)) nuc_bit_shift_panic("bit_set", bit);
    return (long long)((unsigned long long)val | ((unsigned long long)1 << bit));
}

long long rods_bit_clear(long long val, long long bit) {
    if (!nuc_bit_shift_count_ok(bit)) nuc_bit_shift_panic("bit_clear", bit);
    return (long long)((unsigned long long)val & ~((unsigned long long)1 << bit));
}
