// ML-8 — nn.nr convolution layers with weight-gradient coverage.
//
// Expected: rc=0.

import "stdlib/rods/nn.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn push_f(v: i64, x: f64) {
    vec_push(v, f64_to_bits(x));
}

fn make_vec2(a: f64, b: f64) -> i64 {
    let v: i64 = vec_new();
    push_f(v, a);
    push_f(v, b);
    return v;
}

fn make_vec3(a: f64, b: f64, c: f64) -> i64 {
    let v: i64 = vec_new();
    push_f(v, a);
    push_f(v, b);
    push_f(v, c);
    return v;
}

fn make_vec4(a: f64, b: f64, c: f64, d: f64) -> i64 {
    let v: i64 = vec_new();
    push_f(v, a);
    push_f(v, b);
    push_f(v, c);
    push_f(v, d);
    return v;
}

fn make_vec8() -> i64 {
    let v: i64 = vec_new();
    push_f(v, 1.0); push_f(v, 2.0); push_f(v, 3.0); push_f(v, 4.0);
    push_f(v, 5.0); push_f(v, 6.0); push_f(v, 7.0); push_f(v, 8.0);
    return v;
}

fn check_conv1d_forward_backward() -> i64 {
    let input: i64 = make_vec3(1.0, 2.0, 3.0);
    let kernel: i64 = make_vec2(2.0, 1.0);
    let out: i64 = nn_conv1d(input, kernel, 1, 1, 3, 2, 1, 0);
    if vec_len(out) != 2 { return 1; };
    if close(vec_get(out, 0), f64_to_bits(4.0), 0.000001) != 1 { return 2; };
    if close(vec_get(out, 1), f64_to_bits(7.0), 0.000001) != 1 { return 4; };

    let grad_out: i64 = make_vec2(1.0, 1.0);
    let back: i64 = nn_conv1d_backward(grad_out, input, kernel, 1, 1, 3, 2, 1, 0);
    let grad_input: i64 = vec_get(back, 0);
    let grad_kernel: i64 = vec_get(back, 1);
    if close(vec_get(grad_input, 0), f64_to_bits(2.0), 0.000001) != 1 { return 8; };
    if close(vec_get(grad_input, 1), f64_to_bits(3.0), 0.000001) != 1 { return 16; };
    if close(vec_get(grad_input, 2), f64_to_bits(1.0), 0.000001) != 1 { return 32; };
    if close(vec_get(grad_kernel, 0), f64_to_bits(3.0), 0.000001) != 1 { return 64; };
    if close(vec_get(grad_kernel, 1), f64_to_bits(5.0), 0.000001) != 1 { return 128; };
    return 0;
}

fn check_conv2d_forward_backward() -> i64 {
    let input: i64 = make_vec4(1.0, 2.0, 3.0, 4.0);
    let kernel: i64 = make_vec4(1.0, 0.0, 0.0, 1.0);
    let out: i64 = nn_conv2d(input, kernel, 1, 1, 2, 2, 2, 2, 1, 0);
    if vec_len(out) != 1 { return 256; };
    if close(vec_get(out, 0), f64_to_bits(5.0), 0.000001) != 1 { return 512; };

    let grad_out: i64 = make_vec2(1.0, 0.0);
    let back: i64 = nn_conv2d_backward(grad_out, input, kernel, 1, 1, 2, 2, 2, 2, 1, 0);
    let grad_input: i64 = vec_get(back, 0);
    let grad_kernel: i64 = vec_get(back, 1);
    if close(vec_get(grad_input, 0), f64_to_bits(1.0), 0.000001) != 1 { return 1024; };
    if close(vec_get(grad_input, 1), f64_to_bits(0.0), 0.000001) != 1 { return 2048; };
    if close(vec_get(grad_input, 3), f64_to_bits(1.0), 0.000001) != 1 { return 4096; };
    if close(vec_get(grad_kernel, 0), f64_to_bits(1.0), 0.000001) != 1 { return 8192; };
    if close(vec_get(grad_kernel, 3), f64_to_bits(4.0), 0.000001) != 1 { return 16384; };
    return 0;
}

fn check_depthwise_conv2d_forward_backward() -> i64 {
    let input: i64 = make_vec8();
    let kernel: i64 = make_vec2(2.0, 3.0);
    let out: i64 = nn_depthwise_conv2d(input, kernel, 2, 2, 2, 1, 1, 1, 0);
    if vec_len(out) != 8 { return 32768; };
    if close(vec_get(out, 0), f64_to_bits(2.0), 0.000001) != 1 { return 65536; };
    if close(vec_get(out, 3), f64_to_bits(8.0), 0.000001) != 1 { return 131072; };
    if close(vec_get(out, 4), f64_to_bits(15.0), 0.000001) != 1 { return 262144; };
    if close(vec_get(out, 7), f64_to_bits(24.0), 0.000001) != 1 { return 524288; };

    let grad_out: i64 = make_vec8();
    let back: i64 = nn_depthwise_conv2d_backward(grad_out, input, kernel, 2, 2, 2, 1, 1, 1, 0);
    let grad_input: i64 = vec_get(back, 0);
    let grad_kernel: i64 = vec_get(back, 1);
    if close(vec_get(grad_input, 0), f64_to_bits(2.0), 0.000001) != 1 { return 1048576; };
    if close(vec_get(grad_input, 4), f64_to_bits(15.0), 0.000001) != 1 { return 2097152; };
    if close(vec_get(grad_kernel, 0), f64_to_bits(30.0), 0.000001) != 1 { return 4194304; };
    if close(vec_get(grad_kernel, 1), f64_to_bits(174.0), 0.000001) != 1 { return 8388608; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_conv1d_forward_backward();
    fails = fails + check_conv2d_forward_backward();
    fails = fails + check_depthwise_conv2d_forward_backward();
    return fails;
}
