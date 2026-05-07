import "stdlib/rods/ml/ai_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_last_token_i64",
        "torch batched token ids last-column slice",
        "nuc::ai::last_token_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        1,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ids: Vec<i64> = Vec::new();
    ids.push(2); ids.push(0); ids.push(1); ids.push(4);
    ids.push(0); ids.push(3); ids.push(2); ids.push(1);
    ids.push(4); ids.push(1); ids.push(0); ids.push(3);
    let token_ids: TensorI64 = tensor_i64_from_vec(3, 4, ids);

    let last_tokens: TensorI64 = ai_last_token_i64(&token_ids);
    tensor_i64_print_flat("last tokens:", &last_tokens);
    return 0;
}
