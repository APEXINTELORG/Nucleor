import "stdlib/rods/ml/stats_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "scipy_stats_ttest_f64",
        "SciPy one-sample and Welch t-test statistics with Student-t p-values",
        "nuc::stats::ttest",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        5,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(2.0);
    xd.push(4.0);
    xd.push(6.0);
    xd.push(8.0);
    xd.push(10.0);
    let x: TensorF64 = tensor_f64_from_vec(5, 1, xd);

    let mut yd: Vec<f64> = Vec::new();
    yd.push(1.0);
    yd.push(3.0);
    yd.push(5.0);
    yd.push(7.0);
    yd.push(9.0);
    let y: TensorF64 = tensor_f64_from_vec(5, 1, yd);

    let one: StatsTestResultF64 = stats_ttest_1samp_f64(&x, 5.0);
    print("one-sample statistic:");
    print_f64(one.statistic);
    print("one-sample pvalue:");
    print_f64(one.pvalue_two_sided);
    print("one-sample df:");
    print_f64(one.df);

    let welch: StatsTestResultF64 = stats_welch_ttest_f64(&x, &y);
    print("welch statistic:");
    print_f64(welch.statistic);
    print("welch pvalue:");
    print_f64(welch.pvalue_two_sided);
    print("welch df:");
    print_f64(welch.df);
    return 0;
}
