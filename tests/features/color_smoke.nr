// v0.8.127 stdlib/rods/color.nr first test coverage.
//
// Color space conversions (RGB ↔ HSV ↔ Lab) + delta_e + lerp.
// Inputs are f64-bits normalized 0..1 for RGB; HSV uses 0..360 H,
// 0..1 S/V; Lab uses standard CIELAB ranges.
//
// Locks textbook color invariants:
//   1. RGB→HSV: pure red (1,0,0) → H≈0, S=1, V=1.
//   2. RGB→HSV: pure green (0,1,0) → H≈120.
//   3. HSV→RGB→HSV round-trip preserves (H, S, V).
//   4. White (1,1,1) → S=0 (saturation undefined → 0).
//   5. Black (0,0,0) → V=0.
//   6. delta_e between identical Lab points is 0.
//
// Returns are COVec handles; cells via vec_get.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/color.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-4 { return 1; };
    return 0;
}

fn check_red_to_hsv() -> i64 {
    let hsv: i64 = color_rgb_to_hsv(f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let h: i64 = vec_get(hsv, 0);
    let s: i64 = vec_get(hsv, 1);
    let v: i64 = vec_get(hsv, 2);
    if close(h, f64_to_bits(0.0)) != 1 { return 1; };
    if close(s, f64_to_bits(1.0)) != 1 { return 2; };
    if close(v, f64_to_bits(1.0)) != 1 { return 4; };
    return 0;
}

fn check_green_to_hsv() -> i64 {
    let hsv: i64 = color_rgb_to_hsv(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    let h: i64 = vec_get(hsv, 0);
    if close(h, f64_to_bits(120.0)) != 1 { return 8; };
    return 0;
}

fn check_white_zero_saturation() -> i64 {
    let hsv: i64 = color_rgb_to_hsv(f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    let s: i64 = vec_get(hsv, 1);
    if close(s, f64_to_bits(0.0)) != 1 { return 16; };
    return 0;
}

fn check_black_zero_value() -> i64 {
    let hsv: i64 = color_rgb_to_hsv(f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let v: i64 = vec_get(hsv, 2);
    if close(v, f64_to_bits(0.0)) != 1 { return 32; };
    return 0;
}

fn check_hsv_rgb_round_trip() -> i64 {
    // Magenta — H=300, S=1, V=1
    let rgb: i64 = color_hsv_to_rgb(f64_to_bits(300.0), f64_to_bits(1.0), f64_to_bits(1.0));
    let hsv: i64 = color_rgb_to_hsv(vec_get(rgb, 0), vec_get(rgb, 1), vec_get(rgb, 2));
    let h: i64 = vec_get(hsv, 0);
    let s: i64 = vec_get(hsv, 1);
    let v: i64 = vec_get(hsv, 2);
    if close(h, f64_to_bits(300.0)) != 1 { return 64; };
    if close(s, f64_to_bits(1.0)) != 1 { return 128; };
    if close(v, f64_to_bits(1.0)) != 1 { return 256; };
    return 0;
}

fn check_delta_e_self() -> i64 {
    // delta_e between a Lab and itself must be 0.
    let lab: i64 = color_rgb_to_lab(f64_to_bits(0.5), f64_to_bits(0.3), f64_to_bits(0.7));
    let de: i64 = color_delta_e(lab, lab);
    if close(de, f64_to_bits(0.0)) != 1 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_red_to_hsv();
    fails = fails + check_green_to_hsv();
    fails = fails + check_white_zero_saturation();
    fails = fails + check_black_zero_value();
    fails = fails + check_hsv_rgb_round_trip();
    fails = fails + check_delta_e_self();
    return fails;
}
