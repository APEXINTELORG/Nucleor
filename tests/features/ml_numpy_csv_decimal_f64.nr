import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_csv_decimal_f64",
        "numpy.loadtxt decimal f64",
        "nuc::tensor::from_csv_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let t: TensorF64 = tensor_f64_from_csv_f64("tests/features/ml_fixtures/tensor_2x3_f64.csv", 2, 3, 1);
    tensor_f64_print_metadata("result metadata:", &t);
    tensor_f64_print_flat("csv tensor result:", &t);
    print("mean result:");
    print_f64(tensor_f64_mean(&t));
    return 0;
}
