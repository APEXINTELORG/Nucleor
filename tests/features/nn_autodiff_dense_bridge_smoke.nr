// Helper1 v0867: ML-14 first NN/autodiff dense bridge.
//
// Expected: rc=0.

import "stdlib/rods/nn_autodiff.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_input_bits(a: f64, b: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(a));
    vec_push(v, f64_to_bits(b));
    return v;
}

fn make_input_ad(a: f64, b: f64) -> i64 {
    ad_reset();
    let v: i64 = vec_new();
    vec_push(v, ad_var(f64_to_bits(a)));
    vec_push(v, ad_var(f64_to_bits(b)));
    return v;
}

fn check_dense_value_and_input_grad() -> i64 {
    nuc_nn_reset_rng();
    differentiable_clear();

    let layer: i64 = nuc_nn_dense_new(2, 1);
    let x_bits: i64 = make_input_bits(2.0, -1.0);
    let classic_out: i64 = nuc_nn_dense_forward(layer, x_bits);

    let x_ad: i64 = make_input_ad(2.0, -1.0);
    let ad_out_vec: i64 = nn_dense_forward_ad(layer, x_ad);
    let y: i64 = vec_get(ad_out_vec, 0);

    if close(ad_value(y), vec_get(classic_out, 0), 0.0000001) != 1 { return 1; };

    let x0: i64 = vec_get(x_ad, 0);
    let x1: i64 = vec_get(x_ad, 1);
    if close(ad_grad(y, x0), nn_dense_weight(layer, 0, 0), 0.0000001) != 1 { return 2; };
    if close(ad_grad(y, x1), nn_dense_weight(layer, 0, 1), 0.0000001) != 1 { return 4; };

    if differentiable_is("nuc_nn_dense_forward") != 1 { return 8; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = nn_autodiff_limitations();
    if str_index_of(s, "input gradients") < 0 { return 16; };
    if str_index_of(s, "Parameter gradients") < 0 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_dense_value_and_input_grad();
    fails = fails + check_limitations();
    return fails;
}
