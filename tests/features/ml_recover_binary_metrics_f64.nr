import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_binary_metrics_f64 — scalar precision, recall, F1.
// y_true = [1,1,1,0,0], y_pred = [1,1,0,0,1]:
//   TP=2, FP=1, FN=1, TN=1.
//   precision = TP/(TP+FP) = 2/3 ≈ 0.667.
//   recall = TP/(TP+FN) = 2/3 ≈ 0.667.
//   F1 = 2*P*R/(P+R) = 2/3 ≈ 0.667.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;
    let expected: f64 = 2.0 / 3.0;

    let mut td: Vec<i64> = Vec::new();
    td.push(1); td.push(1); td.push(1); td.push(0); td.push(0);
    let y_true: TensorI64 = tensor_i64_from_vec(5, 1, td);

    let mut pd: Vec<i64> = Vec::new();
    pd.push(1); pd.push(1); pd.push(0); pd.push(0); pd.push(1);
    let y_pred: TensorI64 = tensor_i64_from_vec(5, 1, pd);

    let p: f64 = binary_precision_i64(&y_true, &y_pred, 1);
    if close_f64(p, expected, eps) != 1 { print("FAIL precision"); fail = fail + 1; };

    let r: f64 = binary_recall_i64(&y_true, &y_pred, 1);
    if close_f64(r, expected, eps) != 1 { print("FAIL recall"); fail = fail + 1; };

    let f1: f64 = binary_f1_i64(&y_true, &y_pred, 1);
    if close_f64(f1, expected, eps) != 1 { print("FAIL f1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_binary_metrics_f64"); return 0; };
    print("FAIL ml_recover_binary_metrics_f64");
    return 1;
}
