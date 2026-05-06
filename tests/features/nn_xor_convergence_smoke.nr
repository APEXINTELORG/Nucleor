// ML-13 P1 — real nn.nr convergence smoke.
//
// Trains a 2-layer MLP on XOR and checks that the learned predictions are on
// the correct side of 0.5. This exercises dense forward/backward, sigmoid
// backward, gradient accumulation, zero_grad, and Adam parameter updates
// together instead of only checking non-null handles.
//
// Expected: rc=0.

import "stdlib/rods/nn.nr"

fn make_x(a: f64, b: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    return v;
}

fn make_grad(g: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(g));
    return v;
}

fn forward(l0: i64, l1: i64, x: i64) -> i64 {
    let h_pre: i64 = nuc_nn_dense_forward(l0, x);
    let h: i64 = nuc_nn_sigmoid(h_pre);
    let y_pre: i64 = nuc_nn_dense_forward(l1, h);
    let y: i64 = nuc_nn_sigmoid(y_pre);
    let cache: i64 = vec_new();
    vec_push(cache, y);
    vec_push(cache, y_pre);
    vec_push(cache, h);
    vec_push(cache, h_pre);
    return cache;
}

fn train_one(l0: i64, l1: i64, x: i64, target: f64) -> f64 {
    let cache: i64 = forward(l0, l1, x);
    let y: i64 = vec_get(cache, 0);
    let y_pre: i64 = vec_get(cache, 1);
    let h: i64 = vec_get(cache, 2);
    let h_pre: i64 = vec_get(cache, 3);
    let pred: f64 = f64_from_bits(vec_get(y, 0));
    let err: f64 = pred - target;
    let grad_y: i64 = make_grad(2.0 * err);
    let grad_y_pre: i64 = nuc_nn_sigmoid_backward(y, grad_y);
    let grad_h: i64 = nuc_nn_dense_backward(l1, grad_y_pre);
    let grad_h_pre: i64 = nuc_nn_sigmoid_backward(h, grad_h);
    nuc_nn_dense_set_cache(l0, x);
    nuc_nn_dense_backward(l0, grad_h_pre);
    return err * err;
}

fn predict(l0: i64, l1: i64, x: i64) -> f64 {
    let cache: i64 = forward(l0, l1, x);
    let y: i64 = vec_get(cache, 0);
    return f64_from_bits(vec_get(y, 0));
}

fn main() -> i64 {
    nuc_nn_reset_rng();
    let l0: i64 = nuc_nn_dense_new(2, 8);
    let l1: i64 = nuc_nn_dense_new(8, 1);
    let total_params: i64 = nuc_nn_dense_param_count(l0) + nuc_nn_dense_param_count(l1);
    let opt: i64 = nuc_nn_adam_new(total_params, f64_to_bits(0.05), f64_to_bits(0.9), f64_to_bits(0.999));

    let x00: i64 = make_x(0.0, 0.0);
    let x01: i64 = make_x(0.0, 1.0);
    let x10: i64 = make_x(1.0, 0.0);
    let x11: i64 = make_x(1.0, 1.0);

    let mut epoch: i64 = 0;
    while epoch < 4000 {
        nuc_nn_dense_zero_grad(l0);
        nuc_nn_dense_zero_grad(l1);
        train_one(l0, l1, x00, 0.0);
        train_one(l0, l1, x01, 1.0);
        train_one(l0, l1, x10, 1.0);
        train_one(l0, l1, x11, 0.0);
        nuc_nn_adam_tick(opt);
        let off: i64 = nuc_nn_adam_step_at_no_tick(opt, l0, 0);
        nuc_nn_adam_step_at_no_tick(opt, l1, off);
        epoch = epoch + 1;
    };

    let p00: f64 = predict(l0, l1, x00);
    let p01: f64 = predict(l0, l1, x01);
    let p10: f64 = predict(l0, l1, x10);
    let p11: f64 = predict(l0, l1, x11);

    if p00 >= 0.35 { return 1; };
    if p01 <= 0.65 { return 2; };
    if p10 <= 0.65 { return 4; };
    if p11 >= 0.35 { return 8; };
    return 0;
}
