// ML-9 — training-capable normalization layer coverage.
//
// Locks concrete forward/backward behavior for nn.nr batch norm and
// learnable layer norm. Values are f64 bit patterns carried in Vec<i64>,
// matching the rest of the NN rod.
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

fn make_vec3(a: f64, b: f64, c: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    v.push(f64_to_bits(c));
    return v;
}

fn make_vec4(a: f64, b: f64, c: f64, d: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    v.push(f64_to_bits(c));
    v.push(f64_to_bits(d));
    return v;
}

fn check_layer_norm_forward_backward() -> i64 {
    let x: i64 = make_vec3(1.0, 2.0, 3.0);
    let gamma: i64 = make_vec3(1.0, 1.0, 1.0);
    let beta: i64 = make_vec3(0.0, 0.0, 0.0);
    let grad: i64 = make_vec3(1.0, 1.0, 1.0);
    let eps_bits: i64 = f64_to_bits(0.000001);

    let y: i64 = nn_layer_norm(x, gamma, beta, eps_bits);
    if vec_len(y) != 3 { return 1; };
    if close(vec_get(y, 0), f64_to_bits(0.0 - 1.224744), 0.0001) != 1 { return 2; };
    if close(vec_get(y, 1), f64_to_bits(0.0), 0.0001) != 1 { return 4; };
    if close(vec_get(y, 2), f64_to_bits(1.224744), 0.0001) != 1 { return 8; };

    let back: i64 = nn_layer_norm_backward(x, gamma, grad, eps_bits);
    if vec_len(back) != 3 { return 16; };
    let dx: i64 = vec_get(back, 0);
    let dgamma: i64 = vec_get(back, 1);
    let dbeta: i64 = vec_get(back, 2);
    if vec_len(dx) != 3 { return 32; };
    if close(vec_get(dx, 0), f64_to_bits(0.0), 0.000001) != 1 { return 64; };
    if close(vec_get(dgamma, 0), f64_to_bits(0.0 - 1.224744), 0.0001) != 1 { return 128; };
    if close(vec_get(dgamma, 1), f64_to_bits(0.0), 0.0001) != 1 { return 256; };
    if close(vec_get(dgamma, 2), f64_to_bits(1.224744), 0.0001) != 1 { return 512; };
    if close(vec_get(dbeta, 0), f64_to_bits(1.0), 0.000001) != 1 { return 1024; };
    if close(vec_get(dbeta, 2), f64_to_bits(1.0), 0.000001) != 1 { return 2048; };
    return 0;
}

fn check_batch_norm_forward_backward() -> i64 {
    let x: i64 = make_vec4(1.0, 3.0, 3.0, 7.0);
    let gamma: i64 = make_vec3(1.0, 1.0, 0.0);
    let beta: i64 = make_vec3(0.0, 0.0, 0.0);
    let grad: i64 = make_vec4(1.0, 1.0, 1.0, 1.0);
    let eps_bits: i64 = f64_to_bits(0.000001);

    let y: i64 = nn_batch_norm(x, 2, 2, gamma, beta, eps_bits);
    if vec_len(y) != 4 { return 4096; };
    if close(vec_get(y, 0), f64_to_bits(0.0 - 1.0), 0.0001) != 1 { return 8192; };
    if close(vec_get(y, 1), f64_to_bits(0.0 - 1.0), 0.0001) != 1 { return 16384; };
    if close(vec_get(y, 2), f64_to_bits(1.0), 0.0001) != 1 { return 32768; };
    if close(vec_get(y, 3), f64_to_bits(1.0), 0.0001) != 1 { return 65536; };

    let back: i64 = nn_batch_norm_backward(x, 2, 2, gamma, grad, eps_bits);
    if vec_len(back) != 3 { return 131072; };
    let dx: i64 = vec_get(back, 0);
    let dgamma: i64 = vec_get(back, 1);
    let dbeta: i64 = vec_get(back, 2);
    if vec_len(dx) != 4 { return 262144; };
    if vec_len(dgamma) != 2 { return 524288; };
    if vec_len(dbeta) != 2 { return 1048576; };
    if close(vec_get(dx, 0), f64_to_bits(0.0), 0.000001) != 1 { return 2097152; };
    if close(vec_get(dx, 3), f64_to_bits(0.0), 0.000001) != 1 { return 4194304; };
    if close(vec_get(dgamma, 0), f64_to_bits(0.0), 0.0001) != 1 { return 8388608; };
    if close(vec_get(dgamma, 1), f64_to_bits(0.0), 0.0001) != 1 { return 16777216; };
    if close(vec_get(dbeta, 0), f64_to_bits(2.0), 0.000001) != 1 { return 33554432; };
    if close(vec_get(dbeta, 1), f64_to_bits(2.0), 0.000001) != 1 { return 67108864; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_layer_norm_forward_backward();
    fails = fails + check_batch_norm_forward_backward();
    return fails;
}
