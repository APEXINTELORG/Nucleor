import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_binarizer_threshold_f64",
        "scikit-learn Binarizer threshold transform",
        "nuc::learn::binarizer_f64_transform",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut x_data: Vec<f64> = Vec::new();
    x_data.push(-1.0); x_data.push(0.0); x_data.push(0.5);
    x_data.push(0.5000001); x_data.push(0.75); x_data.push(2.0);
    x_data.push(-0.25); x_data.push(0.5); x_data.push(1.5);
    x_data.push(10.0); x_data.push(-3.0); x_data.push(0.51);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, x_data);

    let transformed: TensorF64 = binarizer_f64_transform(&x, 0.5);
    tensor_f64_print_flat("binarizer threshold transform:", &transformed);
    return 0;
}
