// ML-13 P2a - real gnn.nr convergence smoke.
//
// Trains a one-channel GATv2 layer on a two-node self-loop graph:
// node feature 0.0 -> target 0.0, node feature 1.0 -> target 1.0.
// This exercises GNN forward, sigmoid loss, GNN backward, zero_grad, and
// Adam parameter updates together instead of only checking non-null handles.
//
// Expected: rc=0.

import "stdlib/rods/gnn.nr"
import "stdlib/rods/nn.nr"

fn make_features() -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(0.0));
    vec_push(v, f64_to_bits(1.0));
    return v;
}

fn make_self_loops() -> i64 {
    let v: i64 = vec_new();
    vec_push(v, 0);
    vec_push(v, 1);
    return v;
}

fn make_targets() -> i64 {
    let v: i64 = vec_new();
    vec_push(v, f64_to_bits(0.0));
    vec_push(v, f64_to_bits(1.0));
    return v;
}

fn train_one(layer: i64, graph: i64, targets: i64) -> f64 {
    let out: i64 = gnn_gatv2_forward(layer, graph);
    let pred: i64 = nuc_nn_sigmoid(out);
    let grad_pred: i64 = vec_new();

    let mut loss: f64 = 0.0;
    let mut i: i64 = 0;
    while i < 2 {
        let p: f64 = f64_from_bits(vec_get(pred, i));
        let t: f64 = f64_from_bits(vec_get(targets, i));
        let err: f64 = p - t;
        loss = loss + err * err;
        vec_push(grad_pred, f64_to_bits(2.0 * err));
        i = i + 1;
    };

    let grad_out: i64 = nuc_nn_sigmoid_backward(pred, grad_pred);
    gnn_gatv2_backward(layer, graph, grad_out);
    return loss;
}

fn predict(layer: i64, graph: i64) -> i64 {
    return nuc_nn_sigmoid(gnn_gatv2_forward(layer, graph));
}

fn main() -> i64 {
    let feats: i64 = make_features();
    let edge_src: i64 = make_self_loops();
    let edge_dst: i64 = make_self_loops();
    let targets: i64 = make_targets();

    let graph: i64 = gnn_graph_new(feats, 2, 1, edge_src, edge_dst, 2);
    let layer: i64 = gnn_gatv2_new(1, 1);
    let opt: i64 = nuc_nn_adam_new(gnn_gatv2_param_count(layer), f64_to_bits(0.05), f64_to_bits(0.9), f64_to_bits(0.999));

    let initial_pred: i64 = predict(layer, graph);
    let initial_gap: f64 = f64_from_bits(vec_get(initial_pred, 1)) - f64_from_bits(vec_get(initial_pred, 0));

    let mut epoch: i64 = 0;
    while epoch < 1200 {
        gnn_gatv2_zero_grad(layer);
        train_one(layer, graph, targets);
        nuc_nn_adam_tick(opt);
        gnn_gatv2_adam_step(layer, opt, 0);
        epoch = epoch + 1;
    };

    let final_pred: i64 = predict(layer, graph);
    let p0: f64 = f64_from_bits(vec_get(final_pred, 0));
    let p1: f64 = f64_from_bits(vec_get(final_pred, 1));
    let final_gap: f64 = p1 - p0;

    if final_gap <= initial_gap + 0.40 { return 1; };
    if p0 >= 0.25 { return 2; };
    if p1 <= 0.75 { return 4; };
    gnn_graph_free(graph);
    return 0;
}
