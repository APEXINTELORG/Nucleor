// =====================================================
// rods/nn_autodiff - NN / autodiff bridge
// =====================================================
// Import: import "stdlib/rods/nn_autodiff.nr"
// Provides: first-pass bridge that lowers dense-layer forward
//   into scalar autodiff tape nodes. This lets callers compute
//   input gradients through an NN dense layer using autodiff.
// =====================================================

import "stdlib/rods/nn.nr"
import "stdlib/rods/autodiff.nr"
import "stdlib/rods/differentiable.nr"

fn nn_autodiff_register_dense() -> i64 {
    return differentiable_register("nuc_nn_dense_forward");
}

fn nn_dense_forward_ad(layer: i64, input_ad: i64) -> i64 {
    nn_autodiff_register_dense();

    let in_dim: i64 = nn_dense_in_dim(layer);
    let out_dim: i64 = nn_dense_out_dim(layer);
    let out: i64 = vec_new();

    let mut oi: i64 = 0;
    while oi < out_dim {
        let mut acc: i64 = ad_const(nn_dense_bias(layer, oi));
        let mut ii: i64 = 0;
        while ii < in_dim {
            let w: i64 = ad_const(nn_dense_weight(layer, oi, ii));
            let x: i64 = vec_get(input_ad, ii);
            acc = ad_add(acc, ad_mul(w, x));
            ii = ii + 1;
        };
        vec_push(out, acc);
        oi = oi + 1;
    };

    return out;
}

fn nn_autodiff_limitations() -> str {
    return "NN/autodiff bridge limitations (ML-14, helper1 v0867): nn_dense_forward_ad lowers Dense forward into scalar autodiff tape nodes and supports input gradients. Parameter gradients still use nn.nr backward/optimizer surfaces; this bridge does not yet register one opaque layer op, does not cover convolution/norm/attention, and does not provide compiler-side @differentiable lowering.";
}
