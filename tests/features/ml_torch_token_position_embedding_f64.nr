import "stdlib/rods/ml/ai_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

fn main() -> i32 {
    let manifest: ParityManifest = parity_manifest(
        "torch_token_position_embedding_f64",
        "torch token embedding plus position embedding",
        "nuc::ai::token_position_embedding_f64",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        6,
        4,
        0.000001
    );
    parity_manifest_print(&manifest);

    let mut ed: Vec<f64> = Vec::new();
    ed.push(0.10); ed.push(-0.20); ed.push(0.30); ed.push(0.40);
    ed.push(-0.50); ed.push(0.25); ed.push(0.75); ed.push(-0.10);
    ed.push(0.60); ed.push(0.20); ed.push(-0.30); ed.push(0.15);
    ed.push(0.05); ed.push(-0.45); ed.push(0.55); ed.push(0.35);
    ed.push(-0.25); ed.push(0.80); ed.push(0.10); ed.push(-0.60);
    let token_embedding: TensorF64 = tensor_f64_from_vec(5, 4, ed);

    let mut ped: Vec<f64> = Vec::new();
    ped.push(0.01); ped.push(0.02); ped.push(0.03); ped.push(0.04);
    ped.push(0.10); ped.push(-0.10); ped.push(0.05); ped.push(-0.05);
    ped.push(-0.02); ped.push(0.03); ped.push(-0.04); ped.push(0.06);
    ped.push(0.07); ped.push(0.01); ped.push(0.00); ped.push(-0.02);
    let position_embedding: TensorF64 = tensor_f64_from_vec(4, 4, ped);

    let mut ids: Vec<i64> = Vec::new();
    ids.push(2); ids.push(0); ids.push(4);
    ids.push(1); ids.push(3); ids.push(2);
    let token_ids: TensorI64 = tensor_i64_from_vec(2, 3, ids);

    let positioned: TensorF64 = ai_token_position_embedding_f64(&token_embedding, &position_embedding, &token_ids);
    tensor_f64_print_flat("token position embeddings:", &positioned);
    return 0;
}
