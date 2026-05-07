import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_gelu_tanh_backward_f64 — single-pass backward through
// tanh-GELU. At input=0, derivative ≈ 0.5; at large positive inputs,
// derivative → 1; at large negative → 0.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.05;

    let mut id: Vec<f64> = Vec::new();
    id.push(0.0); id.push(5.0); id.push(0.0 - 5.0);
    let input: TensorF64 = tensor_f64_from_vec(1, 3, id);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(1.0); gd.push(1.0); gd.push(1.0);
    let grad_out: TensorF64 = tensor_f64_from_vec(1, 3, gd);

    let g: TensorF64 = nn_gelu_tanh_backward_f64(&input, &grad_out);
    if g.shape.cols != 3 { print("FAIL g cols"); fail = fail + 1; };

    // Derivative at input=0: ≈ 0.5
    if close_f64(tensor_f64_at(&g, 0, 0), 0.5, eps) != 1 { print("FAIL g 0"); fail = fail + 1; };
    // Large positive: ≈ 1
    if tensor_f64_at(&g, 0, 1) < 0.95 { print("FAIL g large+"); fail = fail + 1; };
    // Large negative: ≈ 0
    if tensor_f64_at(&g, 0, 2) > 0.05 { print("FAIL g large-"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_gelu_tanh_backward_f64"); return 0; };
    print("FAIL ml_recover_gelu_tanh_backward_f64");
    return 1;
}
