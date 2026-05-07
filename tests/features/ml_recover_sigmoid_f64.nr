import "stdlib/rods/ml/nn_facade.nr"

// ml_recover_sigmoid_f64 — minimal sigmoid forward.
// sigmoid(0) = 0.5, sigmoid(large) ≈ 1, sigmoid(-large) ≈ 0.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.0); xd.push(10.0); xd.push(0.0 - 10.0);
    let x: TensorF64 = tensor_f64_from_vec(1, 3, xd);

    let s: TensorF64 = nn_sigmoid_f64(&x);
    if close_f64(tensor_f64_at(&s, 0, 0), 0.5, eps) != 1 { print("FAIL sig 0"); fail = fail + 1; };
    if tensor_f64_at(&s, 0, 1) < 0.999 { print("FAIL sig +10"); fail = fail + 1; };
    if tensor_f64_at(&s, 0, 2) > 0.001 { print("FAIL sig -10"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_sigmoid_f64"); return 0; };
    print("FAIL ml_recover_sigmoid_f64");
    return 1;
}
