import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_broadcast_add_f64",
        "numpy broadcasting",
        "nuc::tensor::broadcast_add_row",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0); ad.push(3.0);
    ad.push(4.0); ad.push(5.0); ad.push(6.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    let mut rd: Vec<f64> = Vec::new();
    rd.push(10.0); rd.push(20.0); rd.push(30.0);
    let row: TensorF64 = tensor_f64_from_vec(1, 3, rd);

    let c: TensorF64 = tensor_f64_broadcast_add_row(&a, &row);
    tensor_f64_print_metadata("result metadata:", &c);
    tensor_f64_print_flat("result flat:", &c);
    return 0;
}
