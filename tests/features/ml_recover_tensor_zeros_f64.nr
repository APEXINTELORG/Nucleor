import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_tensor_zeros_f64 — zeros constructor only (avoids the
// tensor_f64_full path flagged in ML-35).

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let z: TensorF64 = tensor_f64_zeros(4, 6);
    if z.shape.rows != 4 { print("FAIL z rows"); fail = fail + 1; };
    if z.shape.cols != 6 { print("FAIL z cols"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&z, 0, 0), 0.0, eps) != 1 { print("FAIL z 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&z, 3, 5), 0.0, eps) != 1 { print("FAIL z 3,5"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&z, 1, 2), 0.0, eps) != 1 { print("FAIL z 1,2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_tensor_zeros_f64"); return 0; };
    print("FAIL ml_recover_tensor_zeros_f64");
    return 1;
}
