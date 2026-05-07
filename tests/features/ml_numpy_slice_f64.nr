import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_slice_f64",
        "numpy slicing",
        "nuc::tensor::slice",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0); ad.push(3.0);
    ad.push(4.0); ad.push(5.0); ad.push(6.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    let s: TensorF64 = tensor_f64_slice(&a, 0, 2, 1, 3);
    tensor_f64_print_metadata("result metadata:", &s);
    tensor_f64_print_flat("slice result:", &s);
    return 0;
}
