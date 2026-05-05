// v0.8.193 stdlib/rods/diffusion.nr first test coverage.
//
// Diffusion-model primitives — DDPM schedules, rectified flow,
// CFG, AdaLN. Pre-v0.8.193: zero coverage.
//
// Locks four lifecycle invariants on the schedule + rectified-
// flow surfaces (heaviest path with cleanest closed-form math):
//
//   1. **Linear schedule length**: `linear_schedule(N=10, ...)`
//      returns Vec of length 10.
//   2. **Cosine schedule length**: same shape.
//   3. **Rectified-flow interpolation at t=0** equals x0.
//   4. **Rectified-flow target = x1 - x0** element-wise.
//
// Expected: rc=0.

import "stdlib/rods/diffusion.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_v(vals: Vec<f64>) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(vals) {
        v.push(f64_to_bits(vec_get(vals, i)));
        i = i + 1;
    };
    return v;
}

fn check_linear_schedule_length() -> i64 {
    // Linear schedule returns flat Vec of 5*T elements:
    // [betas..., alphas..., alpha_bars..., sqrt_alpha_bars...,
    //  sqrt_one_minus_alpha_bars...]
    let s: i64 = diff_linear_schedule(10, f64_to_bits(0.0001), f64_to_bits(0.02));
    if s == 0 { return 1; };
    if vec_len(s) != 50 { return 2; };
    return 0;
}

fn check_cosine_schedule_length() -> i64 {
    let s: i64 = diff_cosine_schedule(10);
    if s == 0 { return 4; };
    if vec_len(s) != 50 { return 8; };
    return 0;
}

fn check_rectified_flow_interp_t0() -> i64 {
    let mut x0: Vec<i64> = Vec::new();
    x0.push(f64_to_bits(1.0));
    x0.push(f64_to_bits(2.0));
    let mut x1: Vec<i64> = Vec::new();
    x1.push(f64_to_bits(5.0));
    x1.push(f64_to_bits(7.0));
    // RF interp: x_t = (1-t)*x0 + t*x1; at t=0 → x0
    let xt: i64 = diff_rf_interp(x0, x1, f64_to_bits(0.0));
    if close(vec_get(xt, 0), f64_to_bits(1.0), 1e-9) != 1 { return 16; };
    if close(vec_get(xt, 1), f64_to_bits(2.0), 1e-9) != 1 { return 32; };
    return 0;
}

fn check_rectified_flow_target() -> i64 {
    let mut x0: Vec<i64> = Vec::new();
    x0.push(f64_to_bits(1.0));
    x0.push(f64_to_bits(2.0));
    let mut x1: Vec<i64> = Vec::new();
    x1.push(f64_to_bits(5.0));
    x1.push(f64_to_bits(7.0));
    // RF target = x1 - x0 = [4, 5]
    let t: i64 = diff_rf_target(x0, x1);
    if close(vec_get(t, 0), f64_to_bits(4.0), 1e-9) != 1 { return 64; };
    if close(vec_get(t, 1), f64_to_bits(5.0), 1e-9) != 1 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_linear_schedule_length();
    fails = fails + check_cosine_schedule_length();
    fails = fails + check_rectified_flow_interp_t0();
    fails = fails + check_rectified_flow_target();
    return fails;
}
