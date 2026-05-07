import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_sgd_momentum_step_f64 — SGD with momentum:
// v_new = momentum * v + grad
// param_new = param - lr * v_new

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

    let mut vd: Vec<f64> = Vec::new();
    vd.push(0.0); vd.push(0.0);
    let velocity: TensorF64 = tensor_f64_from_vec(1, 2, vd);

    // First step (v=0): v_new = 0.9*0 + 0.1 = 0.1, p_new = 1 - 0.5*0.1 = 0.95.
    // Second feature: v_new = 0.2, p_new = 2 - 0.5*0.2 = 1.9.
    let result: SgdMomentumStepF64 = nn_sgd_momentum_step_f64(&param, &grad, &velocity, 0.5, 0.9);
    if close_f64(tensor_f64_at(&result.param, 0, 0), 0.95, eps) != 1 { print("FAIL p 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&result.param, 0, 1), 1.9, eps) != 1 { print("FAIL p 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&result.velocity, 0, 0), 0.1, eps) != 1 { print("FAIL v 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&result.velocity, 0, 1), 0.2, eps) != 1 { print("FAIL v 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_sgd_momentum_step_f64"); return 0; };
    print("FAIL ml_recover_sgd_momentum_step_f64");
    return 1;
}
