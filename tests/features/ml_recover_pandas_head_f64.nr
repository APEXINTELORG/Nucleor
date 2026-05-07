import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_head_f64 — head(n) of a 5-row frame returns first n.

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

    let h: FrameI64F64 = frame_i64_f64_head(&frame, 3);
    if h.rows != 3 { print("FAIL head rows"); fail = fail + 1; };
    if vec_get(h.keys, 0) != 1 { print("FAIL head k0"); fail = fail + 1; };
    if vec_get(h.keys, 2) != 3 { print("FAIL head k2"); fail = fail + 1; };
    if close_f64(vec_get(h.values, 0), 10.0, eps) != 1 { print("FAIL head v0"); fail = fail + 1; };
    if close_f64(vec_get(h.values, 2), 30.0, eps) != 1 { print("FAIL head v2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_head_f64"); return 0; };
    print("FAIL ml_recover_pandas_head_f64");
    return 1;
}
