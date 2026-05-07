import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "scipy_stats_histogram_f64",
        "NumPy SciPy fixed width histogram counts and bin edges",
        "nuc::stats::histogram_fixed_width",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        7,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(0.2);
    xd.push(1.4);
    xd.push(2.9);
    xd.push(3.0);
    xd.push(4.8);
    xd.push(5.0);
    xd.push(5.1);
    let x: TensorF64 = tensor_f64_from_vec(7, 1, xd);

    let hist: StatsHistogramF64 = stats_histogram_fixed_width_f64(&x, 0.0, 5.0, 5);
    tensor_i64_print_flat("histogram counts:", &hist.counts);
    tensor_f64_print_flat("histogram bin edges:", &hist.bin_edges);
    return 0;
}
