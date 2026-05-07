import "stdlib/rods/ml/tensor_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "numpy_matvec_f64_f32",
        "numpy matvec",
        "nuc::tensor::matvec",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ad: Vec<f64> = Vec::new();
    ad.push(1.0); ad.push(2.0); ad.push(3.0);
    ad.push(4.0); ad.push(5.0); ad.push(6.0);
    let a: TensorF64 = tensor_f64_from_vec(2, 3, ad);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(10.0); xd.push(20.0); xd.push(30.0);
    let x: TensorF64 = tensor_f64_from_vec(3, 1, xd);

    let y: TensorF64 = tensor_f64_matvec(&a, &x);
    tensor_f64_print_flat("f64 matvec result:", &y);

    let mut fd: Vec<i64> = Vec::new();
    fd.push(f32_from_int(1)); fd.push(f32_from_int(2)); fd.push(f32_from_int(3));
    fd.push(f32_from_int(4)); fd.push(f32_from_int(5)); fd.push(f32_from_int(6));
    let fa: TensorF32 = tensor_f32_from_vec(2, 3, fd);

    let mut fxd: Vec<i64> = Vec::new();
    fxd.push(f32_from_int(10)); fxd.push(f32_from_int(20)); fxd.push(f32_from_int(30));
    let fx: TensorF32 = tensor_f32_from_vec(3, 1, fxd);

    let fy: TensorF32 = tensor_f32_matvec(&fa, &fx);
    tensor_f32_print_flat("f32 matvec result:", &fy);
    return 0;
}
