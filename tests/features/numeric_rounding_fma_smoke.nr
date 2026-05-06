// Helper1 v0858: NUM-G11 / NUM-G12 numeric rounding + FMA surface.
//
// Locks:
//   1. rounding mode get/set round-trips all four stable mode IDs.
//   2. invalid rounding mode returns -1.
//   3. f64 next-up / next-down move around 1.0 in the right direction.
//   4. f64 and f32 fused multiply-add helpers compute 2*3+4 = 10.
//
// Expected: rc=0.

import "stdlib/rods/numeric.nr"

fn check_rounding_modes() -> i64 {
    let original: i64 = n_get_rounding_mode();
    if original < 0 { return 1; };

    let old_down: i64 = n_set_rounding_mode(n_rounding_downward());
    if old_down < 0 { return 2; };
    if n_get_rounding_mode() != n_rounding_downward() { n_set_rounding_mode(original); return 4; };

    let old_up: i64 = n_set_rounding_mode(n_rounding_upward());
    if old_up != n_rounding_downward() { n_set_rounding_mode(original); return 8; };
    if n_get_rounding_mode() != n_rounding_upward() { n_set_rounding_mode(original); return 16; };

    let old_zero: i64 = n_set_rounding_mode(n_rounding_toward_zero());
    if old_zero != n_rounding_upward() { n_set_rounding_mode(original); return 32; };
    if n_get_rounding_mode() != n_rounding_toward_zero() { n_set_rounding_mode(original); return 64; };

    let old_near: i64 = n_set_rounding_mode(n_rounding_nearest());
    if old_near != n_rounding_toward_zero() { n_set_rounding_mode(original); return 128; };
    if n_get_rounding_mode() != n_rounding_nearest() { n_set_rounding_mode(original); return 256; };

    if n_set_rounding_mode(99) != -1 { n_set_rounding_mode(original); return 512; };
    n_set_rounding_mode(original);
    return 0;
}

fn check_next_up_down() -> i64 {
    let one: i64 = f64_to_bits(1.0);
    let up: f64 = f64_from_bits(n_f64_next_up(one));
    let down: f64 = f64_from_bits(n_f64_next_down(one));
    if up <= 1.0 { return 1024; };
    if down >= 1.0 { return 2048; };
    return 0;
}

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_fma() -> i64 {
    let f64_res: i64 = n_f64_mul_add(f64_to_bits(2.0), f64_to_bits(3.0), f64_to_bits(4.0));
    if close(f64_res, f64_to_bits(10.0), 1e-12) != 1 { return 4096; };

    let f32_res: i64 = n_f32_mul_add(f32(2), f32(3), f32(4));
    if f32_int(f32_res) != 10 { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_rounding_modes();
    fails = fails + check_next_up_down();
    fails = fails + check_fma();
    return fails;
}
