import "stdlib/rods/ml/nn_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_bce_with_logits_f64",
        "torch.nn.functional.binary_cross_entropy_with_logits",
        "nuc::nn::bce_with_logits_loss_f64 + backward_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ld: Vec<f64> = Vec::new();
    ld.push(-2.0); ld.push(0.0); ld.push(2.0);
    ld.push(1.5); ld.push(-0.5); ld.push(3.0);
    let logits: TensorF64 = tensor_f64_from_vec(2, 3, ld);

    let mut td: Vec<f64> = Vec::new();
    td.push(0.0); td.push(1.0); td.push(1.0);
    td.push(1.0); td.push(0.0); td.push(0.0);
    let target: TensorF64 = tensor_f64_from_vec(2, 3, td);

    let sigmoid: TensorF64 = nn_sigmoid_f64(&logits);
    let grad: TensorF64 = nn_bce_with_logits_backward_f64(&logits, &target);
    tensor_f64_print_flat("sigmoid:", &sigmoid);
    print_f64(nn_bce_with_logits_loss_f64(&logits, &target));
    tensor_f64_print_flat("grad logits:", &grad);
    return 0;
}
