import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_div_pow_f64",
        "numpy divide power",
        "nuc::tensor::div_powi",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<f64> = Vec::new();
    ad.push(2.0); ad.push(4.0); ad.push(6.0);
    ad.push(8.0); ad.push(10.0); ad.push(12.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(1.0); bd.push(2.0); bd.push(3.0);
    bd.push(4.0); bd.push(5.0); bd.push(6.0);
    let b: TensorF64 = tensor_f64_from_vec(2, 3, bd);

    let d: TensorF64 = tensor_f64_div(&a, &b);
    let p: TensorF64 = tensor_f64_powi(&b, 2);
    tensor_f64_print_flat("divide result:", &d);
    tensor_f64_print_flat("power result:", &p);
    return 0;
}
