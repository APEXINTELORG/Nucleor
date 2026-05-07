import "stdlib/rods/ml/stats_facade.nr"

// ml_recover_stats_covariance_f64 — scalar covariance + Pearson r.
// y = 2x + 1 (perfect positive linear): r = 1, cov > 0.

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
    xd.push(1.0); xd.push(2.0); xd.push(3.0); xd.push(4.0); xd.push(5.0);
    let x: TensorF64 = tensor_f64_from_vec(5, 1, xd);

    let mut yd: Vec<f64> = Vec::new();
    yd.push(3.0); yd.push(5.0); yd.push(7.0); yd.push(9.0); yd.push(11.0);
    let y: TensorF64 = tensor_f64_from_vec(5, 1, yd);

    // Pearson r = +1.
    if close_f64(stats_pearsonr_f64(&x, &y), 1.0, eps) != 1 { print("FAIL pearson"); fail = fail + 1; };

    // Cov(x,y) with ddof=1: positive and large.
    let cov: f64 = stats_covariance_f64(&x, &y, 1);
    if cov < 4.0 { print("FAIL cov low"); fail = fail + 1; };
    if cov > 6.0 { print("FAIL cov high"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_stats_covariance_f64"); return 0; };
    print("FAIL ml_recover_stats_covariance_f64");
    return 1;
}
