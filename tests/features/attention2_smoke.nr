// v0.8.229 stdlib/rods/attention2.nr first test coverage.
//
// Modern attention variants — FlashAttention, GQA, MLA, sliding-
// window, differential. Pre-v0.8.229: zero coverage on the
// standalone rod. ML-1 fixes (v0.8.45 / v0.8.66) wired the rod
// to the C runtime; this fixture guards the corrected sigs.
//
// Setup: seq=2 tokens, d_k=2. Q and K are all zeros so attention
// scores Q·K^T / sqrt(d_k) are zero everywhere → softmax is
// uniform [0.5, 0.5]. With V = [3, 4, 5, 6] (token 0 = (3,4),
// token 1 = (5,6)), each output token = mean of V = (4, 5).
//
// Locks four invariants:
//
//   1. **Output length matches seq * d_k** — flat output is
//      [seq, d_k].
//   2. **Uniform softmax produces V mean** — token 0 row 0 = 4.
//   3. **Both rows are identical** — uniform attention over both
//      tokens, so token 0 output == token 1 output.
//   4. **Sliding-window is causal** — token 0 sees only V[0],
//      so output[0] == V[0] = (3, 4); token 1 sees V[0] and
//      V[1] uniformly → (4, 5). Flash attention is bidirectional;
//      sliding-window is causal.
//
// Expected: rc=0.

import "stdlib/rods/attention2.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn build_zero_qk() -> i64 {
    // [seq=2, d_k=2] all zeros
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(0.0)); v.push(f64_to_bits(0.0));
    v.push(f64_to_bits(0.0)); v.push(f64_to_bits(0.0));
    return v;
}

fn build_v() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.0)); v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(5.0)); v.push(f64_to_bits(6.0));
    return v;
}

fn check_output_length() -> i64 {
    let q: i64 = build_zero_qk();
    let k: i64 = build_zero_qk();
    let v: i64 = build_v();
    let out: i64 = attn_flash(q, k, v, 2, 2, 32);
    if vec_len(out) != 4 { return 1; };
    return 0;
}

fn check_uniform_mean() -> i64 {
    let q: i64 = build_zero_qk();
    let k: i64 = build_zero_qk();
    let v: i64 = build_v();
    let out: i64 = attn_flash(q, k, v, 2, 2, 32);
    if close(vec_get(out, 0), f64_to_bits(4.0), 1e-6) != 1 { return 2; };
    if close(vec_get(out, 1), f64_to_bits(5.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_rows_identical() -> i64 {
    let q: i64 = build_zero_qk();
    let k: i64 = build_zero_qk();
    let v: i64 = build_v();
    let out: i64 = attn_flash(q, k, v, 2, 2, 32);
    if close(vec_get(out, 2), vec_get(out, 0), 1e-9) != 1 { return 8; };
    if close(vec_get(out, 3), vec_get(out, 1), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_sliding_window_causal() -> i64 {
    let q: i64 = build_zero_qk();
    let k: i64 = build_zero_qk();
    let v: i64 = build_v();
    // Causal: token 0 sees only V[0]=(3,4); token 1 sees V[0,1]
    // uniformly → (4, 5).
    let out: i64 = attn_sliding_window(q, k, v, 2, 2, 2);
    if close(vec_get(out, 0), f64_to_bits(3.0), 1e-6) != 1 { return 32; };
    if close(vec_get(out, 1), f64_to_bits(4.0), 1e-6) != 1 { return 64; };
    if close(vec_get(out, 2), f64_to_bits(4.0), 1e-6) != 1 { return 128; };
    if close(vec_get(out, 3), f64_to_bits(5.0), 1e-6) != 1 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_output_length();
    fails = fails + check_uniform_mean();
    fails = fails + check_rows_identical();
    fails = fails + check_sliding_window_causal();
    return fails;
}
