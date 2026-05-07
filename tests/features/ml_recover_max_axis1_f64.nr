import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_max_axis1_f64 — single-pass max over axis 1.

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
    ad.push(1.0); ad.push(5.0); ad.push(2.0);
    ad.push(7.0); ad.push(4.0); ad.push(3.0);
    ad.push(6.0); ad.push(8.0); ad.push(9.0);
    let a: TensorF64 = tensor_f64_from_vec(3, 3, ad);

    let m: TensorF64 = tensor_f64_max_axis1(&a);
    if m.shape.rows != 3 { print("FAIL max rows"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&m, 0, 0), 5.0, eps) != 1 { print("FAIL max 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&m, 1, 0), 7.0, eps) != 1 { print("FAIL max 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&m, 2, 0), 9.0, eps) != 1 { print("FAIL max 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_max_axis1_f64"); return 0; };
    print("FAIL ml_recover_max_axis1_f64");
    return 1;
}
