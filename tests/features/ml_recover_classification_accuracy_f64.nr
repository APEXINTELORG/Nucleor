import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_classification_accuracy_f64 — direct-pair accuracy:
// y_true = [0, 1, 1, 0, 1], y_pred = [0, 1, 0, 0, 1]: 4 of 5 match → 0.8.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut td: Vec<i64> = Vec::new();
    td.push(0); td.push(1); td.push(1); td.push(0); td.push(1);
    let y_true: TensorI64 = tensor_i64_from_vec(5, 1, td);

    let mut pd: Vec<i64> = Vec::new();
    pd.push(0); pd.push(1); pd.push(0); pd.push(0); pd.push(1);
    let y_pred: TensorI64 = tensor_i64_from_vec(5, 1, pd);

    let acc: f64 = classification_accuracy_i64(&y_true, &y_pred);
    if close_f64(acc, 0.8, eps) != 1 { print("FAIL accuracy"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_classification_accuracy_f64"); return 0; };
    print("FAIL ml_recover_classification_accuracy_f64");
    return 1;
}
