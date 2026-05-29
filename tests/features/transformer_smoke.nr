// v0.8.186 stdlib/rods/transformer.nr first test coverage.
//
// Classic transformer building blocks: softmax, layer norm,
// attention, multi-head, feedforward, positional encoding,
// cross-entropy. Pre-v0.8.186: zero coverage.
//
// Locks four textbook softmax invariants — softmax is the
// most contained primitive (single Vec input, deterministic
// output) and exercises the f64-bits round-trip cleanly:
//
//   1. Sum to 1: softmax([1, 2, 3]) entries sum to 1.0.
//   2. Argmax preserved: softmax preserves the argmax (largest
//      input → largest output).
//   3. Equal inputs → uniform: softmax([1, 1, 1]) → all 1/3.
//   4. Translation invariance: softmax(x) == softmax(x+c).
//
// Expected: rc=0.

import "stdlib/rods/transformer.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_sum_to_1() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    let s: i64 = tf_softmax(v);
    let mut sum: f64 = 0.0;
    let mut i: i64 = 0;
    while i < 3 {
        sum = sum + f64_from_bits(vec_get(s, i));
        i = i + 1;
    };
    let diff: f64 = sum - 1.0;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff > 1e-9 { return 1; };
    return 0;
}

fn check_argmax_preserved() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(5.0));
    v.push(f64_to_bits(2.0));
    let s: i64 = tf_softmax(v);
    let p0: f64 = f64_from_bits(vec_get(s, 0));
    let p1: f64 = f64_from_bits(vec_get(s, 1));
    let p2: f64 = f64_from_bits(vec_get(s, 2));
    if p1 <= p0 { return 2; };
    if p1 <= p2 { return 4; };
    return 0;
}

fn check_uniform_for_equal_inputs() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(1.0));
    let s: i64 = tf_softmax(v);
    let mut i: i64 = 0;
    while i < 4 {
        if close(vec_get(s, i), f64_to_bits(0.25), 1e-9) != 1 { return 8; };
        i = i + 1;
    };
    return 0;
}

fn check_translation_invariance() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(1.0));
    a.push(f64_to_bits(2.0));
    a.push(f64_to_bits(3.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(11.0));  // a + 10 element-wise
    b.push(f64_to_bits(12.0));
    b.push(f64_to_bits(13.0));
    let sa: i64 = tf_softmax(a);
    let sb: i64 = tf_softmax(b);
    let mut i: i64 = 0;
    while i < 3 {
        if close(vec_get(sa, i), vec_get(sb, i), 1e-9) != 1 { return 16; };
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_sum_to_1();
    fails = fails + check_argmax_preserved();
    fails = fails + check_uniform_for_equal_inputs();
    fails = fails + check_translation_invariance();
    return fails;
}
