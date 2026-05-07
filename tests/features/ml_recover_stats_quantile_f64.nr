import "stdlib/rods/ml/stats_facade.nr"

// ml_recover_stats_quantile_f64 — scalar quantile, median, IQR.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    // Sorted [1, 2, 3, 4, 5, 6, 7, 8, 9].
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(3.0); xd.push(4.0); xd.push(5.0);
    xd.push(6.0); xd.push(7.0); xd.push(8.0); xd.push(9.0);
    let x: TensorF64 = tensor_f64_from_vec(9, 1, xd);

    // Median = 5.
    if close_f64(stats_median_f64(&x), 5.0, eps) != 1 { print("FAIL median"); fail = fail + 1; };

    // q25 ≈ 3.0, q75 ≈ 7.0; IQR = 4.0.
    let iqr: f64 = stats_iqr_f64(&x);
    if close_f64(iqr, 4.0, eps) != 1 { print("FAIL iqr"); fail = fail + 1; };

    // q50 = median.
    if close_f64(stats_quantile_f64(&x, 0.5), 5.0, eps) != 1 { print("FAIL q50"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_stats_quantile_f64"); return 0; };
    print("FAIL ml_recover_stats_quantile_f64");
    return 1;
}
