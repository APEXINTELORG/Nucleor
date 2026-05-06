// =====================================================
// rods/nn — Neural Network Training
// =====================================================
// Dense layers, backprop, Adam, activations, attention, ensemble.
// Wraps nn_rt.c via extern fn.
// Import: import "stdlib/rods/nn.nr"
// =====================================================

import "stdlib/rods/complex.nr"

#cfile "../runtime/nn_rt.c"

// Dense layer
extern fn nuc_nn_dense_new(in_dim: i64, out_dim: i64) -> i64;
extern fn nuc_nn_dense_forward(layer: i64, input: i64) -> i64;
extern fn nuc_nn_dense_backward(layer: i64, grad_out: i64) -> i64;
extern fn nuc_nn_dense_zero_grad(layer: i64);
extern fn nuc_nn_dense_set_cache(layer: i64, input: i64);
extern fn nuc_nn_dense_param_count(layer: i64) -> i64;

// Activations
extern fn nuc_nn_relu(vec: i64) -> i64;
extern fn nuc_nn_relu_backward(input: i64, grad: i64) -> i64;
extern fn nuc_nn_sigmoid(vec: i64) -> i64;
extern fn nuc_nn_sigmoid_backward(output: i64, grad: i64) -> i64;
extern fn nuc_nn_softmax(vec: i64) -> i64;
extern fn nuc_nn_softmax_backward(softmax: i64, grad: i64) -> i64;

// Training-capable normalization layers (ML-9)
extern fn nuc_nn_layer_norm(input: i64, gamma: i64, beta: i64, eps_bits: i64) -> i64;
extern fn nuc_nn_layer_norm_backward(input: i64, gamma: i64, grad: i64, eps_bits: i64) -> i64;
extern fn nuc_nn_batch_norm(input: i64, n_samples: i64, feat_dim: i64, gamma: i64, beta: i64, eps_bits: i64) -> i64;
extern fn nuc_nn_batch_norm_backward(input: i64, n_samples: i64, feat_dim: i64, gamma: i64, grad: i64, eps_bits: i64) -> i64;

// Adam optimizer
extern fn nuc_nn_adam_new(n_params: i64, lr: i64, beta1: i64, beta2: i64) -> i64;
extern fn nuc_nn_adam_step_dense(opt: i64, layer: i64);
extern fn nuc_nn_adam_step_logits(opt: i64, logits: i64, grads: i64, offset: i64);
extern fn nuc_nn_adam_tick(opt: i64);
extern fn nuc_nn_adam_step_at_no_tick(opt: i64, layer: i64, offset: i64) -> i64;
extern fn nuc_nn_adam_step_logits_no_tick(opt: i64, logits: i64, grads: i64, offset: i64);

// Noise model helpers
extern fn nuc_nn_noise_rate(logit: i64, max_p: i64) -> i64;
extern fn nuc_nn_noise_rate_grad(logit: i64, max_p: i64) -> i64;

// Z-score standardization
extern fn nuc_nn_compute_stats(dataset: i64, n_samples: i64, feat_dim: i64) -> i64;
extern fn nuc_nn_zscore(vec: i64, mean: i64, std: i64) -> i64;

// Pearson correlation
extern fn nuc_nn_pearson(x: i64, y: i64) -> i64;

// L-BFGS optimizer (toggleable alternative to Adam)
extern fn nuc_nn_lbfgs_new(n_params: i64, lr: i64) -> i64;
extern fn nuc_nn_lbfgs_step_dense(opt: i64, layer: i64);

// RNG reset (for reproducibility)
extern fn nuc_nn_reset_rng();

// Vector utilities
extern fn nuc_nn_vec_from_scalar(val: i64) -> i64;
extern fn nuc_nn_vec_concat(a: i64, b: i64) -> i64;
extern fn nuc_nn_vec_slice(vec: i64, start: i64, len: i64) -> i64;
extern fn nuc_nn_weighted_sum(input: i64, weights: i64, dim: i64) -> i64;

fn nn_layer_norm(input: i64, gamma: i64, beta: i64, eps_bits: i64) -> i64 {
    return nuc_nn_layer_norm(input, gamma, beta, eps_bits);
}

fn nn_layer_norm_backward(input: i64, gamma: i64, grad: i64, eps_bits: i64) -> i64 {
    return nuc_nn_layer_norm_backward(input, gamma, grad, eps_bits);
}

