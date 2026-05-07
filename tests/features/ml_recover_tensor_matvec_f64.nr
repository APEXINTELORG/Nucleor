import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_matvec_f64 — tensor matrix-vector product.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // A (2x3) * x (3x1) → y (2x1).
    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0); ad.push(3.0);
    ad.push(4.0); ad.push(5.0); ad.push(6.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(10.0);
    xd.push(20.0);
    xd.push(30.0);
    let x: TensorF64 = tensor_f64_from_vec(3, 1, xd);

    // y[0] = 1*10 + 2*20 + 3*30 = 140
    // y[1] = 4*10 + 5*20 + 6*30 = 320
    let y: TensorF64 = tensor_f64_matvec(&a, &x);
    if y.shape.rows != 2 { print("FAIL y rows"); fail = fail + 1; };
    if y.shape.cols != 1 { print("FAIL y cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&y, 0, 0), 140.0, eps) != 1 { print("FAIL y 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&y, 1, 0), 320.0, eps) != 1 { print("FAIL y 1"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_matvec_f64"); return 0; };
    print("FAIL ml_recover_tensor_matvec_f64");
    return 1;
}
