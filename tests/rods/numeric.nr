// numeric.nr — tests/rods/numeric — RFC-0015 numeric rod surface
import "stdlib/rods/numeric.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Overflow ops
    if n_wrapping_add(10, 20) != 30 { fail = fail + 1; print("FAIL wrapping_add\n"); };
    // saturating_add is i64-width; saturating at i32 max requires explicit narrowing
    let sat_at_i32: i64 = n_as_i32(n_saturating_add(n_max_i32(), 1));
    if sat_at_i32 != n_min_i32() { fail = fail + 1; print("FAIL saturating then narrow\n"); };
    if n_checked_add(10, 20) != 30 { fail = fail + 1; print("FAIL checked_add\n"); };

    // Casts
    if n_as_u8(300) != 44 { fail = fail + 1; print("FAIL as_u8\n"); };
    if n_as_i8(200) != (0 - 56) { fail = fail + 1; print("FAIL as_i8\n"); };
    if n_as_u16(70000) != 4464 { fail = fail + 1; print("FAIL as_u16\n"); };

    // f32 round-trip
    let x: i64 = f32(7);
    let y: i64 = f32(3);
    let sum: i64 = f32_plus(x, y);
    if f32_int(sum) != 10 { fail = fail + 1; print("FAIL f32 sum\n"); };

    // bf16 round-trip
    let a: i64 = bf16(5);
    if bf16_int(a) != 5 { fail = fail + 1; print("FAIL bf16 round-trip\n"); };

    // f16 round-trip
    let b: i64 = f16(8);
    if f16_int(b) != 8 { fail = fail + 1; print("FAIL f16 round-trip\n"); };

    // Width queries
    if n_size_u8() != 1 { fail = fail + 1; print("FAIL size_u8\n"); };
    if n_size_u32() != 4 { fail = fail + 1; print("FAIL size_u32\n"); };
    if n_size_f64() != 8 { fail = fail + 1; print("FAIL size_f64\n"); };

    // Range
    if n_max_u8() != 255 { fail = fail + 1; print("FAIL max_u8\n"); };
    if n_min_i8() != (0 - 128) { fail = fail + 1; print("FAIL min_i8\n"); };

    if fail == 0 { print("OK numeric"); return 0; };
    return 1;
}
