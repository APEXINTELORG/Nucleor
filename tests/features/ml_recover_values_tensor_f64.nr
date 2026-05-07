import "stdlib/rods/ml/data_facade.nr"

// ml_recover_values_tensor_f64 — frame value-column → TensorF64.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut keys: Vec<i64> = Vec::new();
    keys.push(10); keys.push(20); keys.push(30);

    let mut values: Vec<f64> = Vec::new();
    values.push(0.1); values.push(0.2); values.push(0.3);

    let frame: FrameI64F64 = frame_i64_f64_from_vec("k", "v", keys, values);

    let t: TensorF64 = frame_i64_f64_values_tensor(&frame);
    if t.shape.rows != 3 { print("FAIL t rows"); fail = fail + 1; };
    if t.shape.cols != 1 { print("FAIL t cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 0, 0), 0.1, eps) != 1 { print("FAIL t 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 1, 0), 0.2, eps) != 1 { print("FAIL t 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 2, 0), 0.3, eps) != 1 { print("FAIL t 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_values_tensor_f64"); return 0; };
    print("FAIL ml_recover_values_tensor_f64");
    return 1;
}