fn nn_batch_norm(input: i64, n_samples: i64, feat_dim: i64, gamma: i64, beta: i64, eps_bits: i64) -> i64 {
    return nuc_nn_batch_norm(input, n_samples, feat_dim, gamma, beta, eps_bits);
}

fn nn_batch_norm_backward(input: i64, n_samples: i64, feat_dim: i64, gamma: i64, grad: i64, eps_bits: i64) -> i64 {
    return nuc_nn_batch_norm_backward(input, n_samples, feat_dim, gamma, grad, eps_bits);
}

// =====================================================
// FlexPredictor: 3-layer MLP matching Python TC V2
// Input -> Dense(in, 32) -> ReLU -> Dense(32, 16) -> ReLU -> Dense(16, 1) -> Sigmoid
// =====================================================

fn predictor_new(n_input: i64) -> i64 {
    let model: i64 = vec_new();
    vec_push(model, nuc_nn_dense_new(n_input, 32)); // layer 0
    vec_push(model, nuc_nn_dense_new(32, 16));       // layer 1
    vec_push(model, nuc_nn_dense_new(16, 1));        // layer 2
    return model;
}

fn predictor_forward(model: i64, input: i64) -> i64 {
    let result: i64 = vec_new();
    let l0: i64 = vec_get(model, 0);
    let l1: i64 = vec_get(model, 1);
    let l2: i64 = vec_get(model, 2);

    let h1_pre: i64 = nuc_nn_dense_forward(l0, input);
    let h1: i64 = nuc_nn_relu(h1_pre);
    let h2_pre: i64 = nuc_nn_dense_forward(l1, h1);
    let h2: i64 = nuc_nn_relu(h2_pre);
    let h3_pre: i64 = nuc_nn_dense_forward(l2, h2);
    let h3: i64 = nuc_nn_sigmoid(h3_pre);

    vec_push(result, h3);       // [0] prediction
    vec_push(result, h1_pre);   // [1] pre-relu layer 1
    vec_push(result, h1);       // [2] post-relu layer 1
    vec_push(result, h2_pre);   // [3] pre-relu layer 2
    vec_push(result, h2);       // [4] post-relu layer 2
    vec_push(result, h3_pre);   // [5] pre-sigmoid
    vec_push(result, h3);       // [6] post-sigmoid
    return result;
}

fn predictor_backward(model: i64, cache: i64, grad_loss: i64) -> i64 {
    let l0: i64 = vec_get(model, 0);
    let l1: i64 = vec_get(model, 1);
    let l2: i64 = vec_get(model, 2);

    let h3_out: i64 = vec_get(cache, 6);
    let h2_pre: i64 = vec_get(cache, 3);
    let h1_pre: i64 = vec_get(cache, 1);

    let g_sig: i64 = nuc_nn_sigmoid_backward(h3_out, grad_loss);
    let g_l2: i64 = nuc_nn_dense_backward(l2, g_sig);
    let g_relu2: i64 = nuc_nn_relu_backward(h2_pre, g_l2);
    let g_l1: i64 = nuc_nn_dense_backward(l1, g_relu2);
    let g_relu1: i64 = nuc_nn_relu_backward(h1_pre, g_l1);
    let g_input: i64 = nuc_nn_dense_backward(l0, g_relu1);
    return g_input;
}

fn predictor_zero_grad(model: i64) {
    nuc_nn_dense_zero_grad(vec_get(model, 0));
    nuc_nn_dense_zero_grad(vec_get(model, 1));
    nuc_nn_dense_zero_grad(vec_get(model, 2));
}

fn predictor_adam_step(model: i64, opt: i64) {
    nuc_nn_adam_step_dense(opt, vec_get(model, 0));
    nuc_nn_adam_step_dense(opt, vec_get(model, 1));
    nuc_nn_adam_step_dense(opt, vec_get(model, 2));
}

fn predictor_param_count(model: i64) -> i64 {
    return nuc_nn_dense_param_count(vec_get(model, 0))
         + nuc_nn_dense_param_count(vec_get(model, 1))
         + nuc_nn_dense_param_count(vec_get(model, 2));
}

