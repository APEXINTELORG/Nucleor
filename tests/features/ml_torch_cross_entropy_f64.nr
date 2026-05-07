import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_cross_entropy_f64",
        "torch.nn.functional.log_softmax + cross_entropy",
        "nuc::nn::log_softmax_f64 + cross_entropy_loss_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        3,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ld: Vec<f64> = Vec::new();
    ld.push(2.0); ld.push(0.5); ld.push(-1.0);
    ld.push(0.1); ld.push(1.5); ld.push(2.0);
    ld.push(-1.0); ld.push(3.0); ld.push(0.0);
    let logits: TensorF64 = tensor_f64_from_vec(3, 3, ld);

    let mut td: Vec<i64> = Vec::new();
    td.push(0); td.push(2); td.push(1);
    let target: TensorI64 = tensor_i64_from_vec(3, 1, td);

    let log_probs: TensorF64 = nn_log_softmax_f64(&logits);
    tensor_f64_print_flat("log softmax:", &log_probs);
    print_f64(nn_cross_entropy_loss_f64(&logits, &target));
    return 0;
}
