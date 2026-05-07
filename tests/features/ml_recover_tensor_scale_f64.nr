import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_scale_f64 — pointwise scalar multiply.

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
    ad.push(1.0); ad.push(2.0);
    ad.push(3.0); ad.push(4.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 2, ad);

    let s: TensorF64 = tensor_f64_scale(&a, 2.5);
    if close_f64(tensor_f64_at(&s, 0, 0), 2.5, eps) != 1 { print("FAIL s 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&s, 1, 1), 10.0, eps) != 1 { print("FAIL s 1,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_scale_f64"); return 0; };
    print("FAIL ml_recover_tensor_scale_f64");
    return 1;
}
