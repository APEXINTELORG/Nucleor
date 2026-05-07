// rods/ml/nn_facade — PyTorch nn parity rods (Linear, ReLU, GELU, LayerNorm, RMSNorm, losses, SGD/AdamW)
//
import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/math_facade.nr"

// nn_facade.nr - first PyTorch-style neural-network facade.
//
// Forward-only primitives land first so parity can be established before
// autograd, optimizers, and device dispatch are added.

#[repr(C)]
struct SgdMomentumStepF64 {
    param: TensorF64,
    velocity: TensorF64
}

#[repr(C)]
struct AdamWStepF64 {
    param: TensorF64,
    exp_avg: TensorF64,
    exp_avg_sq: TensorF64
}

#[repr(C)]
struct LinearBackwardF64 {
    grad_input: TensorF64,
    grad_weight: TensorF64,
    grad_bias: TensorF64
}

#[repr(C)]
struct LayerNormBackwardF64 {
    grad_input: TensorF64,
    grad_weight: TensorF64,
    grad_bias: TensorF64
}

#[repr(C)]
struct TwoLayerReluCrossEntropySgdStepF64 {
    loss: f64,
    w1: TensorF64,
    b1: TensorF64,
    w2: TensorF64,
    b2: TensorF64
}

#[repr(C)]
struct TwoLayerReluCrossEntropyAdamWStepF64 {
    loss: f64,
    w1: TensorF64,
    b1: TensorF64,
    w2: TensorF64,
    b2: TensorF64,
    w1_exp_avg: TensorF64,
    w1_exp_avg_sq: TensorF64,
    b1_exp_avg: TensorF64,
    b1_exp_avg_sq: TensorF64,
    w2_exp_avg: TensorF64,
    w2_exp_avg_sq: TensorF64,
    b2_exp_avg: TensorF64,
    b2_exp_avg_sq: TensorF64
}

fn nn_f64_powi(base: f64, exp: i64) -> f64 {
    let mut out: f64 = 1.0;
    let mut i: i64 = 0;
    while i < exp {
        out = out * base;
        i = i + 1;
    };
    return out;
}

fn nn_linear_f64(input: &TensorF64, weight: &TensorF64, bias: &TensorF64) -> TensorF64 {
    if input.shape.cols != weight.shape.cols {
        print("nn error: input features must equal weight features");
        return tensor_f64_zeros(0, 0);
    };
    if bias.shape.rows != 1 {
        print("nn error: bias must be one row");
        return tensor_f64_zeros(0, 0);
    };
    if bias.shape.cols != weight.shape.rows {
        print("nn error: bias cols must equal output features");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut o: i64 = 0;
        while o < weight.shape.rows {
            let mut acc: f64 = tensor_f64_at(bias, 0, o);
            let mut f: i64 = 0;
            while f < input.shape.cols {
                acc = acc + tensor_f64_at(input, r, f) * tensor_f64_at(weight, o, f);
                f = f + 1;
            };
            data.push(acc);
            o = o + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, weight.shape.rows, data);
}

fn nn_linear_backward_f64(input: &TensorF64, weight: &TensorF64, grad_output: &TensorF64) -> LinearBackwardF64 {
    if input.shape.cols != weight.shape.cols {
        print("nn error: input features must equal weight features");
        return LinearBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };
    if input.shape.rows != grad_output.shape.rows {
        print("nn error: grad_output rows must equal input rows");
        return LinearBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };
    if weight.shape.rows != grad_output.shape.cols {
        print("nn error: grad_output cols must equal output features");
        return LinearBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };

    let mut gid: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut f: i64 = 0;
        while f < input.shape.cols {
            let mut acc: f64 = 0.0;
            let mut o: i64 = 0;
            while o < weight.shape.rows {
                acc = acc + tensor_f64_at(grad_output, r, o) * tensor_f64_at(weight, o, f);
                o = o + 1;
            };
            gid.push(acc);
            f = f + 1;
        };
        r = r + 1;
    };

    let mut gwd: Vec<f64> = Vec::new();
    let mut o2: i64 = 0;
    while o2 < weight.shape.rows {
        let mut f2: i64 = 0;
        while f2 < weight.shape.cols {
            let mut acc2: f64 = 0.0;
            let mut r2: i64 = 0;
            while r2 < input.shape.rows {
                acc2 = acc2 + tensor_f64_at(grad_output, r2, o2) * tensor_f64_at(input, r2, f2);
                r2 = r2 + 1;
            };
            gwd.push(acc2);
            f2 = f2 + 1;
        };
        o2 = o2 + 1;
    };

    let mut gbd: Vec<f64> = Vec::new();
    let mut o3: i64 = 0;
    while o3 < weight.shape.rows {
        let mut acc3: f64 = 0.0;
        let mut r3: i64 = 0;
        while r3 < input.shape.rows {
            acc3 = acc3 + tensor_f64_at(grad_output, r3, o3);
            r3 = r3 + 1;
        };
        gbd.push(acc3);
        o3 = o3 + 1;
    };

    return LinearBackwardF64 {
        grad_input: tensor_f64_from_vec(input.shape.rows, input.shape.cols, gid),
        grad_weight: tensor_f64_from_vec(weight.shape.rows, weight.shape.cols, gwd),
        grad_bias: tensor_f64_from_vec(1, weight.shape.rows, gbd)
    };
}

