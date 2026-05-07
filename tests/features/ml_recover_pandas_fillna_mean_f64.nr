import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_fillna_mean_f64 — nullable-frame fillna + mean.

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
    keys.push(1); keys.push(2); keys.push(3);
    let mut vals: Vec<f64> = Vec::new();
    vals.push(10.0); vals.push(0.0); vals.push(30.0);
    let mut valid: Vec<i64> = Vec::new();
    valid.push(1); valid.push(0); valid.push(1);
    let frame: FrameI64NullableF64 = frame_i64_nullable_f64_from_vec("k", "v", keys, vals, valid);

    // fillna(99.0) → values=[10, 99, 30]
    let filled: FrameI64F64 = frame_i64_nullable_f64_fillna(&frame, 99.0);
    if filled.rows != 3 { print("FAIL filled rows"); fail = fail + 1; };
    if close_f64(vec_get(filled.values, 1), 99.0, eps) != 1 { print("FAIL fillna 1"); fail = fail + 1; };

    // mean of valid values only: (10 + 30) / 2 = 20.
    let m: f64 = frame_i64_nullable_f64_mean(&frame);
    if close_f64(m, 20.0, eps) != 1 { print("FAIL mean"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_fillna_mean_f64"); return 0; };
    print("FAIL ml_recover_pandas_fillna_mean_f64");
    return 1;
}
