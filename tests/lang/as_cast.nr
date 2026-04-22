// as_cast.nr — RFC-0015 phase 2: `as` cast operator
// Tests truncation + sign extension semantics across int widths.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Truncate to u8 (modulo 256)
    let big: i64 = 300;
    let small: i64 = big as u8;
    if small != 44 { fail = fail + 1; print("FAIL: 300 as u8 != 44\n"); };

    // Truncate to i8 with sign extension (positive in range)
    let mid: i64 = 100;
    let small_signed: i64 = mid as i8;
    if small_signed != 100 { fail = fail + 1; print("FAIL: 100 as i8 != 100\n"); };

    // Truncate to i8 with sign extension (negative)
    let big2: i64 = 200;  // bit 7 set after truncate
    let neg: i64 = big2 as i8;  // should be 200 - 256 = -56
    if neg != (0 - 56) { fail = fail + 1; print("FAIL: 200 as i8 != -56\n"); };

    // u16
    let huge: i64 = 70000;  // > 65536
    let mod16: i64 = huge as u16;
    if mod16 != 4464 { fail = fail + 1; print("FAIL: 70000 as u16 != 4464\n"); };

    // u32 — preserve low 32 bits
    let big_u: i64 = 1099511627776;  // 2^40
    let trunc32: i64 = big_u as u32;
    if trunc32 != 0 { fail = fail + 1; print("FAIL: 2^40 as u32 != 0\n"); };

    // i32 with sign extension
    let high32: i64 = 0 - 1;  // i64 -1 → all bits set
    let s32: i64 = high32 as i32;
    if s32 != (0 - 1) { fail = fail + 1; print("FAIL: -1 as i32 sign-extend\n"); };

    // Identity casts
    let v: i64 = 42;
    let id: i64 = v as i64;
    if id != 42 { fail = fail + 1; print("FAIL: 42 as i64 identity\n"); };

    // Chained casts: i64 -> u8 -> i64
    let x: i64 = 1000;
    let chained: i64 = (x as u8) as i64;  // 1000 mod 256 = 232
    if chained != 232 { fail = fail + 1; print("FAIL: chained cast\n"); };

    if fail == 0 { print("OK as_cast\n"); return 0; };
    return 1;
}
