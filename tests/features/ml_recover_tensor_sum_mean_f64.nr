import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_sum_mean_f64 — scalar reductions over a 2x3 tensor.
// sum = 21, mean = 21/6 = 3.5.

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

    let s: f64 = tensor_f64_sum(&a);
    if close_f64(s, 21.0, eps) != 1 { print("FAIL sum"); fail = fail + 1; };

    let m: f64 = tensor_f64_mean(&a);
    if close_f64(m, 3.5, eps) != 1 { print("FAIL mean"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_sum_mean_f64"); return 0; };
    print("FAIL ml_recover_tensor_sum_mean_f64");
    return 1;
}
