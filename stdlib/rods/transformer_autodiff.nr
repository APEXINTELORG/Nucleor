// =====================================================
// rods/transformer_autodiff - Transformer / autodiff bridge
// =====================================================
// Import: import "stdlib/rods/transformer_autodiff.nr"
// Provides: first-pass bridges that lower selected transformer forward
//   kernels into scalar autodiff tape nodes. This keeps transformer
//   bridge code out of the lean nn_autodiff import path.
// =====================================================

import "stdlib/rods/transformer.nr"
import "stdlib/rods/complex.nr"
import "stdlib/rods/autodiff.nr"
import "stdlib/rods/differentiable.nr"

fn tf_autodiff_register_attention_split() -> i64 {
    return differentiable_register("nuc_tf_attention_split");
}

fn tf_attention_split_ad(Q_ad: i64, K_ad: i64, V_ad: i64, seq_q: i64, seq_k: i64, d_k: i64, d_v: i64, causal: i64) -> i64 {
    tf_autodiff_register_attention_split();

    let out: i64 = vec_new();
    if seq_q <= 0 { return out; };
    if seq_k <= 0 { return out; };
    if d_k <= 0 { return out; };
    if d_v <= 0 { return out; };

    let scale_bits: i64 = f64_div(f64_from_int(1), f64_sqrt(f64_from_int(d_k)));
    let scale: i64 = ad_const(scale_bits);

    let mut i: i64 = 0;
    while i < seq_q {
        let weights: i64 = vec_new();
        let mut sum_exp: i64 = ad_const(f64_from_int(0));

        let mut j: i64 = 0;
        while j < seq_k {
            let mut e: i64 = ad_const(f64_from_int(0));
            if causal == 0 {
                let mut dot: i64 = ad_const(f64_from_int(0));
                let mut k: i64 = 0;
                while k < d_k {
                    let qv: i64 = vec_get(Q_ad, i * d_k + k);
                    let kv: i64 = vec_get(K_ad, j * d_k + k);
                    dot = ad_add(dot, ad_mul(qv, kv));
                    k = k + 1;
                };
                e = ad_exp(ad_mul(dot, scale));
            } else {
                if j <= i {
                    let mut dot: i64 = ad_const(f64_from_int(0));
                    let mut k: i64 = 0;
                    while k < d_k {
                        let qv: i64 = vec_get(Q_ad, i * d_k + k);
                        let kv: i64 = vec_get(K_ad, j * d_k + k);
                        dot = ad_add(dot, ad_mul(qv, kv));
                        k = k + 1;
                    };
                    e = ad_exp(ad_mul(dot, scale));
                };
            };
            vec_push(weights, e);
            sum_exp = ad_add(sum_exp, e);
            j = j + 1;
        };

        let mut dv: i64 = 0;
        while dv < d_v {
            let mut acc: i64 = ad_const(f64_from_int(0));
            j = 0;
            while j < seq_k {
                let w: i64 = ad_div(vec_get(weights, j), sum_exp);
                let vv: i64 = vec_get(V_ad, j * d_v + dv);
                acc = ad_add(acc, ad_mul(w, vv));
                j = j + 1;
            };
            vec_push(out, acc);
            dv = dv + 1;
        };

        i = i + 1;
    };

    return out;
}

fn tf_attention_ad(Q_ad: i64, K_ad: i64, V_ad: i64, seq_len: i64, d_k: i64) -> i64 {
    return tf_attention_split_ad(Q_ad, K_ad, V_ad, seq_len, seq_len, d_k, d_k, 0);
}

fn tf_autodiff_limitations() -> str {
    return "Transformer/autodiff bridge limitations: tf_attention_split_ad and tf_attention_ad lower classic transformer attention into scalar autodiff tape nodes and support Q/K/V input gradients. This is not one opaque registered attention op, does not cover Flash/GQA/MLA attention variants, and does not provide compiler-side @differentiable lowering.";
}
