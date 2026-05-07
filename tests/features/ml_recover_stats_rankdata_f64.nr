import "stdlib/rods/ml/stats_facade.nr"

// ml_recover_stats_rankdata_f64 — scipy-style average ranking with ties.
// values [3, 1, 4, 1, 5] → ranks [3, 1.5, 4, 1.5, 5].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.0001;

    let mut xd: Vec<f64> = Vec::new();
    xd.push(3.0); xd.push(1.0); xd.push(4.0); xd.push(1.0); xd.push(5.0);
    let x: TensorF64 = tensor_f64_from_vec(5, 1, xd);

    let r: TensorF64 = stats_rankdata_average_f64(&x);
    if r.shape.rows != 5 { print("FAIL r rows"); fail = fail + 1; };
    // rank(3) = 3, rank(1) = (1+2)/2 = 1.5, rank(4) = 4, rank(5) = 5.
    if close_f64(tensor_f64_at(&r, 0, 0), 3.0, eps) != 1 { print("FAIL r 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 1, 0), 1.5, eps) != 1 { print("FAIL r 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 2, 0), 4.0, eps) != 1 { print("FAIL r 2"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 3, 0), 1.5, eps) != 1 { print("FAIL r 3"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&r, 4, 0), 5.0, eps) != 1 { print("FAIL r 4"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_stats_rankdata_f64"); return 0; };
    print("FAIL ml_recover_stats_rankdata_f64");
    return 1;
}
