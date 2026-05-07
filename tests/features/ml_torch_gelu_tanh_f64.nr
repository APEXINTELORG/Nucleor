import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_gelu_tanh_f64",
        "torch.nn.functional.gelu approximate=tanh backward",
        "nuc::nn::gelu_tanh_f64 + backward_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(-2.0); xd.push(-0.5); xd.push(0.0); xd.push(0.5);
    xd.push(1.0); xd.push(2.0); xd.push(-1.5); xd.push(3.0);
    let input: TensorF64 = tensor_f64_from_vec(2, 4, xd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(0.25); gd.push(-1.0); gd.push(0.5); gd.push(1.5);
    gd.push(-0.75); gd.push(2.0); gd.push(0.1); gd.push(-0.2);
    let grad_output: TensorF64 = tensor_f64_from_vec(2, 4, gd);

    let output: TensorF64 = nn_gelu_tanh_f64(&input);
    let grad: TensorF64 = nn_gelu_tanh_backward_f64(&input, &grad_output);
    tensor_f64_print_flat("gelu tanh:", &output);
    tensor_f64_print_flat("grad input:", &grad);
    return 0;
}
