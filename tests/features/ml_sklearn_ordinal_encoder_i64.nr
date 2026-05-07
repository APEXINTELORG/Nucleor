import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_ordinal_encoder_i64",
        "scikit-learn OrdinalEncoder handle_unknown use_encoded_value transform",
        "nuc::learn::ordinal_encoder_i64_transform",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        4,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut category_data: Vec<i64> = Vec::new();
    category_data.push(10); category_data.push(20); category_data.push(30);
    let categories: TensorI64 = tensor_i64_from_vec(3, 1, category_data);

    let mut xd: Vec<i64> = Vec::new();
    xd.push(20);
    xd.push(10);
    xd.push(99);
    xd.push(30);
    let x: TensorI64 = tensor_i64_from_vec(4, 1, xd);

    let encoder: OrdinalEncoderI64 = ordinal_encoder_i64(categories, -1);
    let transformed: TensorI64 = ordinal_encoder_i64_transform(&encoder, &x);
    tensor_i64_print_flat("ordinal transform:", &transformed);
    return 0;
}
