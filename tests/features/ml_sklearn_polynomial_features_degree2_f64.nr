import "stdlib/rods/ml/learn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "sklearn_polynomial_features_degree2_f64",
        "scikit-learn PolynomialFeatures degree=2 include_bias=True transform",
        "nuc::learn::polynomial_features_degree2_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(-1.0);
    xd.push(0.5); xd.push(-0.5); xd.push(2.0);
    xd.push(3.0); xd.push(0.0); xd.push(1.0);
    let x: TensorF64 = tensor_f64_from_vec(3, 3, xd);

    let transformed: TensorF64 = polynomial_features_degree2_f64(&x, 1);
    tensor_f64_print_flat("polynomial degree2 features:", &transformed);
    return 0;
}
