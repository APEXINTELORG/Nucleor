import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_matmul_f64",
        "numpy.matmul",
        "nuc::tensor::matmul",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0);
    ad.push(3.0); ad.push(4.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 2, ad);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(5.0); bd.push(6.0);
    bd.push(7.0); bd.push(8.0);
    let b: TensorF64 = tensor_f64_from_vec(2, 2, bd);

    let c: TensorF64 = tensor_f64_matmul(&a, &b);
    tensor_f64_print_metadata("result metadata:", &c);
    tensor_f64_print_flat("result flat:", &c);
    return 0;
}
