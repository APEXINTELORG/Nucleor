// ML-13 P2b / ML-5 P1 - SSM selective-scan sequence convergence.
//
// Trains the B[t] input weights of a scalar selective scan to match a
// cumulative sequence target. This exercises selective_scan forward,
// selective_scan_backward, gradient extraction, and explicit parameter
// updates together instead of only checking the ZOH helper.
//
// Expected: rc=0.

import "stdlib/rods/ssm.nr"

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad < eps { return 1; };
    return 0;
}

fn make_const_vec(n: i64, val: f64) -> i64 {
    let v: i64 = vec_new();
    let mut i: i64 = 0;
    while i < n {
        vec_push(v, f64_to_bits(val));
        i = i + 1;
    };
    return v;
}

fn make_targets() -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(0.5));
    vec_push(v, f64_to_bits(1.0));
    vec_push(v, f64_to_bits(1.5));
    vec_push(v, f64_to_bits(2.0));
    return v;
}

fn loss_and_grad_y(y: i64, targets: i64, grad_y: i64) -> f64 {
    let mut loss: f64 = 0.0;
    let mut i: i64 = 0;
    while i < 4 {
        let pred: f64 = f64_from_bits(vec_get(y, i));
        let target: f64 = f64_from_bits(vec_get(targets, i));
        let err: f64 = pred - target;
        loss = loss + err * err;
        vec_push(grad_y, f64_to_bits(2.0 * err));
        i = i + 1;
    };
    return loss;
}

fn train_one(x: i64, delta: i64, a: i64, b: i64, c: i64, targets: i64, lr: f64) -> f64 {
    let y: i64 = ssm_selective_scan(x, delta, a, b, c, 4, 1, 1);
    let grad_y: i64 = vec_new();
    let loss: f64 = loss_and_grad_y(y, targets, grad_y);
    let grads: i64 = ssm_selective_scan_backward(x, delta, a, b, c, grad_y, 4, 1, 1);
    let grad_b: i64 = vec_get(grads, 3);

    let mut i: i64 = 0;
    while i < 4 {
        let old_b: f64 = f64_from_bits(vec_get(b, i));
        let gb: f64 = f64_from_bits(vec_get(grad_b, i));
        vec_set(b, i, f64_to_bits(old_b - lr * gb));
        i = i + 1;
    };
    return loss;
}

fn loss_only(x: i64, delta: i64, a: i64, b: i64, c: i64, targets: i64) -> f64 {
    let y: i64 = ssm_selective_scan(x, delta, a, b, c, 4, 1, 1);
    let scratch: i64 = vec_new();
    return loss_and_grad_y(y, targets, scratch);
}

fn main() -> i64 {
    let x: i64 = make_const_vec(4, 1.0);
    let delta: i64 = make_const_vec(4, 1.0);
    let a: i64 = make_const_vec(1, 0.0);
    let b: i64 = make_const_vec(4, 0.05);
    let c: i64 = make_const_vec(4, 1.0);
    let targets: i64 = make_targets();

    let initial_loss: f64 = loss_only(x, delta, a, b, c, targets);
    let mut epoch: i64 = 0;
    while epoch < 160 {
        train_one(x, delta, a, b, c, targets, 0.04);
        epoch = epoch + 1;
    };
    let final_loss: f64 = loss_only(x, delta, a, b, c, targets);
    let y: i64 = ssm_selective_scan(x, delta, a, b, c, 4, 1, 1);

    if final_loss >= initial_loss * 0.01 { return 1; };
    if close_f64(f64_from_bits(vec_get(y, 0)), 0.5, 0.03) != 1 { return 2; };
    if close_f64(f64_from_bits(vec_get(y, 1)), 1.0, 0.03) != 1 { return 4; };
    if close_f64(f64_from_bits(vec_get(y, 2)), 1.5, 0.03) != 1 { return 8; };
    if close_f64(f64_from_bits(vec_get(y, 3)), 2.0, 0.03) != 1 { return 16; };
    return 0;
}
