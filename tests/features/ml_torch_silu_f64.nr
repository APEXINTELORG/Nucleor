import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_silu_f64",
        "torch.nn.functional.silu forward",
        "nuc::nn::silu_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        2,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(-1.75); xd.push(2.0);
    xd.push(-1.75); xd.push(6.5);
    let input: TensorF64 = tensor_f64_from_vec(2, 2, xd);
    let output: TensorF64 = nn_silu_f64(&input);
    tensor_f64_print_flat("silu:", &output);
    return 0;
}
