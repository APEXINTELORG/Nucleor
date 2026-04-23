// checked_div_neg — RFC-0015 phase 4 stdlib enrichment.
//
//   checked_div(a, b)        -> i64  (sets overflow_flag on b==0 or i64::MIN/-1)
//   checked_rem(a, b)        -> i64
//   checked_neg(v)           -> i64
//   wrapping_div(a, b)       -> i64  (silent: 0 on b==0; wraps on i64::MIN/-1)
//   wrapping_rem(a, b)       -> i64
//   wrapping_neg(v)          -> i64  (modular)
//   saturating_neg(v)        -> i64  (clamps i64::MIN to i64::MAX)

fn main() -> i64 {
    let mut fail: i64 = 0;
    // i64::MIN = -9223372036854775808 ; i64::MAX = 9223372036854775807
    // i64::MAX directly; i64::MIN computed via two's-complement wrap
    // (max + 1 wraps to MIN — needs the wrapping_add we already have).
    let imax: i64 = 9223372036854775807;
    let imin: i64 = wrapping_add(imax, 1);

    // checked_div: normal case
    if checked_div(10, 3) != 3 { fail = fail + 1; print("FAIL checked_div ok"); };
    if checked_overflow_flag() != 0 { fail = fail + 1; print("FAIL flag clear after div"); };
    // div-by-zero
    let _x: i64 = checked_div(10, 0);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL flag set on div0"); };
    // i64::MIN / -1 overflow
    let _y: i64 = checked_div(imin, -1);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL flag set on min/-1"); };

    // checked_rem
    if checked_rem(10, 3) != 1 { fail = fail + 1; print("FAIL checked_rem ok"); };
    if checked_overflow_flag() != 0 { fail = fail + 1; print("FAIL flag clear after rem"); };
    let _z: i64 = checked_rem(10, 0);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL flag set on rem0"); };

    // checked_neg
    if checked_neg(7) != -7 { fail = fail + 1; print("FAIL checked_neg ok"); };
    if checked_overflow_flag() != 0 { fail = fail + 1; print("FAIL flag clear after neg"); };
    let _n: i64 = checked_neg(imin);
    if checked_overflow_flag() != 1 { fail = fail + 1; print("FAIL flag set on neg min"); };

    // wrapping_div: silent on div-by-zero
    if wrapping_div(10, 0) != 0 { fail = fail + 1; print("FAIL wrapping_div 0"); };
    if wrapping_div(imin, -1) != imin { fail = fail + 1; print("FAIL wrapping_div min"); };

    // wrapping_rem
    if wrapping_rem(10, 0) != 0 { fail = fail + 1; print("FAIL wrapping_rem 0"); };
    if wrapping_rem(imin, -1) != 0 { fail = fail + 1; print("FAIL wrapping_rem min"); };

    // wrapping_neg: modular -> i64::MIN unchanged (two's complement)
    if wrapping_neg(7) != -7 { fail = fail + 1; print("FAIL wrapping_neg 7"); };
    if wrapping_neg(imin) != imin { fail = fail + 1; print("FAIL wrapping_neg min"); };

    // saturating_neg: clamp i64::MIN to i64::MAX
    if saturating_neg(7) != -7 { fail = fail + 1; print("FAIL saturating_neg 7"); };
    if saturating_neg(imin) != imax { fail = fail + 1; print("FAIL saturating_neg min"); };

    if fail == 0 { print("OK checked_div_neg"); return 0; };
    return 1;
}
