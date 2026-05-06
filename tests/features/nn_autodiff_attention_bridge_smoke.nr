// Helper1 v0876: ML-14 transformer attention autodiff bridge.
//
// Expected: rc=0.

import "stdlib/rods/transformer_autodiff.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn vec1_bits(a: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(a));
    return v;
}

fn vec2_bits(a: f64, b: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(a));
    vec_push(v, f64_to_bits(b));
    return v;
}

fn vec1_ad(a: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, ad_var(f64_to_bits(a)));
    return v;
}

fn vec2_ad(a: f64, b: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, ad_var(f64_to_bits(a)));
    vec_push(v, ad_var(f64_to_bits(b)));
    return v;
}

fn check_attention_value_and_input_grad() -> i64 {
    differentiable_clear();
    ad_reset();

    let q_bits: i64 = vec1_bits(0.0);
    let k_bits: i64 = vec2_bits(1.0, -1.0);
    let v_bits: i64 = vec2_bits(2.0, 4.0);
    let classic_out: i64 = tf_attention_split(q_bits, k_bits, v_bits, 1, 2, 1, 1);

    let q_ad: i64 = vec1_ad(0.0);
    let k_ad: i64 = vec2_ad(1.0, -1.0);
    let v_ad: i64 = vec2_ad(2.0, 4.0);
    let ad_out: i64 = tf_attention_split_ad(q_ad, k_ad, v_ad, 1, 2, 1, 1, 0);

    if vec_len(ad_out) != 1 { return 1; };
    let y0: i64 = vec_get(ad_out, 0);
    if close(ad_value(y0), vec_get(classic_out, 0), 0.0000001) != 1 { return 2; };

    if close(ad_grad(y0, vec_get(v_ad, 0)), f64_to_bits(0.5), 0.0000001) != 1 { return 4; };
    if close(ad_grad(y0, vec_get(v_ad, 1)), f64_to_bits(0.5), 0.0000001) != 1 { return 8; };
    if close(ad_grad(y0, vec_get(q_ad, 0)), f64_to_bits(0.0 - 1.0), 0.0000001) != 1 { return 16; };

    if differentiable_is("nuc_tf_attention_split") != 1 { return 32; };
    return 0;
}

fn check_causal_attention_value() -> i64 {
    differentiable_clear();
    ad_reset();

    let q_bits: i64 = vec2_bits(0.0, 0.0);
    let k_bits: i64 = vec2_bits(1.0, -1.0);
    let v_bits: i64 = vec2_bits(2.0, 4.0);
    let classic_out: i64 = tf_attention_split_masked(q_bits, k_bits, v_bits, 2, 2, 1, 1, 1);

    let q_ad: i64 = vec2_ad(0.0, 0.0);
    let k_ad: i64 = vec2_ad(1.0, -1.0);
    let v_ad: i64 = vec2_ad(2.0, 4.0);
    let ad_out: i64 = tf_attention_split_ad(q_ad, k_ad, v_ad, 2, 2, 1, 1, 1);

    if vec_len(ad_out) != 2 { return 64; };
    if close(ad_value(vec_get(ad_out, 0)), vec_get(classic_out, 0), 0.0000001) != 1 { return 128; };
    if close(ad_value(vec_get(ad_out, 1)), vec_get(classic_out, 1), 0.0000001) != 1 { return 256; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = tf_autodiff_limitations();
    if str_index_of(s, "classic transformer attention") < 0 { return 512; };
    if str_index_of(s, "Flash/GQA") < 0 { return 1024; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_attention_value_and_input_grad();
    fails = fails + check_causal_attention_value();
    fails = fails + check_limitations();
    return fails;
}
