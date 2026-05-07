import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_div_f64 — pointwise division.

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
    ad.push(10.0); ad.push(20.0);
    ad.push(30.0); ad.push(40.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 2, ad);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(2.0); bd.push(4.0);
    bd.push(5.0); bd.push(8.0);
    let b: TensorF64 = tensor_f64_from_vec(2, 2, bd);

    let q: TensorF64 = tensor_f64_div(&a, &b);
    if close_f64(tensor_f64_at(&q, 0, 0), 5.0, eps) != 1 { print("FAIL q 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&q, 0, 1), 5.0, eps) != 1 { print("FAIL q 0,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&q, 1, 0), 6.0, eps) != 1 { print("FAIL q 1,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&q, 1, 1), 5.0, eps) != 1 { print("FAIL q 1,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_div_f64"); return 0; };
    print("FAIL ml_recover_tensor_div_f64");
    return 1;
}
