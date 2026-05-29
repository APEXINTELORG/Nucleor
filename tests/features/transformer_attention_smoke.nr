// v0.8.254 stdlib/rods/transformer.nr attention arity drift FIX coverage.
//
// Pre-v0.8.254 the rod declared `nuc_tf_attention` 5-arg
// (`Q, K, V, seq_len, d_k`) but the C runtime took 7
// (`seq_q, seq_k, d_k, d_v`). The 5-arg call site read garbage
// from the un-pushed slots; result Vec was sized
// `seq_q * d_v` with random bits. Same bug class as v0.8.45 ML-1
// `nuc_attn_flash` and v0.8.252 kv_cache `get_k`/`get_v`. Surfaced
// by TRACK A `extern_arity_drift_sweep_2026-05-05`.
//
// Fix (Plan B, non-breaking):
// - C `nuc_tf_attention` 7-arg renamed to `_split`. Same for `multihead`.
// - New 5-arg `nuc_tf_attention(Q, K, V, seq_len, d_k)` calls
//   `_split(Q, K, V, seq_len, seq_len, d_k, d_k)` — assumes
//   self-attention (seq_q == seq_k) and same K/V dim (d_k == d_v).
// - 6-arg `nuc_tf_multihead(Q, K, V, seq_len, d_model, n_heads)`
//   shims similarly.
// - Adopters who need cross-attention or asymmetric d_k/d_v call
//   the new `tf_attention_split` / `tf_multihead_split` rod fns.
//
// Locks textbook self-attention invariants:
//
//   1. Single-token self-attention is identity — seq_len=1,
//      Q=K=V=[1.0, 2.0] → output equals V (softmax of one score
//      is 1.0, weighted sum equals V).
//   2. 5-arg agrees with 7-arg `_split` — same Q/K/V/seq_len/d_k
//      run through both forms with seq_q=seq_k=seq_len, d_k=d_v=d_k
//      produces bit-identical output.
//   3. Multihead with n_heads=1 equals attention — same Q/K/V
//      through `tf_multihead(seq_len=1, d_model=2, n_heads=1)`
//      should equal `tf_attention(seq_len=1, d_k=2)`.
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

fn make_v2(a: f64, b: f64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    return v;
}

fn check_single_token_identity() -> i64 {
    // seq_len=1, d_k=2: single query attends to single key/value.
    // Softmax of one score = 1.0; output = V verbatim.
    let q: Vec<i64> = make_v2(1.0, 2.0);
    let k: Vec<i64> = make_v2(1.0, 2.0);
    let v: Vec<i64> = make_v2(3.0, 4.0);
    let out: i64 = tf_attention(q, k, v, 1, 2);
    if out == 0 { return 1; };
    if vec_len(out) != 2 { return 2; };
    if close(vec_get(out, 0), f64_to_bits(3.0), 1e-9) != 1 { return 4; };
    if close(vec_get(out, 1), f64_to_bits(4.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_split_matches_5arg() -> i64 {
    // Run the same input through 5-arg and 7-arg (`_split`) and
    // confirm bit-identical output. seq_q=seq_k=seq_len, d_k=d_v=d_k.
    let q: Vec<i64> = make_v2(1.0, 2.0);
    let k: Vec<i64> = make_v2(1.0, 2.0);
    let v: Vec<i64> = make_v2(3.0, 4.0);
    let out_5: i64 = tf_attention(q, k, v, 1, 2);
    let q2: Vec<i64> = make_v2(1.0, 2.0);
    let k2: Vec<i64> = make_v2(1.0, 2.0);
    let v2: Vec<i64> = make_v2(3.0, 4.0);
    let out_7: i64 = tf_attention_split(q2, k2, v2, 1, 1, 2, 2);
    if vec_len(out_5) != vec_len(out_7) { return 16; };
    if vec_get(out_5, 0) != vec_get(out_7, 0) { return 32; };
    if vec_get(out_5, 1) != vec_get(out_7, 1) { return 64; };
    return 0;
}

fn check_multihead_one_head_matches_attention() -> i64 {
    // n_heads=1, d_model=d_k → multihead degenerates to plain attention.
    let q: Vec<i64> = make_v2(1.0, 2.0);
    let k: Vec<i64> = make_v2(1.0, 2.0);
    let v: Vec<i64> = make_v2(3.0, 4.0);
    let mh: i64 = tf_multihead(q, k, v, 1, 2, 1);
    if mh == 0 { return 128; };
    if vec_len(mh) != 2 { return 256; };
    let q2: Vec<i64> = make_v2(1.0, 2.0);
    let k2: Vec<i64> = make_v2(1.0, 2.0);
    let v2: Vec<i64> = make_v2(3.0, 4.0);
    let attn: i64 = tf_attention(q2, k2, v2, 1, 2);
    if vec_get(mh, 0) != vec_get(attn, 0) { return 512; };
    if vec_get(mh, 1) != vec_get(attn, 1) { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_single_token_identity();
    fails = fails + check_split_matches_5arg();
    fails = fails + check_multihead_one_head_matches_attention();
    return fails;
}
