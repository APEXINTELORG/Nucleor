import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_transpose_f64 — single-pass transpose.

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

    let t: TensorF64 = tensor_f64_transpose(&a);
    if t.shape.rows != 3 { print("FAIL t rows"); fail = fail + 1; };
    if t.shape.cols != 2 { print("FAIL t cols"); fail = fail + 1; };
    // Original (0,0)=1 → transposed (0,0)=1; (0,2)=3 → (2,0)=3; (1,2)=6 → (2,1)=6.
    if close_f64(tensor_f64_at(&t, 0, 0), 1.0, eps) != 1 { print("FAIL t 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 2, 0), 3.0, eps) != 1 { print("FAIL t 2,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 2, 1), 6.0, eps) != 1 { print("FAIL t 2,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&t, 0, 1), 4.0, eps) != 1 { print("FAIL t 0,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_transpose_f64"); return 0; };
    print("FAIL ml_recover_tensor_transpose_f64");
    return 1;
}
