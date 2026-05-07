import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_onehot_encoder_i64",
        "scikit-learn OneHotEncoder handle_unknown ignore transform",
        "nuc::learn::one_hot_encoder_i64_transform",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut category_data: Vec<i64> = Vec::new();
    category_data.push(0); category_data.push(1); category_data.push(2);
    let categories: TensorI64 = tensor_i64_from_vec(3, 1, category_data);

    let mut xd: Vec<i64> = Vec::new();
    xd.push(0);
    xd.push(2);
    xd.push(1);
    xd.push(9);
    let x: TensorI64 = tensor_i64_from_vec(4, 1, xd);

    let encoder: OneHotEncoderI64 = one_hot_encoder_i64(categories);
    let transformed: TensorF64 = one_hot_encoder_i64_transform(&encoder, &x);
    tensor_f64_print_flat("onehot transform:", &transformed);
    return 0;
}
