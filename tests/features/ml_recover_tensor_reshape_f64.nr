import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_reshape_f64 — single-pass reshape preserves data
// (row-major).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0); ad.push(3.0);
    ad.push(4.0); ad.push(5.0); ad.push(6.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    // reshape 2x3 → 3x2: data flat [1,2,3,4,5,6] → rows [1,2], [3,4], [5,6].
    let r: TensorF64 = tensor_f64_reshape(&a, 3, 2);
    if r.shape.rows != 3 { print("FAIL r rows"); fail = fail + 1; };
    if r.shape.cols != 2 { print("FAIL r cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 0, 0), 1.0, eps) != 1 { print("FAIL r 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 0, 1), 2.0, eps) != 1 { print("FAIL r 0,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 1, 0), 3.0, eps) != 1 { print("FAIL r 1,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 2, 1), 6.0, eps) != 1 { print("FAIL r 2,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_reshape_f64"); return 0; };
    print("FAIL ml_recover_tensor_reshape_f64");
    return 1;
}
