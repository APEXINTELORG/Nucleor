import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_matmul_f32",
        "numpy.matmul",
        "nuc::tensor::matmul",
        dtype_f32(),
        dtype_default_accumulator(dtype_f32()),
        policy_strict(),
        2,
        2,
        0.0001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<i64> = Vec::new();
    ad.push(f32_from_int(1)); ad.push(f32_from_int(2));
    ad.push(f32_from_int(3)); ad.push(f32_from_int(4));
    let a: TensorF32 = tensor_f32_from_vec(2, 2, ad);

    let mut bd: Vec<i64> = Vec::new();
    bd.push(f32_from_int(5)); bd.push(f32_from_int(6));
    bd.push(f32_from_int(7)); bd.push(f32_from_int(8));
    let b: TensorF32 = tensor_f32_from_vec(2, 2, bd);

    let c: TensorF32 = tensor_f32_matmul(&a, &b);
    tensor_f32_print_metadata("result metadata:", &c);
    tensor_f32_print_flat("result flat:", &c);
    return 0;
}