// =====================================================
// FlexEnsemblePredictor: Attention-weighted multi-core predictor
// Matches Python FlexEnsemblePredictor from process_features_execute.py
//
// core_net: 12 -> 32 -> ReLU -> 32 -> ReLU  (applied per core)
// attention: 32 -> 1, softmax across cores
// ext_net: ext_dim -> 16 -> ReLU
// head: (32+16) -> 32 -> ReLU -> 1 -> Sigmoid
//
// Model layout (Vec):
//   [0] core_net_l0  (Dense 12->32)
//   [1] core_net_l1  (Dense 32->32)
//   [2] attn_layer   (Dense 32->1)
//   [3] ext_net_l0   (Dense ext->16)
//   [4] head_l0      (Dense 48->32)
//   [5] head_l1      (Dense 32->1)
//   [6] n_cores      (int, number of noisy cores)
//   [7] core_feat_dim (int, 12)
// =====================================================

fn ensemble_new(core_feat_dim: i64, ext_feat_dim: i64, n_cores: i64) -> i64 {
    let model: i64 = vec_new();
    vec_push(model, nuc_nn_dense_new(core_feat_dim, 32));   // [0] core_net layer 0
    vec_push(model, nuc_nn_dense_new(32, 32));               // [1] core_net layer 1
    vec_push(model, nuc_nn_dense_new(32, 1));                // [2] attention
    vec_push(model, nuc_nn_dense_new(ext_feat_dim, 16));     // [3] ext_net → 16
    vec_push(model, nuc_nn_dense_new(48, 32));               // [4] head layer 0 (32+16=48)
    vec_push(model, nuc_nn_dense_new(32, 1));                // [5] head layer 1
    // Note: ext_net always outputs 16, head always takes 32+16=48
    vec_push(model, n_cores);                                 // [6] n_cores
    vec_push(model, core_feat_dim);                           // [7] core_feat_dim
    return model;
}

fn ensemble_forward(model: i64, per_core_feats: i64, ext_feats: i64) -> i64 {
    // per_core_feats: flat Vec of n_cores * 12 values (from nuc_diff_extract)
    // ext_feats: Vec of ext_dim values (structural features)
    let n_cores: i64 = vec_get(model, 6);
    let cfd: i64 = vec_get(model, 7);
    let cn0: i64 = vec_get(model, 0);
    let cn1: i64 = vec_get(model, 1);
    let attn_l: i64 = vec_get(model, 2);
    let ext_l: i64 = vec_get(model, 3);
    let hd0: i64 = vec_get(model, 4);
    let hd1: i64 = vec_get(model, 5);

    let cache: i64 = vec_new();  // store everything for backward

    // Process each core through core_net, collect hidden + attention scores
    let all_h: i64 = vec_new();
    let attn_scores: i64 = vec_new();
    let all_h1_pre: i64 = vec_new();
    let all_h2_pre: i64 = vec_new();
    let all_core_f: i64 = vec_new();
    let all_h1: i64 = vec_new();
    let all_h2: i64 = vec_new();

    let mut ci: i64 = 0;
    while ci < n_cores {
        let core_f: i64 = nuc_nn_vec_slice(per_core_feats, ci * cfd, cfd);
        let h1_pre: i64 = nuc_nn_dense_forward(cn0, core_f);
        let h1: i64 = nuc_nn_relu(h1_pre);
        let h2_pre: i64 = nuc_nn_dense_forward(cn1, h1);
        let h2: i64 = nuc_nn_relu(h2_pre);
        let score: i64 = nuc_nn_dense_forward(attn_l, h2);

        let mut fi: i64 = 0;
        while fi < 32 {
            vec_push(all_h, vec_get(h2, fi));
            fi = fi + 1;
        };
        vec_push(attn_scores, vec_get(score, 0));
        vec_push(all_h1_pre, h1_pre);
        vec_push(all_h2_pre, h2_pre);
        vec_push(all_core_f, core_f);
        vec_push(all_h1, h1);
        vec_push(all_h2, h2);
        ci = ci + 1;
    };

    // Softmax attention weights
    let attn_weights: i64 = nuc_nn_softmax(attn_scores);

    // Weighted sum: agg = sum(attn_weights[i] * h[i]), dim=32
    let agg: i64 = nuc_nn_weighted_sum(all_h, attn_weights, 32);

    // ext_net: ext -> 16 -> ReLU
    let ext_pre: i64 = nuc_nn_dense_forward(ext_l, ext_feats);
    let ext_h: i64 = nuc_nn_relu(ext_pre);

    // Concat agg (32) + ext_h (16) = 48
    let combined: i64 = nuc_nn_vec_concat(agg, ext_h);

    // head: 48 -> 32 -> ReLU -> 1 -> Sigmoid
    let hd0_pre: i64 = nuc_nn_dense_forward(hd0, combined);
    let hd0_h: i64 = nuc_nn_relu(hd0_pre);
    let hd1_pre: i64 = nuc_nn_dense_forward(hd1, hd0_h);
    let pred: i64 = nuc_nn_sigmoid(hd1_pre);

    // Cache: [pred, attn_weights, all_h, attn_scores, all_h1_pre, all_h2_pre,
    //         ext_pre, ext_h, combined, hd0_pre, hd0_h, hd1_pre, pred, per_core_feats, ext_feats]
    vec_push(cache, pred);             // [0]
    vec_push(cache, attn_weights);     // [1]
    vec_push(cache, all_h);            // [2]
    vec_push(cache, attn_scores);      // [3]
    vec_push(cache, all_h1_pre);       // [4]
    vec_push(cache, all_h2_pre);       // [5]
    vec_push(cache, ext_pre);          // [6]
    vec_push(cache, ext_h);            // [7]
    vec_push(cache, combined);         // [8]
    vec_push(cache, hd0_pre);          // [9]
    vec_push(cache, hd0_h);            // [10]
    vec_push(cache, hd1_pre);          // [11]
    vec_push(cache, per_core_feats);   // [12]
    vec_push(cache, ext_feats);        // [13]
    vec_push(cache, all_core_f);       // [14] per-core input vecs
    vec_push(cache, all_h1);           // [15] per-core post-relu L0
    vec_push(cache, all_h2);           // [16] per-core post-relu L1
    return cache;
}

