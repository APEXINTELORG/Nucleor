// helper1 v0861 ML-1/ML-4 - attention2 rectangular cross-attention smoke.
//
// Proves the corrected 7-arg flash-attention ABI and the public
// `attn_flash_cross` / `attn_gqa_cross` wrappers handle seq_q != seq_k.

import "stdlib/rods/attention2.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn zeros(n: i64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        v.push(f64_to_bits(0.0));
        i = i + 1;
    };
    return v;
}

fn v_flash_cross() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(6.0));
    v.push(f64_to_bits(9.0));
    return v;
}

fn v_gqa_cross() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(5.0));
    return v;
}

fn check_flash_rectangular_cross_attention() -> i64 {
    let q: Vec<i64> = zeros(1);
    let k: Vec<i64> = zeros(3);
    let v: Vec<i64> = v_flash_cross();
    let out: i64 = attn_flash_cross(q, k, v, 1, 3, 1, 2);
    if out == 0 { return 1; };
    if vec_len(out) != 1 { return 2; };
    if close(vec_get(out, 0), f64_to_bits(6.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_gqa_rectangular_cross_attention() -> i64 {
    let q: Vec<i64> = zeros(2);
    let k: Vec<i64> = zeros(2);
    let v: Vec<i64> = v_gqa_cross();
    let out: i64 = attn_gqa_cross(q, k, v, 1, 2, 1, 2, 1);
    if out == 0 { return 8; };
    if vec_len(out) != 2 { return 16; };
    if close(vec_get(out, 0), f64_to_bits(4.0), 1e-6) != 1 { return 32; };
    if close(vec_get(out, 1), f64_to_bits(4.0), 1e-6) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_flash_rectangular_cross_attention();
    fails = fails + check_gqa_rectangular_cross_attention();
    return fails;
}
