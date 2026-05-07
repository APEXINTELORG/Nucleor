import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_threshold_column_f64 — extract a single column from a
// thresholds tensor. 3x2 thresholds, col=1 → 1x3 column tensor.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut td: Vec<f64> = Vec::new();
    td.push(0.1); td.push(0.5);
    td.push(0.2); td.push(0.6);
    td.push(0.3); td.push(0.7);
    let thresholds: TensorF64 = tensor_f64_from_vec(3, 2, td);

    let col1: TensorF64 = ai_threshold_column_f64(&thresholds, 1);
    if col1.shape.rows != 3 { print("FAIL col rows"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&col1, 0, 0), 0.5, eps) != 1 { print("FAIL col 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&col1, 1, 0), 0.6, eps) != 1 { print("FAIL col 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&col1, 2, 0), 0.7, eps) != 1 { print("FAIL col 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_threshold_column_f64"); return 0; };
    print("FAIL ml_recover_threshold_column_f64");
    return 1;
}