fn ensemble_backward(model: i64, cache: i64, grad_loss: i64) -> i64 {
    let n_cores: i64 = vec_get(model, 6);
    let cfd: i64 = vec_get(model, 7);
    let cn0: i64 = vec_get(model, 0);
    let cn1: i64 = vec_get(model, 1);
    let attn_l: i64 = vec_get(model, 2);
    let ext_l: i64 = vec_get(model, 3);
    let hd0: i64 = vec_get(model, 4);
    let hd1: i64 = vec_get(model, 5);

    let pred: i64 = vec_get(cache, 0);
    let attn_weights: i64 = vec_get(cache, 1);
    let all_h: i64 = vec_get(cache, 2);
    let attn_scores: i64 = vec_get(cache, 3);
    let all_h1_pre: i64 = vec_get(cache, 4);
    let all_h2_pre: i64 = vec_get(cache, 5);
    let ext_pre: i64 = vec_get(cache, 6);
    let hd1_pre: i64 = vec_get(cache, 11);
    let hd0_pre: i64 = vec_get(cache, 9);
    let per_core_feats: i64 = vec_get(cache, 12);

    // Backward through sigmoid
    let g_sig: i64 = nuc_nn_sigmoid_backward(pred, grad_loss);

    // Backward through head L1 (32 -> 1)
    let g_hd1: i64 = nuc_nn_dense_backward(hd1, g_sig);

    // Backward through ReLU after head L0
    let g_hd0_relu: i64 = nuc_nn_relu_backward(hd0_pre, g_hd1);

    // Backward through head L0 (48 -> 32)
    let g_combined: i64 = nuc_nn_dense_backward(hd0, g_hd0_relu);

    // Split gradient: first 32 -> agg grad, last 16 -> ext grad
    let g_agg: i64 = nuc_nn_vec_slice(g_combined, 0, 32);
    let g_ext_h: i64 = nuc_nn_vec_slice(g_combined, 32, 16);

    // Backward through ext_net ReLU
    let g_ext_pre: i64 = nuc_nn_relu_backward(ext_pre, g_ext_h);

    // Backward through ext_net dense
    nuc_nn_dense_backward(ext_l, g_ext_pre);

    // Backward through weighted sum: grad w.r.t. all_h and attn_weights
    // g_all_h[i*32+j] = attn_weights[i] * g_agg[j]
    // g_attn_weights[i] = sum_j(all_h[i*32+j] * g_agg[j])
    let g_attn_weights: i64 = vec_new();
    let mut ci: i64 = 0;
    while ci < n_cores {
        let mut dot: i64 = f64_from_int(0);
        let mut fi: i64 = 0;
        while fi < 32 {
            let h_val: i64 = vec_get(all_h, ci * 32 + fi);
            let g_val: i64 = vec_get(g_agg, fi);
            dot = f64_add(dot, f64_mul(h_val, g_val));
            fi = fi + 1;
        };
        vec_push(g_attn_weights, dot);
        ci = ci + 1;
    };

    // Backward through softmax: g_attn_scores
    let g_attn_scores: i64 = nuc_nn_softmax_backward(attn_weights, g_attn_weights);

    // Per-core cached inputs for shared layers
    let all_core_f: i64 = vec_get(cache, 14);
    let all_h1: i64 = vec_get(cache, 15);
    let all_h2: i64 = vec_get(cache, 16);

    // For each core: backward through attention dense, core_net
    // CRITICAL: restore each core's cached input before calling dense_backward
    // because shared layers (cn0, cn1, attn_l) overwrite cache_in on each forward call
    ci = 0;
    while ci < n_cores {
        let w_i: i64 = vec_get(attn_weights, ci);
        let h2_pre: i64 = vec_get(all_h2_pre, ci);
        let h1_pre: i64 = vec_get(all_h1_pre, ci);
        let core_f: i64 = vec_get(all_core_f, ci);
        let h1: i64 = vec_get(all_h1, ci);
        let h2: i64 = vec_get(all_h2, ci);

        // Gradient from weighted sum: g_h2[j] = w_i * g_agg[j]
        let g_h2: i64 = vec_new();
        let mut fi: i64 = 0;
        while fi < 32 {
            vec_push(g_h2, f64_mul(w_i, vec_get(g_agg, fi)));
            fi = fi + 1;
        };

        // Gradient from attention score — restore h2 as attn_l's input
        nuc_nn_dense_set_cache(attn_l, h2);
        let g_score_vec: i64 = nuc_nn_vec_from_scalar(vec_get(g_attn_scores, ci));
        let g_h2_attn: i64 = nuc_nn_dense_backward(attn_l, g_score_vec);

        // Combine g_h2 from weighted sum + g_h2 from attention
        let g_h2_total: i64 = vec_new();
        fi = 0;
        while fi < 32 {
            vec_push(g_h2_total, f64_add(vec_get(g_h2, fi), vec_get(g_h2_attn, fi)));
            fi = fi + 1;
        };

        // Backward through core_net L1 ReLU
        let g_cn1_relu: i64 = nuc_nn_relu_backward(h2_pre, g_h2_total);

        // Backward through core_net L1 dense — restore h1 as cn1's input
        nuc_nn_dense_set_cache(cn1, h1);
        let g_h1: i64 = nuc_nn_dense_backward(cn1, g_cn1_relu);

        // Backward through core_net L0 ReLU
        let g_cn0_relu: i64 = nuc_nn_relu_backward(h1_pre, g_h1);

        // Backward through core_net L0 dense — restore core_f as cn0's input
        nuc_nn_dense_set_cache(cn0, core_f);
        nuc_nn_dense_backward(cn0, g_cn0_relu);

        ci = ci + 1;
    };

    return f64_from_int(0); // gradients accumulated in layers
}

