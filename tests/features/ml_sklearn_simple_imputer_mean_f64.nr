import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_simple_imputer_mean_f64",
        "scikit-learn SimpleImputer strategy mean fit transform",
        "nuc::learn::simple_imputer_mean_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        4,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut x_data: Vec<f64> = Vec::new();
    x_data.push(1.0); x_data.push(2.0); x_data.push(0.0);
    x_data.push(4.0); x_data.push(0.0); x_data.push(6.0);
    x_data.push(7.0); x_data.push(8.0); x_data.push(9.0);
    x_data.push(0.0); x_data.push(11.0); x_data.push(12.0);
    let x: TensorF64 = tensor_f64_from_vec(4, 3, x_data);

    let mut missing_data: Vec<i64> = Vec::new();
    missing_data.push(0); missing_data.push(0); missing_data.push(1);
    missing_data.push(0); missing_data.push(1); missing_data.push(0);
    missing_data.push(0); missing_data.push(0); missing_data.push(0);
    missing_data.push(1); missing_data.push(0); missing_data.push(0);
    let missing_mask: TensorI64 = tensor_i64_from_vec(4, 3, missing_data);

    let imputer: SimpleImputerF64 = simple_imputer_mean_f64_fit(&x, &missing_mask);
    tensor_f64_print_flat("simple imputer statistics:", &imputer.statistics);

    let transformed: TensorF64 = simple_imputer_transform_f64(&imputer, &x, &missing_mask);
    tensor_f64_print_flat("simple imputer transform:", &transformed);
    return 0;
}
