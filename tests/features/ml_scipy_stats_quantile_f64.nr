import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "scipy_stats_quantile_f64",
        "SciPy NumPy sorted quantile median IQR statistics",
        "nuc::stats::quantile_median_iqr",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        6,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(11.0);
    xd.push(1.0);
    xd.push(7.0);
    xd.push(16.0);
    xd.push(2.0);
    xd.push(4.0);
    let x: TensorF64 = tensor_f64_from_vec(6, 1, xd);

    let sorted: TensorF64 = stats_sorted_values_f64(&x);
    tensor_f64_print_flat("sorted values:", &sorted);

    print("quantile results:");
    print_f64(stats_quantile_f64(&x, 0.25));
    print_f64(stats_median_f64(&x));
    print_f64(stats_quantile_f64(&x, 0.75));
    print_f64(stats_iqr_f64(&x));
    return 0;
}
