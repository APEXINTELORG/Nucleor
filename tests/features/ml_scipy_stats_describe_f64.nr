import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "scipy_stats_describe_f64",
        "SciPy NumPy descriptive statistics covariance Pearson zscore",
        "nuc::stats::describe_cov_pearson_zscore",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(4.0);
    xd.push(7.0); xd.push(11.0); xd.push(16.0);
    let x: TensorF64 = tensor_f64_from_vec(2, 3, xd);

    let mut yd: Vec<f64> = Vec::new();
    yd.push(2.0); yd.push(1.0); yd.push(5.0);
    yd.push(6.0); yd.push(13.0); yd.push(15.0);
    let y: TensorF64 = tensor_f64_from_vec(2, 3, yd);

    print("stats scalar results:");
    print_f64(stats_mean_f64(&x));
    print_f64(stats_variance_f64(&x, 0));
    print_f64(stats_variance_f64(&x, 1));
    print_f64(stats_std_f64(&x, 0));
    print_f64(stats_covariance_f64(&x, &y, 0));
    print_f64(stats_covariance_f64(&x, &y, 1));
    print_f64(stats_pearsonr_f64(&x, &y));

    let z: TensorF64 = stats_zscore_f64(&x, 0);
    tensor_f64_print_flat("zscore result:", &z);
    return 0;
}