fn nn_relu_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        if input.data[i] < 0.0 {
            data.push(0.0);
        } else {
            data.push(input.data[i]);
        };
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_relu_backward_f64(input: &TensorF64, grad_output: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&input.shape, &grad_output.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        if input.data[i] > 0.0 {
            data.push(grad_output.data[i]);
        } else {
            data.push(0.0);
        };
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_gelu_tanh_scalar_f64(x: f64) -> f64 {
    let k: f64 = 0.797885;
    let c: f64 = 0.044715;
    let x2: f64 = x * x;
    let inner: f64 = k * (x + c * x * x2);
    return 0.5 * x * (1.0 + math_tanh_f64(inner));
}

fn nn_gelu_tanh_grad_scalar_f64(x: f64) -> f64 {
    let k: f64 = 0.797885;
    let c: f64 = 0.044715;
    let x2: f64 = x * x;
    let inner: f64 = k * (x + c * x * x2);
    let th: f64 = math_tanh_f64(inner);
    let sech2: f64 = 1.0 - th * th;
    let inner_grad: f64 = k * (1.0 + 3.0 * c * x2);
    return 0.5 * (1.0 + th) + 0.5 * x * sech2 * inner_grad;
}

fn nn_gelu_tanh_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(nn_gelu_tanh_scalar_f64(input.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_gelu_tanh_backward_f64(input: &TensorF64, grad_output: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&input.shape, &grad_output.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(grad_output.data[i] * nn_gelu_tanh_grad_scalar_f64(input.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_layer_norm_f64(input: &TensorF64, weight: &TensorF64, bias: &TensorF64, eps: f64) -> TensorF64 {
    if weight.shape.rows != 1 {
        print("nn error: layer norm weight must be one row");
        return tensor_f64_zeros(0, 0);
    };
    if bias.shape.rows != 1 {
        print("nn error: layer norm bias must be one row");
        return tensor_f64_zeros(0, 0);
    };
    if weight.shape.cols != input.shape.cols {
        print("nn error: layer norm weight cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };
    if bias.shape.cols != input.shape.cols {
        print("nn error: layer norm bias cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let cols_f: f64 = input.shape.cols as f64;
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut mean: f64 = 0.0;
        let mut c: i64 = 0;
        while c < input.shape.cols {
            mean = mean + tensor_f64_at(input, r, c);
            c = c + 1;
        };
        mean = mean / cols_f;

        let mut var: f64 = 0.0;
        c = 0;
        while c < input.shape.cols {
            let centered: f64 = tensor_f64_at(input, r, c) - mean;
            var = var + centered * centered;
            c = c + 1;
        };
        var = var / cols_f;
        let inv_std: f64 = 1.0 / math_sqrt_f64(var + eps);

        c = 0;
        while c < input.shape.cols {
            let normalized: f64 = (tensor_f64_at(input, r, c) - mean) * inv_std;
            data.push(normalized * tensor_f64_at(weight, 0, c) + tensor_f64_at(bias, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_rms_norm_f64(input: &TensorF64, weight: &TensorF64, eps: f64) -> TensorF64 {
    if weight.shape.rows != 1 {
        print("nn error: RMSNorm weight must be one row");
        return tensor_f64_zeros(0, 0);
    };
    if weight.shape.cols != input.shape.cols {
        print("nn error: RMSNorm weight cols must equal input cols");
        return tensor_f64_zeros(0, 0);
    };

    let cols_f: f64 = input.shape.cols as f64;
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut mean_square: f64 = 0.0;
        let mut c: i64 = 0;
        while c < input.shape.cols {
            let v: f64 = tensor_f64_at(input, r, c);
            mean_square = mean_square + v * v;
            c = c + 1;
        };
        mean_square = mean_square / cols_f;
        let inv_rms: f64 = 1.0 / math_sqrt_f64(mean_square + eps);

        c = 0;
        while c < input.shape.cols {
            data.push(tensor_f64_at(input, r, c) * inv_rms * tensor_f64_at(weight, 0, c));
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_layer_norm_backward_f64(input: &TensorF64, weight: &TensorF64, grad_output: &TensorF64, eps: f64) -> LayerNormBackwardF64 {
    if shape2_assert_same(&input.shape, &grad_output.shape) != 0 {
        return LayerNormBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };
    if weight.shape.rows != 1 {
        print("nn error: layer norm weight must be one row");
        return LayerNormBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };
    if weight.shape.cols != input.shape.cols {
        print("nn error: layer norm weight cols must equal input cols");
        return LayerNormBackwardF64 { grad_input: tensor_f64_zeros(0, 0), grad_weight: tensor_f64_zeros(0, 0), grad_bias: tensor_f64_zeros(0, 0) };
    };

    let cols_f: f64 = input.shape.cols as f64;
    let mut gid: Vec<f64> = Vec::new();
    let mut gwd: Vec<f64> = Vec::new();
    let mut gbd: Vec<f64> = Vec::new();

    let mut c_init: i64 = 0;
    while c_init < input.shape.cols {
        gwd.push(0.0);
        gbd.push(0.0);
        c_init = c_init + 1;
    };

    let mut r: i64 = 0;
    while r < input.shape.rows {
        let mut mean: f64 = 0.0;
        let mut c: i64 = 0;
        while c < input.shape.cols {
            mean = mean + tensor_f64_at(input, r, c);
            c = c + 1;
        };
        mean = mean / cols_f;

        let mut var: f64 = 0.0;
        c = 0;
        while c < input.shape.cols {
            let centered: f64 = tensor_f64_at(input, r, c) - mean;
            var = var + centered * centered;
            c = c + 1;
        };
        var = var / cols_f;
        let inv_std: f64 = 1.0 / math_sqrt_f64(var + eps);

        let mut sum_dhat: f64 = 0.0;
        let mut sum_dhat_norm: f64 = 0.0;
        c = 0;
        while c < input.shape.cols {
            let normalized: f64 = (tensor_f64_at(input, r, c) - mean) * inv_std;
            let go: f64 = tensor_f64_at(grad_output, r, c);
            let dhat: f64 = go * tensor_f64_at(weight, 0, c);
            gwd[c] = gwd[c] + go * normalized;
            gbd[c] = gbd[c] + go;
            sum_dhat = sum_dhat + dhat;
            sum_dhat_norm = sum_dhat_norm + dhat * normalized;
            c = c + 1;
        };

        c = 0;
        while c < input.shape.cols {
            let normalized2: f64 = (tensor_f64_at(input, r, c) - mean) * inv_std;
            let dhat2: f64 = tensor_f64_at(grad_output, r, c) * tensor_f64_at(weight, 0, c);
            gid.push((dhat2 * cols_f - sum_dhat - normalized2 * sum_dhat_norm) * inv_std / cols_f);
            c = c + 1;
        };
        r = r + 1;
    };

    return LayerNormBackwardF64 {
        grad_input: tensor_f64_from_vec(input.shape.rows, input.shape.cols, gid),
        grad_weight: tensor_f64_from_vec(1, input.shape.cols, gwd),
        grad_bias: tensor_f64_from_vec(1, input.shape.cols, gbd)
    };
}

fn nn_mse_loss_f64(input: &TensorF64, target: &TensorF64) -> f64 {
    if shape2_assert_same(&input.shape, &target.shape) != 0 {
        return -1.0;
    };
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        let d: f64 = input.data[i] - target.data[i];
        acc = acc + d * d;
        i = i + 1;
    };
    return acc / (tensor_f64_len(input) as f64);
}

fn nn_mse_loss_backward_f64(input: &TensorF64, target: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&input.shape, &target.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let scale: f64 = 2.0 / (tensor_f64_len(input) as f64);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push((input.data[i] - target.data[i]) * scale);
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_l1_loss_f64(input: &TensorF64, target: &TensorF64) -> f64 {
    if shape2_assert_same(&input.shape, &target.shape) != 0 {
        return -1.0;
    };
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        let mut d: f64 = input.data[i] - target.data[i];
        if d < 0.0 { d = 0.0 - d; };
        acc = acc + d;
        i = i + 1;
    };
    return acc / (tensor_f64_len(input) as f64);
}

fn nn_nll_loss_f64(log_probs: &TensorF64, target: &TensorI64) -> f64 {
    if target.shape.rows != log_probs.shape.rows {
        print("nn error: target rows must equal input rows");
        return -1.0;
    };
    if target.shape.cols != 1 {
        print("nn error: target must be a single class-index column");
        return -1.0;
    };

    let mut acc: f64 = 0.0;
    let mut r: i64 = 0;
    while r < log_probs.shape.rows {
        let cls: i64 = tensor_i64_at(target, r, 0);
        if cls < 0 {
            print("nn error: target class index is negative");
            return -1.0;
        };
        if cls >= log_probs.shape.cols {
            print("nn error: target class index exceeds input classes");
            return -1.0;
        };
        acc = acc - tensor_f64_at(log_probs, r, cls);
        r = r + 1;
    };
    return acc / (log_probs.shape.rows as f64);
}

fn nn_log_softmax_f64(logits: &TensorF64) -> TensorF64 {
    if logits.shape.cols <= 0 {
        print("nn error: logits must have at least one class");
        return tensor_f64_zeros(0, 0);
    };

    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < logits.shape.rows {
        let mut max_val: f64 = tensor_f64_at(logits, r, 0);
        let mut c: i64 = 1;
        while c < logits.shape.cols {
            let v: f64 = tensor_f64_at(logits, r, c);
            if v > max_val { max_val = v; };
            c = c + 1;
        };

        let mut sum_exp: f64 = 0.0;
        c = 0;
        while c < logits.shape.cols {
            sum_exp = sum_exp + math_exp_f64(tensor_f64_at(logits, r, c) - max_val);
            c = c + 1;
        };
        let log_sum: f64 = max_val + math_log_f64(sum_exp);
        c = 0;
        while c < logits.shape.cols {
            data.push(tensor_f64_at(logits, r, c) - log_sum);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(logits.shape.rows, logits.shape.cols, data);
}

fn nn_sigmoid_scalar_f64(x: f64) -> f64 {
    if x >= 0.0 {
        return 1.0 / (1.0 + math_exp_f64(0.0 - x));
    };
    let z: f64 = math_exp_f64(x);
    return z / (1.0 + z);
}

fn nn_sigmoid_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        data.push(nn_sigmoid_scalar_f64(input.data[i]));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_silu_f64(input: &TensorF64) -> TensorF64 {
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(input) {
        let x: f64 = input.data[i];
        data.push(x * nn_sigmoid_scalar_f64(x));
        i = i + 1;
    };
    return tensor_f64_from_vec(input.shape.rows, input.shape.cols, data);
}

fn nn_cross_entropy_loss_f64(logits: &TensorF64, target: &TensorI64) -> f64 {
    let log_probs: TensorF64 = nn_log_softmax_f64(logits);
    return nn_nll_loss_f64(&log_probs, target);
}

fn nn_cross_entropy_backward_f64(logits: &TensorF64, target: &TensorI64) -> TensorF64 {
    if logits.shape.rows <= 0 {
        print("nn error: logits must have at least one row");
        return tensor_f64_zeros(0, 0);
    };
    if logits.shape.cols <= 0 {
        print("nn error: logits must have at least one class");
        return tensor_f64_zeros(0, 0);
    };
    if target.shape.rows != logits.shape.rows {
        print("nn error: target rows must equal input rows");
        return tensor_f64_zeros(0, 0);
    };
    if target.shape.cols != 1 {
        print("nn error: target must be a single class-index column");
        return tensor_f64_zeros(0, 0);
    };

    let log_probs: TensorF64 = nn_log_softmax_f64(logits);
    let scale: f64 = 1.0 / (logits.shape.rows as f64);
    let mut data: Vec<f64> = Vec::new();
    let mut r: i64 = 0;
    while r < logits.shape.rows {
        let cls: i64 = tensor_i64_at(target, r, 0);
        if cls < 0 {
            print("nn error: target class index is negative");
            return tensor_f64_zeros(0, 0);
        };
        if cls >= logits.shape.cols {
            print("nn error: target class index exceeds input classes");
            return tensor_f64_zeros(0, 0);
        };

        let mut c: i64 = 0;
        while c < logits.shape.cols {
            let mut grad: f64 = math_exp_f64(tensor_f64_at(&log_probs, r, c));
            if c == cls {
                grad = grad - 1.0;
            };
            data.push(grad * scale);
            c = c + 1;
        };
        r = r + 1;
    };
    return tensor_f64_from_vec(logits.shape.rows, logits.shape.cols, data);
}

fn nn_bce_with_logits_loss_f64(logits: &TensorF64, target: &TensorF64) -> f64 {
    if shape2_assert_same(&logits.shape, &target.shape) != 0 {
        return -1.0;
    };
    let mut acc: f64 = 0.0;
    let mut i: i64 = 0;
    while i < tensor_f64_len(logits) {
        let x: f64 = logits.data[i];
        let y: f64 = target.data[i];
        let mut max_x: f64 = 0.0;
        let mut neg_abs_x: f64 = x;
        if x >= 0.0 {
            max_x = x;
            neg_abs_x = 0.0 - x;
        };
        acc = acc + max_x - x * y + math_log_f64(1.0 + math_exp_f64(neg_abs_x));
        i = i + 1;
    };
    return acc / (tensor_f64_len(logits) as f64);
}

fn nn_bce_with_logits_backward_f64(logits: &TensorF64, target: &TensorF64) -> TensorF64 {
    if shape2_assert_same(&logits.shape, &target.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let scale: f64 = 1.0 / (tensor_f64_len(logits) as f64);
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(logits) {
        data.push((nn_sigmoid_scalar_f64(logits.data[i]) - target.data[i]) * scale);
        i = i + 1;
    };
    return tensor_f64_from_vec(logits.shape.rows, logits.shape.cols, data);
}

fn nn_sgd_step_f64(param: &TensorF64, grad: &TensorF64, learning_rate: f64) -> TensorF64 {
    if shape2_assert_same(&param.shape, &grad.shape) != 0 {
        return tensor_f64_zeros(0, 0);
    };
    let mut data: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(param) {
        data.push(param.data[i] - learning_rate * grad.data[i]);
        i = i + 1;
    };
    return tensor_f64_from_vec(param.shape.rows, param.shape.cols, data);
}

fn nn_sgd_momentum_step_f64(param: &TensorF64, grad: &TensorF64, velocity: &TensorF64, learning_rate: f64, momentum: f64) -> SgdMomentumStepF64 {
    if shape2_assert_same(&param.shape, &grad.shape) != 0 {
        return SgdMomentumStepF64 { param: tensor_f64_zeros(0, 0), velocity: tensor_f64_zeros(0, 0) };
    };
    if shape2_assert_same(&param.shape, &velocity.shape) != 0 {
        return SgdMomentumStepF64 { param: tensor_f64_zeros(0, 0), velocity: tensor_f64_zeros(0, 0) };
    };

    let mut pdata: Vec<f64> = Vec::new();
    let mut vdata: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(param) {
        let next_velocity: f64 = momentum * velocity.data[i] + grad.data[i];
        vdata.push(next_velocity);
        pdata.push(param.data[i] - learning_rate * next_velocity);
        i = i + 1;
    };

    return SgdMomentumStepF64 {
        param: tensor_f64_from_vec(param.shape.rows, param.shape.cols, pdata),
        velocity: tensor_f64_from_vec(param.shape.rows, param.shape.cols, vdata)
    };
}

fn nn_adamw_step_f64(param: &TensorF64, grad: &TensorF64, exp_avg: &TensorF64, exp_avg_sq: &TensorF64, learning_rate: f64, beta1: f64, beta2: f64, weight_decay: f64, eps: f64, step_num: i64) -> AdamWStepF64 {
    if step_num <= 0 {
        print("nn error: AdamW step_num must be positive");
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };
    if shape2_assert_same(&param.shape, &grad.shape) != 0 {
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };
    if shape2_assert_same(&param.shape, &exp_avg.shape) != 0 {
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };
    if shape2_assert_same(&param.shape, &exp_avg_sq.shape) != 0 {
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };

    let bias_correction1: f64 = 1.0 - nn_f64_powi(beta1, step_num);
    let bias_correction2: f64 = 1.0 - nn_f64_powi(beta2, step_num);
    if bias_correction1 == 0.0 {
        print("nn error: AdamW beta1 bias correction is zero");
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };
    if bias_correction2 == 0.0 {
        print("nn error: AdamW beta2 bias correction is zero");
        return AdamWStepF64 { param: tensor_f64_zeros(0, 0), exp_avg: tensor_f64_zeros(0, 0), exp_avg_sq: tensor_f64_zeros(0, 0) };
    };

    let mut pdata: Vec<f64> = Vec::new();
    let mut mdata: Vec<f64> = Vec::new();
    let mut vdata: Vec<f64> = Vec::new();
    let mut i: i64 = 0;
    while i < tensor_f64_len(param) {
        let g: f64 = grad.data[i];
        let next_m: f64 = beta1 * exp_avg.data[i] + (1.0 - beta1) * g;
        let next_v: f64 = beta2 * exp_avg_sq.data[i] + (1.0 - beta2) * g * g;
        let denom: f64 = math_sqrt_f64(next_v / bias_correction2) + eps;
        let decayed_param: f64 = param.data[i] * (1.0 - learning_rate * weight_decay);
        let update: f64 = (next_m / bias_correction1) / denom;
        mdata.push(next_m);
        vdata.push(next_v);
        pdata.push(decayed_param - learning_rate * update);
        i = i + 1;
    };

    return AdamWStepF64 {
        param: tensor_f64_from_vec(param.shape.rows, param.shape.cols, pdata),
        exp_avg: tensor_f64_from_vec(param.shape.rows, param.shape.cols, mdata),
        exp_avg_sq: tensor_f64_from_vec(param.shape.rows, param.shape.cols, vdata)
    };
}

fn nn_two_layer_relu_f64(input: &TensorF64, w1: &TensorF64, b1: &TensorF64, w2: &TensorF64, b2: &TensorF64) -> TensorF64 {
    let h_pre: TensorF64 = nn_linear_f64(input, w1, b1);
    let h: TensorF64 = nn_relu_f64(&h_pre);
    return nn_linear_f64(&h, w2, b2);
}

fn nn_two_layer_relu_cross_entropy_sgd_step_f64(input: &TensorF64, target: &TensorI64, w1: &TensorF64, b1: &TensorF64, w2: &TensorF64, b2: &TensorF64, learning_rate: f64) -> TwoLayerReluCrossEntropySgdStepF64 {
    let h_pre: TensorF64 = nn_linear_f64(input, w1, b1);
    let h: TensorF64 = nn_relu_f64(&h_pre);
    let logits: TensorF64 = nn_linear_f64(&h, w2, b2);
    let loss: f64 = nn_cross_entropy_loss_f64(&logits, target);
    let grad_logits: TensorF64 = nn_cross_entropy_backward_f64(&logits, target);
    let bw2: LinearBackwardF64 = nn_linear_backward_f64(&h, w2, &grad_logits);
    let grad_h_pre: TensorF64 = nn_relu_backward_f64(&h_pre, &bw2.grad_input);
    let bw1: LinearBackwardF64 = nn_linear_backward_f64(input, w1, &grad_h_pre);

    return TwoLayerReluCrossEntropySgdStepF64 {
        loss: loss,
        w1: nn_sgd_step_f64(w1, &bw1.grad_weight, learning_rate),
        b1: nn_sgd_step_f64(b1, &bw1.grad_bias, learning_rate),
        w2: nn_sgd_step_f64(w2, &bw2.grad_weight, learning_rate),
        b2: nn_sgd_step_f64(b2, &bw2.grad_bias, learning_rate)
    };
}

fn nn_two_layer_relu_cross_entropy_adamw_step_f64(input: &TensorF64, target: &TensorI64, w1: &TensorF64, b1: &TensorF64, w2: &TensorF64, b2: &TensorF64, w1_exp_avg: &TensorF64, w1_exp_avg_sq: &TensorF64, b1_exp_avg: &TensorF64, b1_exp_avg_sq: &TensorF64, w2_exp_avg: &TensorF64, w2_exp_avg_sq: &TensorF64, b2_exp_avg: &TensorF64, b2_exp_avg_sq: &TensorF64, learning_rate: f64, beta1: f64, beta2: f64, weight_decay: f64, eps: f64, step_num: i64) -> TwoLayerReluCrossEntropyAdamWStepF64 {
    let h_pre: TensorF64 = nn_linear_f64(input, w1, b1);
    let h: TensorF64 = nn_relu_f64(&h_pre);
    let logits: TensorF64 = nn_linear_f64(&h, w2, b2);
    let loss: f64 = nn_cross_entropy_loss_f64(&logits, target);
    let grad_logits: TensorF64 = nn_cross_entropy_backward_f64(&logits, target);
    let bw2: LinearBackwardF64 = nn_linear_backward_f64(&h, w2, &grad_logits);
    let grad_h_pre: TensorF64 = nn_relu_backward_f64(&h_pre, &bw2.grad_input);
    let bw1: LinearBackwardF64 = nn_linear_backward_f64(input, w1, &grad_h_pre);

    let next_w1: AdamWStepF64 = nn_adamw_step_f64(w1, &bw1.grad_weight, w1_exp_avg, w1_exp_avg_sq, learning_rate, beta1, beta2, weight_decay, eps, step_num);
    let next_b1: AdamWStepF64 = nn_adamw_step_f64(b1, &bw1.grad_bias, b1_exp_avg, b1_exp_avg_sq, learning_rate, beta1, beta2, weight_decay, eps, step_num);
    let next_w2: AdamWStepF64 = nn_adamw_step_f64(w2, &bw2.grad_weight, w2_exp_avg, w2_exp_avg_sq, learning_rate, beta1, beta2, weight_decay, eps, step_num);
    let next_b2: AdamWStepF64 = nn_adamw_step_f64(b2, &bw2.grad_bias, b2_exp_avg, b2_exp_avg_sq, learning_rate, beta1, beta2, weight_decay, eps, step_num);

    return TwoLayerReluCrossEntropyAdamWStepF64 {
        loss: loss,
        w1: next_w1.param,
        b1: next_b1.param,
        w2: next_w2.param,
        b2: next_b2.param,
        w1_exp_avg: next_w1.exp_avg,
        w1_exp_avg_sq: next_w1.exp_avg_sq,
        b1_exp_avg: next_b1.exp_avg,
        b1_exp_avg_sq: next_b1.exp_avg_sq,
        w2_exp_avg: next_w2.exp_avg,
        w2_exp_avg_sq: next_w2.exp_avg_sq,
        b2_exp_avg: next_b2.exp_avg,
        b2_exp_avg_sq: next_b2.exp_avg_sq
    };
}

fn nn_two_layer_gelu_tanh_f64(input: &TensorF64, w1: &TensorF64, b1: &TensorF64, w2: &TensorF64, b2: &TensorF64) -> TensorF64 {
    let h_pre: TensorF64 = nn_linear_f64(input, w1, b1);
    let h: TensorF64 = nn_gelu_tanh_f64(&h_pre);
    return nn_linear_f64(&h, w2, b2);
}
