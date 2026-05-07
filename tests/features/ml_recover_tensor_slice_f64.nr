import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_slice_f64 — 2D slice.

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
    ad.push(7.0); ad.push(8.0); ad.push(9.0);
    let a: TensorF64 = tensor_f64_from_vec(3, 3, ad);

    // slice rows [0..2), cols [1..3) → 2x2 = [[2,3],[5,6]].
    let s: TensorF64 = tensor_f64_slice(&a, 0, 2, 1, 3);
    if s.shape.rows != 2 { print("FAIL s rows"); fail = fail + 1; };
    if s.shape.cols != 2 { print("FAIL s cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 0, 0), 2.0, eps) != 1 { print("FAIL s 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 0, 1), 3.0, eps) != 1 { print("FAIL s 0,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 1, 0), 5.0, eps) != 1 { print("FAIL s 1,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 1, 1), 6.0, eps) != 1 { print("FAIL s 1,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_slice_f64"); return 0; };
    print("FAIL ml_recover_tensor_slice_f64");
    return 1;
}
