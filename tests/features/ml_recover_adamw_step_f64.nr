import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_adamw_step_f64 — single AdamW update step. Returns
// AdamWStepF64{param, exp_avg, exp_avg_sq}. Verify shapes + sanity
// (param moves toward gradient direction with non-trivial magnitude).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut pd: Vec<f64> = Vec::new();
    pd.push(1.0); pd.push(2.0);
    let param: TensorF64 = tensor_f64_from_vec(1, 2, pd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(0.1); gd.push(0.2);
    let grad: TensorF64 = tensor_f64_from_vec(1, 2, gd);

    let mut zd: Vec<f64> = Vec::new();
    zd.push(0.0); zd.push(0.0);
    let exp_avg: TensorF64 = tensor_f64_from_vec(1, 2, zd);

    let mut zd2: Vec<f64> = Vec::new();
    zd2.push(0.0); zd2.push(0.0);
    let exp_avg_sq: TensorF64 = tensor_f64_from_vec(1, 2, zd2);

    let result: AdamWStepF64 = nn_adamw_step_f64(&param, &grad, &exp_avg, &exp_avg_sq, 0.01, 0.9, 0.999, 0.0, 0.000001, 1);

    if result.param.shape.cols != 2 { print("FAIL p cols"); fail = fail + 1; };
    if result.exp_avg.shape.cols != 2 { print("FAIL m cols"); fail = fail + 1; };
    if result.exp_avg_sq.shape.cols != 2 { print("FAIL v cols"); fail = fail + 1; };

    // After 1 AdamW step with grad=[0.1, 0.2], lr=0.01: param should decrease.
    // Direction: exp_avg = (1-beta1)*grad ≈ 0.01, 0.02, normalized step ≈ ±0.01 each
    // (so param[0] ≈ 1 - 0.01 = 0.99, param[1] ≈ 2 - 0.01 = 1.99).
    if tensor_f64_at(&result.param, 0, 0) >= 1.0 { print("FAIL p0 not decreased"); fail = fail + 1; };
    if tensor_f64_at(&result.param, 0, 1) >= 2.0 { print("FAIL p1 not decreased"); fail = fail + 1; };
    if tensor_f64_at(&result.param, 0, 0) <= 0.95 { print("FAIL p0 too small"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_adamw_step_f64"); return 0; };
    print("FAIL ml_recover_adamw_step_f64");
    return 1;
}
