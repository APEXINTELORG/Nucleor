import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_binary_roc_auc_f64 — perfect-separation ROC AUC = 1.0.
// y_true=[0, 0, 1, 1], scores=[0.1, 0.2, 0.8, 0.9]: ranking puts all
// positives above all negatives → AUC = 1.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut td: Vec<i64> = Vec::new();
    td.push(0); td.push(0); td.push(1); td.push(1);
    let y_true: TensorI64 = tensor_i64_from_vec(4, 1, td);

    let mut sd: Vec<f64> = Vec::new();
    sd.push(0.1); sd.push(0.2); sd.push(0.8); sd.push(0.9);
    let scores: TensorF64 = tensor_f64_from_vec(4, 1, sd);

    let auc: f64 = binary_roc_auc_f64(&y_true, &scores, 1);
    if close_f64(auc, 1.0, eps) != 1 { print("FAIL auc"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_binary_roc_auc_f64"); return 0; };
    print("FAIL ml_recover_binary_roc_auc_f64");
    return 1;
}
