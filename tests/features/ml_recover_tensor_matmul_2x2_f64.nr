import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_matmul_2x2_f64 — explicit recovery of tensor matmul,
// previously implicit in ML-4 ml_tensor_facade_smoke.

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

    let mut bd: Vec<f64> = Vec::new();
    bd.push(5.0); bd.push(6.0);
    bd.push(7.0); bd.push(8.0);
    let b: TensorF64 = tensor_f64_from_vec(2, 2, bd);

    let c: TensorF64 = tensor_f64_matmul(&a, &b);
    if close_f64(tensor_f64_at(&c, 0, 0), 19.0, eps) != 1 { print("FAIL c 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 0, 1), 22.0, eps) != 1 { print("FAIL c 0,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 1, 0), 43.0, eps) != 1 { print("FAIL c 1,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&c, 1, 1), 50.0, eps) != 1 { print("FAIL c 1,1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_matmul_2x2_f64"); return 0; };
    print("FAIL ml_recover_tensor_matmul_2x2_f64");
    return 1;
}
