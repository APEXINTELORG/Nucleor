import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_relu_backward_f64 — gating backward gradient. For ReLU,
// gradient passes through where input > 0, otherwise blocked.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // input = [-1, 0, 1, 2], grad_out = [10, 10, 10, 10]
    // ReLU bwd: 0 where input <= 0, else grad_out.
    let mut id: Vec<f64> = Vec::new();
    id.push(0.0 - 1.0); id.push(0.0); id.push(1.0); id.push(2.0);
    let input: TensorF64 = tensor_f64_from_vec(1, 4, id);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(10.0); gd.push(10.0); gd.push(10.0); gd.push(10.0);
    let grad_out: TensorF64 = tensor_f64_from_vec(1, 4, gd);

    let g: TensorF64 = nn_relu_backward_f64(&input, &grad_out);
    if g.shape.cols != 4 { print("FAIL g cols"); fail = fail + 1; };

    if close_f64(tensor_f64_at(&g, 0, 0), 0.0, eps) != 1 { print("FAIL g 0"); fail = fail + 1; };
    // input == 0 boundary — accept 0 OR 10 (implementation choice).
    if close_f64(tensor_f64_at(&g, 0, 2), 10.0, eps) != 1 { print("FAIL g 2"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&g, 0, 3), 10.0, eps) != 1 { print("FAIL g 3"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_relu_backward_f64"); return 0; };
    print("FAIL ml_recover_relu_backward_f64");
    return 1;
}
