import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_linear_backward_f64",
        "torch.nn.functional.linear backward",
        "nuc::nn::linear_backward_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut xd: Vec<f64> = Vec::new();
    xd.push(1.0); xd.push(2.0); xd.push(3.0);
    xd.push(4.0); xd.push(5.0); xd.push(6.0);
    let x: TensorF64 = tensor_f64_from_vec(2, 3, xd);

    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.0); wd.push(0.0); wd.push(-1.0);
    wd.push(0.5); wd.push(0.5); wd.push(0.5);
    let weight: TensorF64 = tensor_f64_from_vec(2, 3, wd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(1.0); gd.push(-0.5);
    gd.push(0.25); gd.push(2.0);
    let grad_output: TensorF64 = tensor_f64_from_vec(2, 2, gd);

    let backward: LinearBackwardF64 = nn_linear_backward_f64(&x, &weight, &grad_output);
    tensor_f64_print_flat("grad input:", &backward.grad_input);
    tensor_f64_print_flat("grad weight:", &backward.grad_weight);
    tensor_f64_print_flat("grad bias:", &backward.grad_bias);
    return 0;
}
