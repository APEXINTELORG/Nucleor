import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_rms_norm_f64",
        "torch RMSNorm formula over f64 tensors",
        "nuc::nn::rms_norm_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(3.0); xd.push(4.0);
    xd.push(-1.0); xd.push(0.5); xd.push(2.0); xd.push(5.0);
    let input: TensorF64 = tensor_f64_from_vec(2, 4, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.0); wd.push(0.5); wd.push(-1.0); wd.push(2.0);
    let weight: TensorF64 = tensor_f64_from_vec(1, 4, wd);

    let output: TensorF64 = nn_rms_norm_f64(&input, &weight, 0.00001);
    tensor_f64_print_flat("rms norm:", &output);
    return 0;
}
