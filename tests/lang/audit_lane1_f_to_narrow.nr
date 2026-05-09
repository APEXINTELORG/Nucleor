// Lane 1 audit fix (2026-05-08) — closes F-NUM-001.
// Pre-fix `f64 as {i8,u8,i16,u16}` (and the f32 sisters) fell through
// to the integer-bit-mask `__nucleor_as_<T>` helpers operating on the
// f64 BIT PATTERN — every "round" f64 with mantissa-low-bits-zero
// silently became 0 (image / color / audio quantization paths).
// Post-fix routes through the saturating-truncate helpers per
// RFC-0015 §3.5 (NaN -> 0, saturate at the destination range, then
// truncate toward zero).
fn main() -> i32 {
    let mut fail: i64 = 0;

    // Mid-range f64 -> narrow signed/unsigned ints.
    let v: f64 = 50.0;
    let v_i8: i8 = v as i8;
    let v_u8: u8 = v as u8;
    let v_i16: i16 = v as i16;
    let v_u16: u16 = v as u16;
    if (v_i8 as i64) != 50 { fail = fail + 1; print("FAIL: f64(50) as i8\n"); };
    if (v_u8 as i64) != 50 { fail = fail + 1; print("FAIL: f64(50) as u8\n"); };
    if (v_i16 as i64) != 50 { fail = fail + 1; print("FAIL: f64(50) as i16\n"); };
    if (v_u16 as i64) != 50 { fail = fail + 1; print("FAIL: f64(50) as u16\n"); };

    // Saturating: out-of-range positive -> upper bound.
    let big: f64 = 1000.0;
    let big_i8: i8 = big as i8;
    let big_u8: u8 = big as u8;
    if (big_i8 as i64) != 127 { fail = fail + 1; print("FAIL: f64(1000) as i8 should saturate to 127\n"); };
    if (big_u8 as i64) != 255 { fail = fail + 1; print("FAIL: f64(1000) as u8 should saturate to 255\n"); };

    // Saturating: out-of-range negative -> lower bound (i8) or 0 (u8).
    let neg: f64 = 0.0 - 1000.0;
    let neg_i8: i8 = neg as i8;
    let neg_u8: u8 = neg as u8;
    if (neg_i8 as i64) != (0 - 128) { fail = fail + 1; print("FAIL: f64(-1000) as i8 should saturate to -128\n"); };
    if (neg_u8 as i64) != 0 { fail = fail + 1; print("FAIL: f64(-1000) as u8 should saturate to 0\n"); };

    if fail == 0 { print("PASS: f-to-narrow saturating-truncate\n"); };
    fail as i32
}
