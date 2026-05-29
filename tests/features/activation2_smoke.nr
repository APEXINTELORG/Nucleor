// v0.8.202 stdlib/rods/activation2.nr first test coverage.
//
// Modern transformer activations + normalizations (SwiGLU, GELU,
// SiLU, JumpReLU, DyT, RMSNorm, QK-Norm, RoPE, DeepNorm, softmax,
// sigmoid). Pre-v0.8.202: zero coverage.
//
// Locks four textbook fixed-point invariants:
//
//   1. GELU(0) == 0 — gelu has a zero at x=0 (0 * 0.5 * 1 = 0).
//   2. SiLU(0) == 0 — x · sigmoid(x) at x=0 is 0 · 0.5 = 0.
//   3. Sigmoid(0) == 0.5 — 1/(1+e^0) = 1/2.
//   4. JumpReLU below threshold == 0 — jumprelu([0.5], θ=1.0)
//      gates the value to 0.
//
// Expected: rc=0.

import "stdlib/rods/activation2.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_gelu_zero() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    let out: i64 = act_gelu(v);
    if close(vec_get(out, 0), f64_to_bits(0.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_silu_zero() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    let out: i64 = act_silu(v);
    if close(vec_get(out, 0), f64_to_bits(0.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_sigmoid_zero() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0));
    let out: i64 = act_sigmoid(v);
    if close(vec_get(out, 0), f64_to_bits(0.5), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_jumprelu_below_threshold() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.5));
    let out: i64 = act_jumprelu(v, f64_to_bits(1.0));
    if close(vec_get(out, 0), f64_to_bits(0.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_gelu_zero();
    fails = fails + check_silu_zero();
    fails = fails + check_sigmoid_zero();
    fails = fails + check_jumprelu_below_threshold();
    return fails;
}
