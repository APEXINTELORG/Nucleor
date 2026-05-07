import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_log_softmax_f64 — minimal log_softmax forward.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.0001;

    // Logits [0, 0, 0]: log_softmax should be log(1/3) for each element.
    let mut ld: Vec<f64> = Vec::new();
    ld.push(0.0); ld.push(0.0); ld.push(0.0);
    let logits: TensorF64 = tensor_f64_from_vec(1, 3, ld);

    let lp: TensorF64 = nn_log_softmax_f64(&logits);
    if lp.shape.cols != 3 { print("FAIL lp cols"); fail = fail + 1; };

    // log(1/3) ≈ -1.0986
    let expected: f64 = 0.0 - 1.0986123;
    if close_f64(tensor_f64_at(&lp, 0, 0), expected, eps) != 1 { print("FAIL lp 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&lp, 0, 1), expected, eps) != 1 { print("FAIL lp 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&lp, 0, 2), expected, eps) != 1 { print("FAIL lp 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_log_softmax_f64"); return 0; };
    print("FAIL ml_recover_log_softmax_f64");
    return 1;
}
