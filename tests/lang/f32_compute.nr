// f32_compute.nr — RFC-0015 phase 6: f32 distinct compute path
// f32 values pass as i64 with bit-pattern in low 32 bits.
// Verifies the storage round-trip + arithmetic.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // f32 from int round-trip
    let one_f32: i64 = f32_from_int(1);
    let one_back: i64 = f32_to_int(one_f32);
    if one_back != 1 { fail = fail + 1; print("FAIL: f32 round-trip 1\n"); };

    let big_f32: i64 = f32_from_int(1000);
    if f32_to_int(big_f32) != 1000 { fail = fail + 1; print("FAIL: f32 round-trip 1000\n"); };

    // f32 add
    let two_f32: i64 = f32_from_int(2);
    let three_f32: i64 = f32_add(one_f32, two_f32);
    if f32_to_int(three_f32) != 3 { fail = fail + 1; print("FAIL: f32 add\n"); };

    // f32 mul
    let four_f32: i64 = f32_from_int(4);
    let twelve_f32: i64 = f32_mul(three_f32, four_f32);
    if f32_to_int(twelve_f32) != 12 { fail = fail + 1; print("FAIL: f32 mul\n"); };

    // f32 div
    let half_div: i64 = f32_div(twelve_f32, four_f32);
    if f32_to_int(half_div) != 3 { fail = fail + 1; print("FAIL: f32 div\n"); };

    // f32 sqrt
    let nine_f32: i64 = f32_from_int(9);
    let three_via_sqrt: i64 = f32_sqrt(nine_f32);
    if f32_to_int(three_via_sqrt) != 3 { fail = fail + 1; print("FAIL: f32 sqrt\n"); };

    // f32 comparisons
    if f32_lt(one_f32, two_f32) != 1 { fail = fail + 1; print("FAIL: f32 lt true\n"); };
    if f32_lt(two_f32, one_f32) != 0 { fail = fail + 1; print("FAIL: f32 lt false\n"); };
    if f32_eq(two_f32, two_f32) != 1 { fail = fail + 1; print("FAIL: f32 eq self\n"); };

    // f32 → f64 → f32 round-trip
    let f64_form: i64 = f32_to_f64(three_f32);
    let back_f32: i64 = f64_to_f32(f64_form);
    if f32_to_int(back_f32) != 3 { fail = fail + 1; print("FAIL: f32-f64 round-trip\n"); };

    // bf16 round-trip
    let pi_f32_approx: i64 = f32_from_int(3);  // 3.0
    let pi_bf16: i64 = bf16_from_f32(pi_f32_approx);
    let pi_back: i64 = bf16_to_f32(pi_bf16);
    if f32_to_int(pi_back) != 3 { fail = fail + 1; print("FAIL: bf16 round-trip\n"); };

    // bf16 arithmetic at f32 precision
    let two_bf16: i64 = bf16_from_f32(f32_from_int(2));
    let four_bf16: i64 = bf16_from_f32(f32_from_int(4));
    let six_bf16: i64 = bf16_add(two_bf16, four_bf16);
    if f32_to_int(bf16_to_f32(six_bf16)) != 6 { fail = fail + 1; print("FAIL: bf16 add\n"); };

    // f16 round-trip
    let five_f16: i64 = f16_from_f32(f32_from_int(5));
    if f32_to_int(f16_to_f32(five_f16)) != 5 { fail = fail + 1; print("FAIL: f16 round-trip\n"); };

    // f16 arithmetic
    let f16_a: i64 = f16_from_f32(f32_from_int(7));
    let f16_b: i64 = f16_from_f32(f32_from_int(3));
    let f16_sum: i64 = f16_add(f16_a, f16_b);
    if f32_to_int(f16_to_f32(f16_sum)) != 10 { fail = fail + 1; print("FAIL: f16 add\n"); };

    if fail == 0 { print("OK f32_compute\n"); return 0; };
    return 1;
}
