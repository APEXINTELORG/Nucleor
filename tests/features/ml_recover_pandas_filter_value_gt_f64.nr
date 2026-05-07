import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_filter_value_gt_f64 — frame walk filter > threshold.

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
    keys.push(1); keys.push(2); keys.push(3); keys.push(4); keys.push(5);
    let mut values: Vec<f64> = Vec::new();
    values.push(10.0); values.push(20.0); values.push(30.0); values.push(40.0); values.push(50.0);

    let frame: FrameI64F64 = frame_i64_f64_from_vec("k", "v", keys, values);

    // > 25 → values [30, 40, 50] = 3 rows.
    let f: FrameI64F64 = frame_i64_f64_filter_value_gt(&frame, 25.0);
    if f.rows != 3 { print("FAIL gt rows"); fail = fail + 1; };
    if vec_get(f.keys, 0) != 3 { print("FAIL gt k0"); fail = fail + 1; };
    if close_f64(vec_get(f.values, 2), 50.0, eps) != 1 { print("FAIL gt v2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_filter_value_gt_f64"); return 0; };
    print("FAIL ml_recover_pandas_filter_value_gt_f64");
    return 1;
}
