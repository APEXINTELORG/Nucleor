import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_tail_f64 — tail(n) of a 5-row frame returns last n.

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

    let t: FrameI64F64 = frame_i64_f64_tail(&frame, 2);
    if t.rows != 2 { print("FAIL tail rows"); fail = fail + 1; };
    if vec_get(t.keys, 0) != 4 { print("FAIL tail k0"); fail = fail + 1; };
    if vec_get(t.keys, 1) != 5 { print("FAIL tail k1"); fail = fail + 1; };
    if close_f64(vec_get(t.values, 0), 40.0, eps) != 1 { print("FAIL tail v0"); fail = fail + 1; };
    if close_f64(vec_get(t.values, 1), 50.0, eps) != 1 { print("FAIL tail v1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_tail_f64"); return 0; };
    print("FAIL ml_recover_pandas_tail_f64");
    return 1;
}
