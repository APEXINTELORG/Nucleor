import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_normalizer_l2_f64",
        "scikit-learn Normalizer norm l2 transform",
        "nuc::learn::normalizer_l2_f64_transform",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut x_data: Vec<f64> = Vec::new();
    x_data.push(3.0); x_data.push(4.0); x_data.push(0.0);
    x_data.push(1.0); x_data.push(2.0); x_data.push(2.0);
    x_data.push(0.0); x_data.push(0.0); x_data.push(0.0);
    x_data.push(-2.0); x_data.push(0.0); x_data.push(2.0);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, x_data);

    let normalized: TensorF64 = normalizer_l2_f64_transform(&x);
    tensor_f64_print_flat("normalizer l2 transform:", &normalized);
    return 0;
}
