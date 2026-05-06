// ML-13 P2c - transformer small-LM convergence smoke.
//
// Trains two next-token logit rows for the alternating sequence
// 0 -> 1 and 1 -> 0. This exercises transformer cross-entropy,
// cross-entropy gradient, softmax probability readout, and Adam logit
// updates together while staying small enough for the full gate.
//
// Expected: rc=0.

import "stdlib/rods/transformer.nr"
import "stdlib/rods/nn.nr"

fn make_logits() -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(0.0));
    vec_push(v, f64_to_bits(0.0));
    return v;
}

fn loss_pair(logits0: i64, logits1: i64) -> f64 {
    return f64_from_bits(tf_cross_entropy(logits0, 1)) + f64_from_bits(tf_cross_entropy(logits1, 0));
}

fn target_prob(logits: i64, target: i64) -> f64 {
    let probs: i64 = tf_softmax(logits);
    return f64_from_bits(vec_get(probs, target));
}

fn main() -> i64 {
    let logits0: i64 = make_logits();
    let logits1: i64 = make_logits();
    let opt: i64 = nuc_nn_adam_new(4, f64_to_bits(0.12), f64_to_bits(0.9), f64_to_bits(0.999));
    let initial_loss: f64 = loss_pair(logits0, logits1);

    let mut epoch: i64 = 0;
    while epoch < 120 {
        let grad0: i64 = tf_cross_entropy_grad(logits0, 1);
        let grad1: i64 = tf_cross_entropy_grad(logits1, 0);
        nuc_nn_adam_tick(opt);
        nuc_nn_adam_step_logits_no_tick(opt, logits0, grad0, 0);
        nuc_nn_adam_step_logits_no_tick(opt, logits1, grad1, 2);
        epoch = epoch + 1;
    };

    let final_loss: f64 = loss_pair(logits0, logits1);
    let p01: f64 = target_prob(logits0, 1);
    let p10: f64 = target_prob(logits1, 0);

    if final_loss >= initial_loss * 0.20 { return 1; };
    if p01 <= 0.90 { return 2; };
    if p10 <= 0.90 { return 4; };
    return 0;
}
