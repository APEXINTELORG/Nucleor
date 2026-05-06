// Helper1 v0874: ML-14 NN/autodiff Conv2D bridge.
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

fn vec1_bits(a: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(a));
    return v;
}

fn vec4_bits(a: f64, b: f64, c: f64, d: f64) -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(a));
    vec_push(v, f64_to_bits(b));
    vec_push(v, f64_to_bits(c));
    vec_push(v, f64_to_bits(d));
    return v;
}

fn vec4_ad(a: f64, b: f64, c: f64, d: f64) -> i64 {
    ad_reset();
    let v: i64 = vec_new();
    vec_push(v, ad_var(f64_to_bits(a)));
    vec_push(v, ad_var(f64_to_bits(b)));
    vec_push(v, ad_var(f64_to_bits(c)));
    vec_push(v, ad_var(f64_to_bits(d)));
    return v;
}

fn check_conv2d_value_and_input_grad() -> i64 {
    differentiable_clear();

    let x_bits: i64 = vec4_bits(1.0, 2.0, 3.0, 4.0);
    let kernel: i64 = vec4_bits(1.0, 0.5, -0.25, 2.0);
    let classic_out: i64 = nn_conv2d(x_bits, kernel, 1, 1, 2, 2, 2, 2, 1, 0);

    let x_ad: i64 = vec4_ad(1.0, 2.0, 3.0, 4.0);
    let ad_out: i64 = nn_conv2d_ad(x_ad, kernel, 1, 1, 2, 2, 2, 2, 1, 0);

    if vec_len(ad_out) != 1 { return 1; };
    let y0: i64 = vec_get(ad_out, 0);
    if close(ad_value(y0), vec_get(classic_out, 0), 0.0000001) != 1 { return 2; };

    let grad_out: i64 = vec1_bits(1.0);
    let back: i64 = nn_conv2d_backward(grad_out, x_bits, kernel, 1, 1, 2, 2, 2, 2, 1, 0);
    let dx: i64 = vec_get(back, 0);

    if close(ad_grad(y0, vec_get(x_ad, 0)), vec_get(dx, 0), 0.0000001) != 1 { return 4; };
    if close(ad_grad(y0, vec_get(x_ad, 1)), vec_get(dx, 1), 0.0000001) != 1 { return 8; };
    if close(ad_grad(y0, vec_get(x_ad, 2)), vec_get(dx, 2), 0.0000001) != 1 { return 16; };
    if close(ad_grad(y0, vec_get(x_ad, 3)), vec_get(dx, 3), 0.0000001) != 1 { return 32; };

    if differentiable_is("nuc_nn_conv2d") != 1 { return 64; };
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = nn_autodiff_limitations();
    if str_index_of(s, "Conv2D") < 0 { return 128; };
    if str_index_of(s, "depthwise") < 0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_conv2d_value_and_input_grad();
    fails = fails + check_limitations();
    return fails;
}
