import "stdlib/rods/ml/stats_facade.nr"

// ml_recover_stats_min_max_f64 — scalar min/max over a tensor.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    let mut xd: Vec<f64> = Vec::new();
    xd.push(3.0); xd.push(1.0); xd.push(4.0); xd.push(1.0); xd.push(5.0); xd.push(9.0); xd.push(2.0);
    let x: TensorF64 = tensor_f64_from_vec(7, 1, xd);

    if close_f64(stats_min_f64(&x), 1.0, eps) != 1 { print("FAIL min"); fail = fail + 1; };
    if close_f64(stats_max_f64(&x), 9.0, eps) != 1 { print("FAIL max"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_stats_min_max_f64"); return 0; };
    print("FAIL ml_recover_stats_min_max_f64");
    return 1;
}
