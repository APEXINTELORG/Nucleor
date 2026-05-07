import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_nll_loss_f64",
        "torch.nn.functional.nll_loss",
        "nuc::nn::nll_loss_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ld: Vec<f64> = Vec::new();
    ld.push(-0.2); ld.push(-1.7); ld.push(-2.3);
    ld.push(-2.0); ld.push(-0.4); ld.push(-1.5);
    ld.push(-1.2); ld.push(-2.2); ld.push(-0.3);
    let log_probs: TensorF64 = tensor_f64_from_vec(3, 3, ld);

    let mut td: Vec<i64> = Vec::new();
    td.push(0); td.push(1); td.push(2);
    let target: TensorI64 = tensor_i64_from_vec(3, 1, td);

    print_f64(nn_nll_loss_f64(&log_probs, &target));
    return 0;
}
