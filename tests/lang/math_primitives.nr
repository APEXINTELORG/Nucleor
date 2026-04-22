// math_primitives — verify the new integer + f64 math runtime helpers.
//
// f64 values pass as i64 cells holding bit patterns; arithmetic on those
// cells must go through the dedicated f64_* helpers, not the int operators.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // ---- Integer helpers ----
    if i64_abs(0 - 7) != 7 { fail = fail + 1; print("FAIL i64_abs"); };
    if i64_min(3, 5) != 3 { fail = fail + 1; print("FAIL i64_min"); };
    if i64_max(3, 5) != 5 { fail = fail + 1; print("FAIL i64_max"); };
    if i64_clamp(15, 0, 10) != 10 { fail = fail + 1; print("FAIL i64_clamp hi"); };
    if i64_clamp(0 - 3, 0, 10) != 0 { fail = fail + 1; print("FAIL i64_clamp lo"); };
    if i64_clamp(5, 0, 10) != 5 { fail = fail + 1; print("FAIL i64_clamp mid"); };
    if i64_sign(0 - 42) != (0 - 1) { fail = fail + 1; print("FAIL i64_sign neg"); };
    if i64_sign(0) != 0 { fail = fail + 1; print("FAIL i64_sign zero"); };
    if i64_sign(42) != 1 { fail = fail + 1; print("FAIL i64_sign pos"); };
    if i64_pow(2, 10) != 1024 { fail = fail + 1; print("FAIL i64_pow"); };
    if i64_pow(3, 4) != 81 { fail = fail + 1; print("FAIL i64_pow 3^4"); };
    if i64_isqrt(16) != 4 { fail = fail + 1; print("FAIL i64_isqrt 16"); };
    if i64_isqrt(99) != 9 { fail = fail + 1; print("FAIL i64_isqrt 99"); };
    if i64_isqrt(0) != 0 { fail = fail + 1; print("FAIL i64_isqrt 0"); };
    if i64_gcd(12, 18) != 6 { fail = fail + 1; print("FAIL i64_gcd"); };
    if i64_gcd(17, 13) != 1 { fail = fail + 1; print("FAIL i64_gcd coprime"); };
    if i64_lcm(4, 6) != 12 { fail = fail + 1; print("FAIL i64_lcm"); };
    if i64_lcm(0, 5) != 0 { fail = fail + 1; print("FAIL i64_lcm zero"); };

    // ---- f64 transcendentals — every helper resolves and returns sane bits ----
    // We check (a) constant retrieval and (b) trip through identities that
    // round-trip back to int comparable values via f64_to_i32.

    // sin(0) == 0, cos(0) == 1
    let zero_bits: i64 = i32_to_f64(0);
    let one_bits: i64 = i32_to_f64(1);
    if f64_to_i32(f64_sin(zero_bits)) != 0 { fail = fail + 1; print("FAIL sin(0)"); };
    if f64_to_i32(f64_cos(zero_bits)) != 1 { fail = fail + 1; print("FAIL cos(0)"); };
    if f64_to_i32(f64_tan(zero_bits)) != 0 { fail = fail + 1; print("FAIL tan(0)"); };

    // exp(0) == 1, log(e) == 1, log2(8) == 3, log10(1000) == 3
    let eight_bits: i64 = i32_to_f64(8);
    let thousand_bits: i64 = i32_to_f64(1000);
    if f64_to_i32(f64_exp(zero_bits)) != 1 { fail = fail + 1; print("FAIL exp(0)"); };
    if f64_to_i32(f64_log(f64_e())) != 1 { fail = fail + 1; print("FAIL log(e)"); };
    if f64_to_i32(f64_log2(eight_bits)) != 3 { fail = fail + 1; print("FAIL log2(8)"); };
    if f64_to_i32(f64_log10(thousand_bits)) != 3 { fail = fail + 1; print("FAIL log10(1000)"); };
    if f64_to_i32(f64_exp2(i32_to_f64(4))) != 16 { fail = fail + 1; print("FAIL exp2(4)"); };

    // pow(2, 10) == 1024
    let two_bits: i64 = i32_to_f64(2);
    let ten_bits: i64 = i32_to_f64(10);
    if f64_to_i32(f64_pow_v(two_bits, ten_bits)) != 1024 { fail = fail + 1; print("FAIL pow(2,10)"); };

    // hypot(3, 4) == 5
    let three_bits: i64 = i32_to_f64(3);
    let four_bits: i64 = i32_to_f64(4);
    if f64_to_i32(f64_hypot(three_bits, four_bits)) != 5 { fail = fail + 1; print("FAIL hypot(3,4)"); };

    // floor / ceil / trunc / round on whole-number bit patterns
    if f64_to_i32(f64_floor(four_bits)) != 4 { fail = fail + 1; print("FAIL floor(4)"); };
    if f64_to_i32(f64_ceil(four_bits)) != 4 { fail = fail + 1; print("FAIL ceil(4)"); };
    if f64_to_i32(f64_trunc(three_bits)) != 3 { fail = fail + 1; print("FAIL trunc(3)"); };
    if f64_to_i32(f64_round(four_bits)) != 4 { fail = fail + 1; print("FAIL round(4)"); };

    // sinh(0) == 0, cosh(0) == 1, tanh(0) == 0
    if f64_to_i32(f64_sinh(zero_bits)) != 0 { fail = fail + 1; print("FAIL sinh(0)"); };
    if f64_to_i32(f64_cosh(zero_bits)) != 1 { fail = fail + 1; print("FAIL cosh(0)"); };
    if f64_to_i32(f64_tanh(zero_bits)) != 0 { fail = fail + 1; print("FAIL tanh(0)"); };

    // asin(0) == 0, acos(1) == 0, atan(0) == 0, atan2(0, 1) == 0
    if f64_to_i32(f64_asin(zero_bits)) != 0 { fail = fail + 1; print("FAIL asin(0)"); };
    if f64_to_i32(f64_acos(one_bits)) != 0 { fail = fail + 1; print("FAIL acos(1)"); };
    if f64_to_i32(f64_atan(zero_bits)) != 0 { fail = fail + 1; print("FAIL atan(0)"); };
    if f64_to_i32(f64_atan2(zero_bits, one_bits)) != 0 { fail = fail + 1; print("FAIL atan2(0,1)"); };

    // fmod / clamp on whole numbers
    if f64_to_i32(f64_fmod(i32_to_f64(7), three_bits)) != 1 { fail = fail + 1; print("FAIL fmod(7,3)"); };
    if f64_to_i32(f64_clamp(i32_to_f64(15), zero_bits, ten_bits)) != 10 { fail = fail + 1; print("FAIL clamp hi"); };
    if f64_to_i32(f64_clamp(i32_to_f64(0 - 5), zero_bits, ten_bits)) != 0 { fail = fail + 1; print("FAIL clamp lo"); };

    // lerp(0, 10, 1) == 10  (t=1 picks the endpoint, no need for fractional)
    if f64_to_i32(f64_lerp(zero_bits, ten_bits, one_bits)) != 10 { fail = fail + 1; print("FAIL lerp(0,10,1)"); };

    // deg ↔ rad: round-trip through 180 deg ≈ pi rad ≈ 180 deg again
    let one_eighty_bits: i64 = i32_to_f64(180);
    let rt_bits: i64 = f64_rad_to_deg(f64_deg_to_rad(one_eighty_bits));
    if f64_to_i32(rt_bits) != 180 { fail = fail + 1; print("FAIL deg/rad round-trip"); };

    // Constants — non-zero retrieval (float bit patterns are huge)
    if f64_pi() == 0 { fail = fail + 1; print("FAIL pi const"); };
    if f64_tau() == 0 { fail = fail + 1; print("FAIL tau const"); };
    if f64_e() == 0 { fail = fail + 1; print("FAIL e const"); };
    if f64_sqrt2() == 0 { fail = fail + 1; print("FAIL sqrt2 const"); };
    if f64_ln2() == 0 { fail = fail + 1; print("FAIL ln2 const"); };
    if f64_ln10() == 0 { fail = fail + 1; print("FAIL ln10 const"); };

    // Predicates: NaN, Inf, finite
    let one_d_bits: i64 = i32_to_f64(1);
    if f64_is_finite(one_d_bits) != 1 { fail = fail + 1; print("FAIL is_finite(1)"); };
    if f64_is_nan(one_d_bits) != 0 { fail = fail + 1; print("FAIL is_nan(1)"); };
    if f64_is_inf(one_d_bits) != 0 { fail = fail + 1; print("FAIL is_inf(1)"); };

    if fail == 0 { print("OK math_primitives"); return 0; };
    return 1;
}
