import "stdlib/rods/ml/data_facade.nr"

// ml_recover_pandas_inner_join_f64 — minimal frame inner join smoke.
// Left: keys=[1,2,3], values=[10,20,30]. Right: keys=[2,3,4], values=[200,300,400].
// Inner join on key produces 2 rows: key=2 (l=20,r=200), key=3 (l=30,r=300).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut lk: Vec<i64> = Vec::new();
    lk.push(1); lk.push(2); lk.push(3);
    let mut lv: Vec<f64> = Vec::new();
    lv.push(10.0); lv.push(20.0); lv.push(30.0);
    let left: FrameI64F64 = frame_i64_f64_from_vec("k", "lv", lk, lv);

    let mut rk: Vec<i64> = Vec::new();
    rk.push(2); rk.push(3); rk.push(4);
    let mut rv: Vec<f64> = Vec::new();
    rv.push(200.0); rv.push(300.0); rv.push(400.0);
    let right: FrameI64F64 = frame_i64_f64_from_vec("k", "rv", rk, rv);

    let joined: JoinedI64F64F64 = frame_i64_f64_inner_join(&left, &right);
    if joined.rows != 2 { print("FAIL join rows"); fail = fail + 1; };
    if vec_get(joined.keys, 0) != 2 { print("FAIL join key 0"); fail = fail + 1; };
    if vec_get(joined.keys, 1) != 3 { print("FAIL join key 1"); fail = fail + 1; };
    if close_f64(vec_get(joined.left_values, 0), 20.0, eps) != 1 { print("FAIL join lv 0"); fail = fail + 1; };
    if close_f64(vec_get(joined.right_values, 0), 200.0, eps) != 1 { print("FAIL join rv 0"); fail = fail + 1; };
    if close_f64(vec_get(joined.left_values, 1), 30.0, eps) != 1 { print("FAIL join lv 1"); fail = fail + 1; };
    if close_f64(vec_get(joined.right_values, 1), 300.0, eps) != 1 { print("FAIL join rv 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_pandas_inner_join_f64"); return 0; };
    print("FAIL ml_recover_pandas_inner_join_f64");
    return 1;
}
