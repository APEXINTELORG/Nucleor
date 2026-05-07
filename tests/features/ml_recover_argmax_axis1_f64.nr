import "stdlib/rods/ml/tensor_facade.nr"

// ml_recover_argmax_axis1_f64 — single-pass argmax over axis 1.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // 3x3: row 0 max at col 1 (val 5), row 1 max at col 0 (val 7), row 2 max at col 2 (val 9).
    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(5.0); ad.push(2.0);
    ad.push(7.0); ad.push(4.0); ad.push(3.0);
    ad.push(6.0); ad.push(8.0); ad.push(9.0);
    let a: TensorF64 = tensor_f64_from_vec(3, 3, ad);

    let am: TensorI64 = tensor_f64_argmax_axis1(&a);
    if am.shape.rows != 3 { print("FAIL argmax rows"); fail = fail + 1; };
    if tensor_i64_at(&am, 0, 0) != 1 { print("FAIL argmax 0"); fail = fail + 1; };
    if tensor_i64_at(&am, 1, 0) != 0 { print("FAIL argmax 1"); fail = fail + 1; };
    if tensor_i64_at(&am, 2, 0) != 2 { print("FAIL argmax 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_argmax_axis1_f64"); return 0; };
    print("FAIL ml_recover_argmax_axis1_f64");
    return 1;
}
