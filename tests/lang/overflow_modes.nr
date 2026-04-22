// overflow_modes.nr — RFC-0015 phase 4: wrapping_*/checked_*/saturating_*

fn main() -> i32 {
    let mut fail: i64 = 0;

    // wrapping_add basic
    let a: i64 = 100;
    let b: i64 = 200;
    if wrapping_add(a, b) != 300 { fail = fail + 1; print("FAIL: wrapping_add basic\n"); };

    // wrapping_sub
    if wrapping_sub(50, 10) != 40 { fail = fail + 1; print("FAIL: wrapping_sub\n"); };

    // wrapping_mul
    if wrapping_mul(7, 6) != 42 { fail = fail + 1; print("FAIL: wrapping_mul\n"); };

    // saturating_add basic
    if saturating_add(10, 20) != 30 { fail = fail + 1; print("FAIL: saturating_add basic\n"); };

    // saturating_add at clamp: i64::MAX + 1 = i64::MAX
    let max: i64 = 9223372036854775807;
    if saturating_add(max, 1) != max { fail = fail + 1; print("FAIL: saturating_add clamp\n"); };

    // saturating_sub
    if saturating_sub(100, 30) != 70 { fail = fail + 1; print("FAIL: saturating_sub\n"); };

    // saturating_mul
    if saturating_mul(5, 6) != 30 { fail = fail + 1; print("FAIL: saturating_mul\n"); };
    if saturating_mul(max, 2) != max { fail = fail + 1; print("FAIL: saturating_mul clamp\n"); };

    // checked_add normal
    let chk1: i64 = checked_add(10, 20);
    let flag1: i64 = checked_overflow_flag();
    if chk1 != 30 { fail = fail + 1; print("FAIL: checked_add normal value\n"); };
    if flag1 != 0 { fail = fail + 1; print("FAIL: checked_add normal flag\n"); };

    // checked_add overflow
    let _ = checked_add(max, 1);
    let flag2: i64 = checked_overflow_flag();
    if flag2 != 1 { fail = fail + 1; print("FAIL: checked_add overflow flag\n"); };

    // checked_sub
    let _ = checked_sub(10, 20);
    if checked_overflow_flag() != 0 { fail = fail + 1; print("FAIL: checked_sub no overflow\n"); };

    // checked_mul overflow
    let _ = checked_mul(max, 2);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL: checked_mul overflow flag\n"); };

    if fail == 0 { print("OK overflow_modes\n"); return 0; };
    return 1;
}
