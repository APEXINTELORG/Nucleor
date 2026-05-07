import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_dropna_f64 — minimal nullable-frame dropna smoke.
// 4 rows with valid mask [1, 0, 1, 1]: dropna drops the row at idx 1.

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
    keys.push(1); keys.push(2); keys.push(3); keys.push(4);

    let mut vals: Vec<f64> = Vec::new();
    vals.push(10.0); vals.push(0.0); vals.push(30.0); vals.push(40.0);

    let mut valid: Vec<i64> = Vec::new();
    valid.push(1); valid.push(0); valid.push(1); valid.push(1);

    let frame: FrameI64NullableF64 = frame_i64_nullable_f64_from_vec("k", "v", keys, vals, valid);

    let cleaned: FrameI64F64 = frame_i64_nullable_f64_dropna(&frame);
    if cleaned.rows != 3 { print("FAIL drop rows"); fail = fail + 1; };
    if vec_get(cleaned.keys, 0) != 1 { print("FAIL drop k0"); fail = fail + 1; };
    if vec_get(cleaned.keys, 1) != 3 { print("FAIL drop k1"); fail = fail + 1; };
    if vec_get(cleaned.keys, 2) != 4 { print("FAIL drop k2"); fail = fail + 1; };
    if close_f64(vec_get(cleaned.values, 0), 10.0, eps) != 1 { print("FAIL drop v0"); fail = fail + 1; };
    if close_f64(vec_get(cleaned.values, 2), 40.0, eps) != 1 { print("FAIL drop v2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_dropna_f64"); return 0; };
    print("FAIL ml_recover_pandas_dropna_f64");
    return 1;
}
