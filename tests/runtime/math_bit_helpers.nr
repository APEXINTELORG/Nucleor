// math_bit_helpers — RFC-0015 / RFC-0017 stdlib enrichment.
//
// f64 unary/binary math:
//   f64_abs(b)              -> i64 (f64 bits)
//   f64_min(a, b)           -> i64
//   f64_max(a, b)           -> i64
//   f64_sign(b)             -> i64  (-1.0, 0.0, +1.0)
//   f64_copy_sign(a, b)     -> i64
//
// Bit population helpers:
//   count_ones(v)           -> i64
//   count_zeros(v)          -> i64

fn main() -> i64 {
    let mut fail: i64 = 0;

    // f64_abs: |-3.5| == 3.5
    let neg: i64 = f64_from_scaled(-3500000);
    let pos: i64 = f64_from_scaled(3500000);
    let absv: i64 = f64_abs(neg);
    if absv != pos { fail = fail + 1; print("FAIL f64_abs"); };

    // f64_min / f64_max
    let a: i64 = f64_from_scaled(2000000);
    let b: i64 = f64_from_scaled(7000000);
    if f64_min(a, b) != a { fail = fail + 1; print("FAIL f64_min"); };
    if f64_max(a, b) != b { fail = fail + 1; print("FAIL f64_max"); };

    // f64_sign: positive -> +1, negative -> -1, zero -> 0
    let one: i64 = f64_from_scaled(1000000);
    let mone: i64 = f64_from_scaled(-1000000);
    let zero: i64 = f64_from_scaled(0);
    if f64_sign(pos) != one  { fail = fail + 1; print("FAIL f64_sign +"); };
    if f64_sign(neg) != mone { fail = fail + 1; print("FAIL f64_sign -"); };
    if f64_sign(zero) != zero { fail = fail + 1; print("FAIL f64_sign 0"); };

    // f64_copy_sign: |a| with sign(b)
    let signed_neg: i64 = f64_copy_sign(pos, neg);
    if signed_neg != neg { fail = fail + 1; print("FAIL f64_copy_sign -"); };
    let signed_pos: i64 = f64_copy_sign(neg, pos);
    if signed_pos != pos { fail = fail + 1; print("FAIL f64_copy_sign +"); };

    // count_ones / count_zeros
    if count_ones(0) != 0  { fail = fail + 1; print("FAIL count_ones 0"); };
    if count_ones(7) != 3  { fail = fail + 1; print("FAIL count_ones 7"); };
    if count_ones(-1) != 64 { fail = fail + 1; print("FAIL count_ones -1"); };
    if count_zeros(0) != 64 { fail = fail + 1; print("FAIL count_zeros 0"); };
    if count_zeros(7) != 61 { fail = fail + 1; print("FAIL count_zeros 7"); };
    if count_zeros(-1) != 0 { fail = fail + 1; print("FAIL count_zeros -1"); };

    // count_ones + count_zeros == 64 invariant (spot check)
    let v: i64 = 12345678;
    if count_ones(v) + count_zeros(v) != 64 {
        fail = fail + 1;
        print("FAIL count invariant");
    };

    if fail == 0 { print("OK math_bit_helpers"); return 0; };
    return 1;
}
