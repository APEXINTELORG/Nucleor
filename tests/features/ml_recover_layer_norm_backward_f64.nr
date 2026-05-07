import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_layer_norm_backward_f64 — LayerNorm backward returns three
// tensor gradients (input, weight, bias). Verify shapes; sanity-check
// that bias gradient sums grad_output along axis 0.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    // input (1x3), weight (1x3), grad_out (1x3).
    let mut id: Vec<f64> = Vec::new();
    id.push(1.0); id.push(2.0); id.push(3.0);
    let input: TensorF64 = tensor_f64_from_vec(1, 3, id);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.0); wd.push(1.0); wd.push(1.0);
    let weight: TensorF64 = tensor_f64_from_vec(1, 3, wd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(0.5); gd.push(0.5); gd.push(0.5);
    let grad_out: TensorF64 = tensor_f64_from_vec(1, 3, gd);

    let result: LayerNormBackwardF64 = nn_layer_norm_backward_f64(&input, &weight, &grad_out, 0.00001);
    if result.grad_input.shape.cols != 3 { print("FAIL grad_input cols"); fail = fail + 1; };
    if result.grad_weight.shape.cols != 3 { print("FAIL grad_weight cols"); fail = fail + 1; };
    if result.grad_bias.shape.cols != 3 { print("FAIL grad_bias cols"); fail = fail + 1; };

    // grad_bias should equal grad_output summed along axis 0 (single batch row → grad_bias = grad_out).
    if close_f64(tensor_f64_at(&result.grad_bias, 0, 0), 0.5, eps) != 1 { print("FAIL grad_bias 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&result.grad_bias, 0, 2), 0.5, eps) != 1 { print("FAIL grad_bias 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_layer_norm_backward_f64"); return 0; };
    print("FAIL ml_recover_layer_norm_backward_f64");
    return 1;
}
