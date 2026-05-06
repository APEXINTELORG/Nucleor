// =====================================================
// rods/nn_autodiff - NN / autodiff bridge
// =====================================================
// Import: import "stdlib/rods/nn_autodiff.nr"
// Provides: first-pass bridges that lower selected NN forward
//   kernels into scalar autodiff tape nodes. This lets callers compute
//   input gradients through NN surfaces using autodiff.
// =====================================================

import "stdlib/rods/nn.nr"
import "stdlib/rods/autodiff.nr"
import "stdlib/rods/differentiable.nr"

fn nn_autodiff_register_dense() -> i64 {
    return differentiable_register("nuc_nn_dense_forward");
}

fn nn_autodiff_register_layer_norm() -> i64 {
    return differentiable_register("nuc_nn_layer_norm");
}

fn nn_autodiff_register_batch_norm() -> i64 {
    return differentiable_register("nuc_nn_batch_norm");
}

fn nn_autodiff_register_conv1d() -> i64 {
    return differentiable_register("nuc_nn_conv1d");
}

fn nn_autodiff_register_conv2d() -> i64 {
    return differentiable_register("nuc_nn_conv2d");
}

fn nn_autodiff_register_depthwise_conv2d() -> i64 {
    return differentiable_register("nuc_nn_depthwise_conv2d");
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

fn nn_layer_norm_ad(input_ad: i64, gamma_bits: i64, beta_bits: i64, eps_bits: i64) -> i64 {
    nn_autodiff_register_layer_norm();

    let n: i64 = vec_len(input_ad);
    let out: i64 = vec_new();
    if n <= 0 { return out; };

    let inv_n_bits: i64 = f64_div(f64_from_int(1), f64_from_int(n));
    let inv_n: i64 = ad_const(inv_n_bits);

    let mut sum: i64 = ad_const(f64_from_int(0));
    let mut i: i64 = 0;
    while i < n {
        sum = ad_add(sum, vec_get(input_ad, i));
        i = i + 1;
    };
    let mean: i64 = ad_mul(sum, inv_n);

    let mut var_sum: i64 = ad_const(f64_from_int(0));
    i = 0;
    while i < n {
        let centered: i64 = ad_sub(vec_get(input_ad, i), mean);
        var_sum = ad_add(var_sum, ad_mul(centered, centered));
        i = i + 1;
    };
    let var: i64 = ad_mul(var_sum, inv_n);
    let denom: i64 = ad_sqrt(ad_add(var, ad_const(eps_bits)));

    i = 0;
    while i < n {
        let centered: i64 = ad_sub(vec_get(input_ad, i), mean);
        let xhat: i64 = ad_div(centered, denom);
        let scaled: i64 = ad_mul(ad_const(vec_get(gamma_bits, i)), xhat);
        vec_push(out, ad_add(scaled, ad_const(vec_get(beta_bits, i))));
        i = i + 1;
    };

    return out;
}

fn nn_batch_norm_ad(input_ad: i64, n_samples: i64, feat_dim: i64, gamma_bits: i64, beta_bits: i64, eps_bits: i64) -> i64 {
    nn_autodiff_register_batch_norm();

    let out: i64 = vec_new();
    let total: i64 = n_samples * feat_dim;
    if n_samples <= 0 { return out; };
    if feat_dim <= 0 { return out; };
    if vec_len(input_ad) < total { return out; };

    let inv_ns_bits: i64 = f64_div(f64_from_int(1), f64_from_int(n_samples));
    let inv_ns: i64 = ad_const(inv_ns_bits);

    let means: i64 = vec_new();
    let denoms: i64 = vec_new();

    let mut f: i64 = 0;
    while f < feat_dim {
        let mut sum: i64 = ad_const(f64_from_int(0));
        let mut s: i64 = 0;
        while s < n_samples {
            let idx: i64 = s * feat_dim + f;
            sum = ad_add(sum, vec_get(input_ad, idx));
            s = s + 1;
        };
        let mean: i64 = ad_mul(sum, inv_ns);
        vec_push(means, mean);

        let mut var_sum: i64 = ad_const(f64_from_int(0));
        s = 0;
        while s < n_samples {
            let idx: i64 = s * feat_dim + f;
            let centered: i64 = ad_sub(vec_get(input_ad, idx), mean);
            var_sum = ad_add(var_sum, ad_mul(centered, centered));
            s = s + 1;
        };
        let var: i64 = ad_mul(var_sum, inv_ns);
        vec_push(denoms, ad_sqrt(ad_add(var, ad_const(eps_bits))));
        f = f + 1;
    };

    let mut idx_out: i64 = 0;
    while idx_out < total {
        let feat: i64 = idx_out % feat_dim;
        let centered: i64 = ad_sub(vec_get(input_ad, idx_out), vec_get(means, feat));
        let xhat: i64 = ad_div(centered, vec_get(denoms, feat));
        let scaled: i64 = ad_mul(ad_const(vec_get(gamma_bits, feat)), xhat);
        vec_push(out, ad_add(scaled, ad_const(vec_get(beta_bits, feat))));
        idx_out = idx_out + 1;
    };

    return out;
}

fn nn_conv1d_ad(input_ad: i64, kernel_bits: i64, c_in: i64, c_out: i64, length: i64, k_width: i64, stride: i64, pad: i64) -> i64 {
    nn_autodiff_register_conv1d();

    let out: i64 = vec_new();
    if c_in <= 0 { return out; };
    if c_out <= 0 { return out; };
    if length <= 0 { return out; };
    if k_width <= 0 { return out; };
    if stride <= 0 { return out; };

    let out_l: i64 = (length + (2 * pad) - k_width) / stride + 1;
    if out_l <= 0 { return out; };

    let mut oc: i64 = 0;
    while oc < c_out {
        let mut ox: i64 = 0;
        while ox < out_l {
            let mut acc: i64 = ad_const(f64_from_int(0));
            let mut ic: i64 = 0;
            while ic < c_in {
                let mut fx: i64 = 0;
                while fx < k_width {
                    let ix: i64 = ox * stride - pad + fx;
                    if ix >= 0 {
                        if ix < length {
                            let in_idx: i64 = ic * length + ix;
                            let k_idx: i64 = oc * c_in * k_width + ic * k_width + fx;
                            let x: i64 = vec_get(input_ad, in_idx);
                            let k: i64 = ad_const(vec_get(kernel_bits, k_idx));
                            acc = ad_add(acc, ad_mul(x, k));
                        };
                    };
                    fx = fx + 1;
                };
                ic = ic + 1;
            };
            vec_push(out, acc);
            ox = ox + 1;
        };
        oc = oc + 1;
    };

    return out;
}

fn nn_conv2d_ad(input_ad: i64, kernel_bits: i64, c_in: i64, c_out: i64, height: i64, width: i64, k_height: i64, k_width: i64, stride: i64, pad: i64) -> i64 {
    nn_autodiff_register_conv2d();

    let out: i64 = vec_new();
    if c_in <= 0 { return out; };
    if c_out <= 0 { return out; };
    if height <= 0 { return out; };
    if width <= 0 { return out; };
    if k_height <= 0 { return out; };
    if k_width <= 0 { return out; };
    if stride <= 0 { return out; };

    let out_h: i64 = (height + (2 * pad) - k_height) / stride + 1;
    let out_w: i64 = (width + (2 * pad) - k_width) / stride + 1;
    if out_h <= 0 { return out; };
    if out_w <= 0 { return out; };

    let mut oc: i64 = 0;
    while oc < c_out {
        let mut oh: i64 = 0;
        while oh < out_h {
            let mut ow: i64 = 0;
            while ow < out_w {
                let mut acc: i64 = ad_const(f64_from_int(0));
                let mut ic: i64 = 0;
                while ic < c_in {
                    let mut fh: i64 = 0;
                    while fh < k_height {
                        let mut fw: i64 = 0;
                        while fw < k_width {
                            let ih: i64 = oh * stride - pad + fh;
                            let iw: i64 = ow * stride - pad + fw;
                            if ih >= 0 {
                                if ih < height {
                                    if iw >= 0 {
                                        if iw < width {
                                            let in_idx: i64 = ic * height * width + ih * width + iw;
                                            let k_idx: i64 = oc * c_in * k_height * k_width + ic * k_height * k_width + fh * k_width + fw;
                                            let x: i64 = vec_get(input_ad, in_idx);
                                            let k: i64 = ad_const(vec_get(kernel_bits, k_idx));
                                            acc = ad_add(acc, ad_mul(x, k));
                                        };
                                    };
                                };
                            };
                            fw = fw + 1;
                        };
                        fh = fh + 1;
                    };
                    ic = ic + 1;
                };
                vec_push(out, acc);
                ow = ow + 1;
            };
            oh = oh + 1;
        };
        oc = oc + 1;
    };

    return out;
}

fn nn_depthwise_conv2d_ad(input_ad: i64, kernel_bits: i64, channels: i64, height: i64, width: i64, k_height: i64, k_width: i64, stride: i64, pad: i64) -> i64 {
    nn_autodiff_register_depthwise_conv2d();

    let out: i64 = vec_new();
    if channels <= 0 { return out; };
    if height <= 0 { return out; };
    if width <= 0 { return out; };
    if k_height <= 0 { return out; };
    if k_width <= 0 { return out; };
    if stride <= 0 { return out; };

    let out_h: i64 = (height + (2 * pad) - k_height) / stride + 1;
    let out_w: i64 = (width + (2 * pad) - k_width) / stride + 1;
    if out_h <= 0 { return out; };
    if out_w <= 0 { return out; };

    let mut c: i64 = 0;
    while c < channels {
        let mut oh: i64 = 0;
        while oh < out_h {
            let mut ow: i64 = 0;
            while ow < out_w {
                let mut acc: i64 = ad_const(f64_from_int(0));
                let mut fh: i64 = 0;
                while fh < k_height {
                    let mut fw: i64 = 0;
                    while fw < k_width {
                        let ih: i64 = oh * stride - pad + fh;
                        let iw: i64 = ow * stride - pad + fw;
                        if ih >= 0 {
                            if ih < height {
                                if iw >= 0 {
                                    if iw < width {
                                        let in_idx: i64 = c * height * width + ih * width + iw;
                                        let k_idx: i64 = c * k_height * k_width + fh * k_width + fw;
                                        let x: i64 = vec_get(input_ad, in_idx);
                                        let k: i64 = ad_const(vec_get(kernel_bits, k_idx));
                                        acc = ad_add(acc, ad_mul(x, k));
                                    };
                                };
                            };
                        };
                        fw = fw + 1;
                    };
                    fh = fh + 1;
                };
                vec_push(out, acc);
                ow = ow + 1;
            };
            oh = oh + 1;
        };
        c = c + 1;
    };

    return out;
}

fn nn_autodiff_limitations() -> str {
    return "NN/autodiff bridge limitations (ML-14, helper1 v0867/v0871/v0872/v0873/v0874/v0875): nn_dense_forward_ad, nn_layer_norm_ad, nn_batch_norm_ad, nn_conv1d_ad, nn_conv2d_ad, and nn_depthwise_conv2d_ad lower Dense, LayerNorm, BatchNorm/batch-norm, Conv1D, Conv2D, and depthwise Conv2D forward paths into scalar autodiff tape nodes and support input gradients. Parameter gradients still use nn.nr backward/optimizer surfaces; this bridge does not yet register one opaque layer op, does not cover broader convolution surfaces beyond these bridges or attention, and does not provide compiler-side @differentiable lowering.";
}
