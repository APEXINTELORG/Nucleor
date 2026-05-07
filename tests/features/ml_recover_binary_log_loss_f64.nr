import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_binary_log_loss_f64 — scalar binary log loss.
// y_true=[1, 0, 1, 0], probas=[0.9, 0.1, 0.8, 0.2]: each pred is correct
// with high confidence → log loss is small (≈ 0.164).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.05;

    let mut td: Vec<i64> = Vec::new();
    td.push(1); td.push(0); td.push(1); td.push(0);
    let y_true: TensorI64 = tensor_i64_from_vec(4, 1, td);

    let mut pd: Vec<f64> = Vec::new();
    pd.push(0.9); pd.push(0.1); pd.push(0.8); pd.push(0.2);
    let probas: TensorF64 = tensor_f64_from_vec(4, 1, pd);

    let loss: f64 = binary_log_loss_i64_f64(&y_true, &probas, 1);
    // Each prediction matches with 0.8-0.9 prob: loss = mean(-log(0.9), -log(0.9), -log(0.8), -log(0.8))
    //                                              ≈ mean(0.105, 0.105, 0.223, 0.223) ≈ 0.164.
    if loss < 0.05 { print("FAIL loss too small"); fail = fail + 1; };
    if loss > 0.5 { print("FAIL loss too large"); fail = fail + 1; };
    if close_f64(loss, 0.164, eps) != 1 { print("FAIL loss not ~0.164"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_binary_log_loss_f64"); return 0; };
    print("FAIL ml_recover_binary_log_loss_f64");
    return 1;
}
