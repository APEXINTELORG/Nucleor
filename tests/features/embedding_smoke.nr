// v0.8.132 stdlib/rods/embedding.nr first test coverage.
//
// Vector embedding tables — vocab × dim float matrix with
// per-token lookup, cosine similarity, dot product, nearest-k.
//
// Locks textbook embedding invariants:
//   1. cosine_sim(v, v) == 1.0 for any non-zero vector.
//   2. dot(v, v) == ||v||² (sum of squares).
//   3. cosine_sim of orthogonal vectors == 0.
//   4. set + lookup round-trip preserves the vector.
//
// Vec-of-f64-bits is what emb takes; we pass via Vec<i64> with
// f64_to_bits.
//
// Expected: rc=0.

import "stdlib/rods/embedding.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_cosine_self() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(5.0));
    let r: i64 = emb_cosine(v, v);
    if close(r, f64_to_bits(1.0)) != 1 { return 1; };
    return 0;
}

fn check_dot_self() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(2.0));
    v.push(f64_to_bits(3.0));
    // dot(v, v) = 1+4+9 = 14
    let r: i64 = emb_dot(v, v);
    if close(r, f64_to_bits(14.0)) != 1 { return 2; };
    return 0;
}

fn check_orthogonal_cosine() -> i64 {
    let mut a: Vec<i64> = Vec::new();
    a.push(f64_to_bits(1.0));
    a.push(f64_to_bits(0.0));
    let mut b: Vec<i64> = Vec::new();
    b.push(f64_to_bits(0.0));
    b.push(f64_to_bits(1.0));
    // cos(angle) of orthogonal vectors = 0
    let r: i64 = emb_cosine(a, b);
    if close(r, f64_to_bits(0.0)) != 1 { return 4; };
    return 0;
}

fn check_set_lookup() -> i64 {
    let e: i64 = emb_new(4, 3);
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(1.5));
    v.push(f64_to_bits(2.5));
    v.push(f64_to_bits(3.5));
    emb_set(e, 2, v);
    let got: i64 = emb_lookup(e, 2);
    if close(vec_get(got, 0), f64_to_bits(1.5)) != 1 { return 8; };
    if close(vec_get(got, 1), f64_to_bits(2.5)) != 1 { return 16; };
    if close(vec_get(got, 2), f64_to_bits(3.5)) != 1 { return 32; };
    emb_free(e);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_cosine_self();
    fails = fails + check_dot_self();
    fails = fails + check_orthogonal_cosine();
    fails = fails + check_set_lookup();
    return fails;
}
