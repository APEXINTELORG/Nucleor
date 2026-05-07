import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "scipy_stats_rank_extrema_f64",
        "SciPy NumPy extrema arg extrema and average rank statistics",
        "nuc::stats::rank_extrema",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        6,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(20.0);
    xd.push(10.0);
    xd.push(20.0);
    xd.push(30.0);
    xd.push(10.0);
    xd.push(25.0);
    let x: TensorF64 = tensor_f64_from_vec(6, 1, xd);

    print("extrema results:");
    print_f64(stats_min_f64(&x));
    print_f64(stats_max_f64(&x));
    print_f64(stats_range_f64(&x));
    print_int(stats_argmin_i64(&x));
    print_int(stats_argmax_i64(&x));

    let ranks: TensorF64 = stats_rankdata_average_f64(&x);
    tensor_f64_print_flat("average ranks:", &ranks);
    return 0;
}
