import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_bce_with_logits_backward_f64 — BCE-with-logits backward.
// d(loss)/d(logit) = (sigmoid(logit) - target) / N.
// logits=[0, 0], target=[0, 1]: sigmoid=0.5 each. grads=[0.5, -0.5]/2=[0.25, -0.25].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut ld: Vec<f64> = Vec::new();
    ld.push(0.0); ld.push(0.0);
    let logits: TensorF64 = tensor_f64_from_vec(1, 2, ld);

    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(1.0);
    let target: TensorF64 = tensor_f64_from_vec(1, 2, td);

    let g: TensorF64 = nn_bce_with_logits_backward_f64(&logits, &target);
    if g.shape.cols != 2 { print("FAIL g cols"); fail = fail + 1; };

    // Gradient should have opposite signs (positive for target 0, negative for target 1).
    if tensor_f64_at(&g, 0, 0) <= 0.0 { print("FAIL g0 sign"); fail = fail + 1; };
    if tensor_f64_at(&g, 0, 1) >= 0.0 { print("FAIL g1 sign"); fail = fail + 1; };
    // Magnitudes should be equal in absolute value.
    if close_f64(tensor_f64_at(&g, 0, 0), 0.0 - tensor_f64_at(&g, 0, 1), eps) != 1 {
        print("FAIL g symmetry"); fail = fail + 1;
    };

    if fail == 0 { print("OK ml_recover_bce_with_logits_backward_f64"); return 0; };
    print("FAIL ml_recover_bce_with_logits_backward_f64");
    return 1;
}
