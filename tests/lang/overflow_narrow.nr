// overflow_narrow — RFC-0015 phase 4: per-narrow-width overflow primitives.
//
// Verifies wrapping/saturating/checked add/sub/mul for each of:
// i8, i16, i32, u8, u16, u32, u64.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // ---- i8: range [-128, 127] ----
    if wrapping_add_i8(120, 20) != (0 - 116) { fail = fail + 1; print("FAIL wrap_add_i8"); }; // 140 mod-wrap → -116
    if wrapping_sub_i8(0 - 100, 50) != 106 { fail = fail + 1; print("FAIL wrap_sub_i8"); };  // -150 wrap → 106
    if saturating_add_i8(120, 20) != 127 { fail = fail + 1; print("FAIL sat_add_i8 hi"); };
    if saturating_sub_i8(0 - 100, 50) != (0 - 128) { fail = fail + 1; print("FAIL sat_sub_i8 lo"); };
    if saturating_mul_i8(20, 20) != 127 { fail = fail + 1; print("FAIL sat_mul_i8 hi"); };
    let _x: i64 = checked_add_i8(120, 20);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL chk_add_i8 of"); };
    let _y: i64 = checked_add_i8(50, 60);
    if checked_overflow_flag() != 0 { fail = fail + 1; print("FAIL chk_add_i8 ok"); };

    // ---- i16: range [-32768, 32767] ----
    if saturating_add_i16(30000, 5000) != 32767 { fail = fail + 1; print("FAIL sat_add_i16 hi"); };
    if saturating_sub_i16(0 - 30000, 5000) != (0 - 32768) { fail = fail + 1; print("FAIL sat_sub_i16 lo"); };
    let _z: i64 = checked_mul_i16(200, 200);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL chk_mul_i16 of"); }; // 40000 > 32767

    // ---- i32: range [-2^31, 2^31 - 1] ----
    let imax32: i64 = 2147483647;
    if saturating_add_i32(imax32, 1) != imax32 { fail = fail + 1; print("FAIL sat_add_i32 hi"); };
    if wrapping_add_i32(imax32, 1) != (0 - imax32 - 1) { fail = fail + 1; print("FAIL wrap_add_i32"); };

    // ---- u8: range [0, 255] ----
    if saturating_add_u8(250, 20) != 255 { fail = fail + 1; print("FAIL sat_add_u8 hi"); };
    if saturating_sub_u8(20, 50) != 0 { fail = fail + 1; print("FAIL sat_sub_u8 lo"); };
    if wrapping_add_u8(250, 20) != 14 { fail = fail + 1; print("FAIL wrap_add_u8"); }; // 270 mod 256 = 14
    let _u: i64 = checked_add_u8(200, 100);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL chk_add_u8 of"); };

    // ---- u16: range [0, 65535] ----
    if saturating_add_u16(60000, 10000) != 65535 { fail = fail + 1; print("FAIL sat_add_u16 hi"); };
    if wrapping_mul_u16(300, 300) != (90000 - 65536) { fail = fail + 1; print("FAIL wrap_mul_u16"); }; // 90000 mod 65536

    // ---- u32: range [0, 2^32 - 1] ----
    let umax32: i64 = 4294967295;
    if saturating_add_u32(umax32, 1) != umax32 { fail = fail + 1; print("FAIL sat_add_u32 hi"); };

    // ---- u64: full 64-bit unsigned ----
    if saturating_sub_u64(10, 20) != 0 { fail = fail + 1; print("FAIL sat_sub_u64 lo"); };
    if wrapping_add_u64(0, 5) != 5 { fail = fail + 1; print("FAIL wrap_add_u64"); };

    if fail == 0 { print("OK overflow_narrow"); return 0; };
    return 1;
}
