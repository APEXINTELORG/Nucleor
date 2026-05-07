import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_mse_loss_f64",
        "torch.nn.functional.mse_loss",
        "nuc::nn::mse_loss_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut pd: Vec<f64> = Vec::new();
    pd.push(1.0); pd.push(2.0); pd.push(3.0);
    pd.push(4.0); pd.push(5.0); pd.push(6.0);
    let pred: TensorF64 = tensor_f64_from_vec(2, 3, pd);

    let mut td: Vec<f64> = Vec::new();
    td.push(1.5); td.push(1.0); td.push(2.5);
    td.push(4.5); td.push(4.0); td.push(7.0);
    let target: TensorF64 = tensor_f64_from_vec(2, 3, td);

    print_f64(nn_mse_loss_f64(&pred, &target));
    return 0;
}
