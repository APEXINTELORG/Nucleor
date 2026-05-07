import "stdlib/rods/ml/learn_facade.nr"

// ml_recover_confusion_matrix_i64 — 2-class confusion matrix.
// y_true = [0, 0, 1, 1, 1], y_pred = [0, 1, 1, 1, 0]
// → TN(0,0)=1, FP(0,1)=1, FN(1,0)=1, TP(1,1)=2.

fn main() -> i32 {
    let mut fail: i64 = 0;

    let mut td: Vec<i64> = Vec::new();
    td.push(0); td.push(0); td.push(1); td.push(1); td.push(1);
    let y_true: TensorI64 = tensor_i64_from_vec(5, 1, td);

    let mut pd: Vec<i64> = Vec::new();
    pd.push(0); pd.push(1); pd.push(1); pd.push(1); pd.push(0);
    let y_pred: TensorI64 = tensor_i64_from_vec(5, 1, pd);

    let cm: TensorI64 = confusion_matrix_i64(&y_true, &y_pred, 2);
    if cm.shape.rows != 2 { print("FAIL cm rows"); fail = fail + 1; };
    if cm.shape.cols != 2 { print("FAIL cm cols"); fail = fail + 1; };
    if tensor_i64_at(&cm, 0, 0) != 1 { print("FAIL cm 00"); fail = fail + 1; };
    if tensor_i64_at(&cm, 0, 1) != 1 { print("FAIL cm 01"); fail = fail + 1; };
    if tensor_i64_at(&cm, 1, 0) != 1 { print("FAIL cm 10"); fail = fail + 1; };
    if tensor_i64_at(&cm, 1, 1) != 2 { print("FAIL cm 11"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_confusion_matrix_i64"); return 0; };
    print("FAIL ml_recover_confusion_matrix_i64");
    return 1;
}
