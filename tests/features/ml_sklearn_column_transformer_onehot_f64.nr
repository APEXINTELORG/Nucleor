import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_column_transformer_onehot_f64",
        "scikit-learn ColumnTransformer numeric passthrough plus OneHotEncoder",
        "nuc::learn::column_transformer_numeric_onehot_f64_i64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        5,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut numeric_data: Vec<f64> = Vec::new();
    numeric_data.push(1.5); numeric_data.push(10.0);
    numeric_data.push(2.5); numeric_data.push(20.0);
    numeric_data.push(3.5); numeric_data.push(30.0);
    numeric_data.push(4.5); numeric_data.push(40.0);
    let numeric: TensorF64 = tensor_f64_from_vec(4, 2, numeric_data);

    let mut categorical_data: Vec<i64> = Vec::new();
    categorical_data.push(0);
    categorical_data.push(2);
    categorical_data.push(1);
    categorical_data.push(9);
    let categorical: TensorI64 = tensor_i64_from_vec(4, 1, categorical_data);

    let mut category_data: Vec<i64> = Vec::new();
    category_data.push(0); category_data.push(1); category_data.push(2);
    let categories: TensorI64 = tensor_i64_from_vec(3, 1, category_data);
    let encoder: OneHotEncoderI64 = one_hot_encoder_i64(categories);

    let transformed: TensorF64 = column_transformer_numeric_onehot_f64_i64(&numeric, &categorical, &encoder);
    tensor_f64_print_flat("column transformer onehot:", &transformed);
    return 0;
}
