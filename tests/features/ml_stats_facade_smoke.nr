import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_stats_facade_smoke — exercises descriptive statistics from
// stdlib/rods/ml/stats_facade.nr: mean, variance (ddof=0 and ddof=1),
// std, Pearson correlation. Self-contained. Deeper SciPy parity
// (rankdata, t-test exact p-values, normal CDF) lives in subsequent
// batches.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // x = [1, 2, 3, 4, 5] -> mean=3.0, var(ddof=0)=2.0, var(ddof=1)=2.5, std(ddof=0)=sqrt(2)
    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(3.0); xd.push(4.0); xd.push(5.0);
    let x: TensorF64 = tensor_f64_from_vec(5, 1, xd);

    if close_f64(stats_mean_f64(&x), 3.0, eps) != 1 { print("FAIL mean"); fail = fail + 1; };
    if close_f64(stats_variance_f64(&x, 0), 2.0, eps) != 1 { print("FAIL var ddof0"); fail = fail + 1; };
    if close_f64(stats_variance_f64(&x, 1), 2.5, eps) != 1 { print("FAIL var ddof1"); fail = fail + 1; };

    let std0: f64 = stats_std_f64(&x, 0);
    if close_f64(std0 * std0, 2.0, eps) != 1 { print("FAIL std ddof0 sq"); fail = fail + 1; };

    // Perfectly correlated y = 2x + 1 -> Pearson r = 1.0
    let mut yd: Vec<f64> = Vec::new();
    yd.push(3.0); yd.push(5.0); yd.push(7.0); yd.push(9.0); yd.push(11.0);
    let y: TensorF64 = tensor_f64_from_vec(5, 1, yd);

    if close_f64(stats_pearsonr_f64(&x, &y), 1.0, eps) != 1 { print("FAIL pearsonr +1"); fail = fail + 1; };

    // Anti-correlated z = -x -> r = -1.0
    let mut zd: Vec<f64> = Vec::new();
    zd.push(0.0 - 1.0); zd.push(0.0 - 2.0); zd.push(0.0 - 3.0); zd.push(0.0 - 4.0); zd.push(0.0 - 5.0);
    let z: TensorF64 = tensor_f64_from_vec(5, 1, zd);

    if close_f64(stats_pearsonr_f64(&x, &z), 0.0 - 1.0, eps) != 1 { print("FAIL pearsonr -1"); fail = fail + 1; };

    let manifest: ParityManifest = parity_manifest(
        "ml_stats_facade_smoke",
        "internal",
        "stdlib::rods::ml::stats_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        1,
        eps
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_stats_facade_smoke");
        return 0;
    };
    print("FAIL ml_stats_facade_smoke");
    return 1;
}
