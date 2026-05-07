import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_select_rows_f64 — gather rows by indices.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // 4 rows × 2 cols
    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0);
    ad.push(3.0); ad.push(4.0);
    ad.push(5.0); ad.push(6.0);
    ad.push(7.0); ad.push(8.0);
    let a: TensorF64 = tensor_f64_from_vec(4, 2, ad);

    // Pick rows [3, 0, 2] → produces 3x2 = [[7,8],[1,2],[5,6]].
    let mut id: Vec<i64> = Vec::new();
    id.push(3); id.push(0); id.push(2);
    let indices: TensorI64 = tensor_i64_from_vec(3, 1, id);

    let r: TensorF64 = tensor_f64_select_rows(&a, &indices);
    if r.shape.rows != 3 { print("FAIL r rows"); fail = fail + 1; };
    if r.shape.cols != 2 { print("FAIL r cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 0, 0), 7.0, eps) != 1 { print("FAIL r 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 1, 1), 2.0, eps) != 1 { print("FAIL r 1,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 2, 0), 5.0, eps) != 1 { print("FAIL r 2,0"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_select_rows_f64"); return 0; };
    print("FAIL ml_recover_tensor_select_rows_f64");
    return 1;
}
