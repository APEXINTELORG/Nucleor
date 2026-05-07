import "stdlib/rods/ml/ai_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_append_next_token_i64",
        "torch.cat batched token ids with one sampled next token per row",
        "nuc::ai::append_next_token_i64",
        dtype_i64(),
        dtype_default_accumulator(dtype_i64()),
        policy_strict(),
        3,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ids: Vec<i64> = Vec::new();
    ids.push(2); ids.push(0); ids.push(1);
    ids.push(0); ids.push(3); ids.push(2);
    ids.push(4); ids.push(1); ids.push(0);
    let token_ids: TensorI64 = tensor_i64_from_vec(3, 3, ids);

    let mut next: Vec<i64> = Vec::new();
    next.push(2); next.push(3); next.push(4);
    let next_tokens: TensorI64 = tensor_i64_from_vec(3, 1, next);

    let appended: TensorI64 = ai_append_next_token_i64(&token_ids, &next_tokens);
    tensor_i64_print_flat("appended token ids:", &appended);
    return 0;
}