fn ensemble_zero_grad(model: i64) {
    nuc_nn_dense_zero_grad(vec_get(model, 0));
    nuc_nn_dense_zero_grad(vec_get(model, 1));
    nuc_nn_dense_zero_grad(vec_get(model, 2));
    nuc_nn_dense_zero_grad(vec_get(model, 3));
    nuc_nn_dense_zero_grad(vec_get(model, 4));
    nuc_nn_dense_zero_grad(vec_get(model, 5));
}

fn ensemble_adam_step(model: i64, opt: i64) {
    // Use tick-once pattern: increment t once, then step all layers without re-incrementing
    nuc_nn_adam_tick(opt);
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 0), 0);
    let o1: i64 = nuc_nn_dense_param_count(vec_get(model, 0));
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 1), o1);
    let o2: i64 = o1 + nuc_nn_dense_param_count(vec_get(model, 1));
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 2), o2);
    let o3: i64 = o2 + nuc_nn_dense_param_count(vec_get(model, 2));
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 3), o3);
    let o4: i64 = o3 + nuc_nn_dense_param_count(vec_get(model, 3));
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 4), o4);
    let o5: i64 = o4 + nuc_nn_dense_param_count(vec_get(model, 4));
    nuc_nn_adam_step_at_no_tick(opt, vec_get(model, 5), o5);
}

fn ensemble_param_count(model: i64) -> i64 {
    return nuc_nn_dense_param_count(vec_get(model, 0))
         + nuc_nn_dense_param_count(vec_get(model, 1))
         + nuc_nn_dense_param_count(vec_get(model, 2))
         + nuc_nn_dense_param_count(vec_get(model, 3))
         + nuc_nn_dense_param_count(vec_get(model, 4))
         + nuc_nn_dense_param_count(vec_get(model, 5));
}
