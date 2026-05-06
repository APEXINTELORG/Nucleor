// ML-10 — causal transformer attention + encoder-decoder attention block.
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

fn make_v1(a: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    return v;
}

fn make_v2(a: f64, b: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    return v;
}

fn make_v3(a: f64, b: f64, c: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    v.push(f64_to_bits(c));
    return v;
}

fn check_causal_attention_prefix_means() -> i64 {
    let q: i64 = make_v3(0.0, 0.0, 0.0);
    let k: i64 = make_v3(0.0, 0.0, 0.0);
    let v: i64 = make_v3(3.0, 6.0, 9.0);
    let out: i64 = tf_attention_causal(q, k, v, 3, 1);
    if vec_len(out) != 3 { return 1; };
    if close(vec_get(out, 0), f64_to_bits(3.0), 0.000001) != 1 { return 2; };
    if close(vec_get(out, 1), f64_to_bits(4.5), 0.000001) != 1 { return 4; };
    if close(vec_get(out, 2), f64_to_bits(6.0), 0.000001) != 1 { return 8; };
    return 0;
}

fn check_masked_flag_off_matches_full_attention() -> i64 {
    let q: i64 = make_v3(0.0, 0.0, 0.0);
    let k: i64 = make_v3(0.0, 0.0, 0.0);
    let v: i64 = make_v3(3.0, 6.0, 9.0);
    let full: i64 = tf_attention_split_masked(q, k, v, 3, 3, 1, 1, 0);
    if vec_len(full) != 3 { return 16; };
    if close(vec_get(full, 0), f64_to_bits(6.0), 0.000001) != 1 { return 32; };
    if close(vec_get(full, 1), f64_to_bits(6.0), 0.000001) != 1 { return 64; };
    if close(vec_get(full, 2), f64_to_bits(6.0), 0.000001) != 1 { return 128; };
    return 0;
}

fn check_encoder_decoder_block_crosses_memory() -> i64 {
    let tq: i64 = make_v1(0.0);
    let tk: i64 = make_v1(0.0);
    let tv: i64 = make_v1(7.0);
    let mem_k: i64 = make_v2(0.0, 0.0);
    let mem_v: i64 = make_v2(2.0, 4.0);
    let out: i64 = tf_encoder_decoder_block(tq, tk, tv, mem_k, mem_v, 1, 2, 1, 1);
    if vec_len(out) != 1 { return 256; };
    if close(vec_get(out, 0), f64_to_bits(3.0), 0.000001) != 1 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_causal_attention_prefix_means();
    fails = fails + check_masked_flag_off_matches_full_attention();
    fails = fails + check_encoder_decoder_block_crosses_memory();
    return fails;
}
