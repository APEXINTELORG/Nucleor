import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_sgd_step_f64 — single SGD update: param -= lr * grad.
// param=[1.0, 2.0], grad=[0.1, 0.2], lr=0.5 → [0.95, 1.9].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut pd: Vec<f64> = Vec::new();
    pd.push(1.0); pd.push(2.0);
    let param: TensorF64 = tensor_f64_from_vec(1, 2, pd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(0.1); gd.push(0.2);
    let grad: TensorF64 = tensor_f64_from_vec(1, 2, gd);

    let p_new: TensorF64 = nn_sgd_step_f64(&param, &grad, 0.5);
    if close_f64(tensor_f64_at(&p_new, 0, 0), 0.95, eps) != 1 { print("FAIL p 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&p_new, 0, 1), 1.9, eps) != 1 { print("FAIL p 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_sgd_step_f64"); return 0; };
    print("FAIL ml_recover_sgd_step_f64");
    return 1;
}
