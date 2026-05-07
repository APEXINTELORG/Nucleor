import "stdlib/rods/ml/ai_facade.nr"
import "stdlib/rods/ml/parity_manifest.nr"

// ml_ai_facade_smoke — exercises the AI/transformer surface from
// stdlib/rods/ml/ai_facade.nr: greedy next-token, last-token slicing,
// token append. Self-contained. Deeper PyTorch/HF parity (full attention
// blocks, decoder-layer generation loop) lives in subsequent batches.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // Greedy next-token: argmax over a single-row logits tensor.
    let mut ld: Vec<f64> = Vec::new();
    ld.push(0.1); ld.push(2.0); ld.push(0.3); ld.push(1.5);
    let logits: TensorF64 = tensor_f64_from_vec(1, 4, ld);
    let next: TensorI64 = ai_greedy_next_token_i64(&logits);
    if next.shape.rows != 1 { print("FAIL greedy rows"); fail = fail + 1; };
    if tensor_i64_at(&next, 0, 0) != 1 { print("FAIL greedy argmax"); fail = fail + 1; };

    // Two-row argmax to confirm batched behavior.
    let mut bd: Vec<f64> = Vec::new();
    bd.push(0.1); bd.push(2.0); bd.push(0.3);
    bd.push(3.0); bd.push(0.5); bd.push(0.2);
    let blogits: TensorF64 = tensor_f64_from_vec(2, 3, bd);
    let bnext: TensorI64 = ai_greedy_next_token_i64(&blogits);
    if tensor_i64_at(&bnext, 0, 0) != 1 { print("FAIL greedy b0"); fail = fail + 1; };
    if tensor_i64_at(&bnext, 1, 0) != 0 { print("FAIL greedy b1"); fail = fail + 1; };

    // Last-token extraction: token_ids[:, -1:].
    let mut tid: Vec<i64> = Vec::new();
    tid.push(7); tid.push(8); tid.push(9);
    tid.push(2); tid.push(3); tid.push(4);
    let tokens: TensorI64 = tensor_i64_from_vec(2, 3, tid);
    let last: TensorI64 = ai_last_token_i64(&tokens);
    if last.shape.cols != 1 { print("FAIL last cols"); fail = fail + 1; };
    if tensor_i64_at(&last, 0, 0) != 9 { print("FAIL last r0"); fail = fail + 1; };
    if tensor_i64_at(&last, 1, 0) != 4 { print("FAIL last r1"); fail = fail + 1; };

    // Append next-token column.
    let mut nd: Vec<i64> = Vec::new();
    nd.push(11);
    nd.push(22);
    let nx: TensorI64 = tensor_i64_from_vec(2, 1, nd);
    let appended: TensorI64 = ai_append_next_token_i64(&tokens, &nx);
    if appended.shape.cols != 4 { print("FAIL append cols"); fail = fail + 1; };
    if tensor_i64_at(&appended, 0, 3) != 11 { print("FAIL append r0c3"); fail = fail + 1; };
    if tensor_i64_at(&appended, 1, 3) != 22 { print("FAIL append r1c3"); fail = fail + 1; };

    let manifest: ParityManifest = parity_manifest(
        "ml_ai_facade_smoke",
        "internal",
        "stdlib::rods::ml::ai_facade",
        dtype_f64(),
        dtype_default_accumulator(dtype_f64()),
        policy_strict(),
        2,
        3,
        0.000001
    );
    parity_manifest_print(&manifest);

    if fail == 0 {
        print("OK ml_ai_facade_smoke");
        return 0;
    };
    print("FAIL ml_ai_facade_smoke");
    return 1;
}
