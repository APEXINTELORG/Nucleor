import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_drop_duplicates_f64 — keep first occurrence per key.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // keys = [1, 2, 1, 3, 2], values = [10, 20, 11, 30, 21]
    // drop_duplicates_by_key_keep_first → keys [1, 2, 3], values [10, 20, 30].
    let mut keys: Vec<i64> = Vec::new();
    keys.push(1); keys.push(2); keys.push(1); keys.push(3); keys.push(2);
    let mut values: Vec<f64> = Vec::new();
    values.push(10.0); values.push(20.0); values.push(11.0); values.push(30.0); values.push(21.0);

    let frame: FrameI64F64 = frame_i64_f64_from_vec("k", "v", keys, values);

    let f: FrameI64F64 = frame_i64_f64_drop_duplicates_by_key_keep_first(&frame);
    if f.rows != 3 { print("FAIL dd rows"); fail = fail + 1; };
    if vec_get(f.keys, 0) != 1 { print("FAIL dd k0"); fail = fail + 1; };
    if vec_get(f.keys, 1) != 2 { print("FAIL dd k1"); fail = fail + 1; };
    if vec_get(f.keys, 2) != 3 { print("FAIL dd k2"); fail = fail + 1; };
    if close_f64(vec_get(f.values, 0), 10.0, eps) != 1 { print("FAIL dd v0"); fail = fail + 1; };
    if close_f64(vec_get(f.values, 1), 20.0, eps) != 1 { print("FAIL dd v1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_drop_duplicates_f64"); return 0; };
    print("FAIL ml_recover_pandas_drop_duplicates_f64");
    return 1;
}
