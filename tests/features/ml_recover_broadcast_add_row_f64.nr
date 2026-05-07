import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_broadcast_add_row_f64 — add a (1, C) row to every row of
// an (R, C) tensor.

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

    let mut rd: Vec<f64> = Vec::new();
    rd.push(10.0); rd.push(20.0); rd.push(30.0);
    let row: TensorF64 = tensor_f64_from_vec(1, 3, rd);

    let b: TensorF64 = tensor_f64_broadcast_add_row(&a, &row);
    if close_f64(tensor_f64_at(&b, 0, 0), 11.0, eps) != 1 { print("FAIL b 0,0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&b, 0, 2), 33.0, eps) != 1 { print("FAIL b 0,2"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&b, 1, 1), 25.0, eps) != 1 { print("FAIL b 1,1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&b, 1, 2), 36.0, eps) != 1 { print("FAIL b 1,2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_broadcast_add_row_f64"); return 0; };
    print("FAIL ml_recover_broadcast_add_row_f64");
    return 1;
}
