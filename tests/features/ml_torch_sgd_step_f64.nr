import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_sgd_step_f64",
        "torch.optim.SGD step",
        "nuc::nn::sgd_step_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut pd: Vec<f64> = Vec::new();
    pd.push(1.0); pd.push(-2.0); pd.push(3.0);
    pd.push(4.0); pd.push(-5.0); pd.push(6.0);
    let param: TensorF64 = tensor_f64_from_vec(2, 3, pd);

    let mut gd: Vec<f64> = Vec::new();
    gd.push(0.1); gd.push(-0.2); gd.push(0.3);
    gd.push(-0.4); gd.push(0.5); gd.push(-0.6);
    let grad: TensorF64 = tensor_f64_from_vec(2, 3, gd);

    let updated: TensorF64 = nn_sgd_step_f64(&param, &grad, 0.1);
    tensor_f64_print_flat("updated parameter:", &updated);
    return 0;
}
