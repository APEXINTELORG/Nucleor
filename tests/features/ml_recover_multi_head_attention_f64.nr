import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_multi_head_attention_f64 — minimal 2-head SDPA smoke
// (deferred ML-11). 1 query × 2 keys × 2 values, model_dim=4,
// head_count=2, head_dim=2. Q matches K[0] in head 0 only, K[1] in
// head 1 only — output should reflect the per-head attention split.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // q (1x4): [1, 0, 0, 1] — head 0 = [1, 0], head 1 = [0, 1]
    let mut qd: Vec<f64> = Vec::new();
    qd.push(1.0); qd.push(0.0); qd.push(0.0); qd.push(1.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 4, qd);

    // K (2x4): row 0 = [1, 0, 0, 0] (matches q-head0), row 1 = [0, 0, 0, 1] (matches q-head1)
    let mut kd: Vec<f64> = Vec::new();
    kd.push(1.0); kd.push(0.0); kd.push(0.0); kd.push(0.0);
    kd.push(0.0); kd.push(0.0); kd.push(0.0); kd.push(1.0);
    let k: TensorF64 = tensor_f64_from_vec(2, 4, kd);

    // V (2x4): row 0 carries 10 in head-0 cols, row 1 carries 20 in head-1 cols
    let mut vd: Vec<f64> = Vec::new();
    vd.push(10.0); vd.push(10.0); vd.push(0.0); vd.push(0.0);
    vd.push(0.0); vd.push(0.0); vd.push(20.0); vd.push(20.0);
    let v: TensorF64 = tensor_f64_from_vec(2, 4, vd);

    let y: TensorF64 = ai_multi_head_scaled_dot_product_attention_f64(&q, &k, &v, 2, 0);
    if y.shape.rows != 1 { print("FAIL mha rows"); fail = fail + 1; };
    if y.shape.cols != 4 { print("FAIL mha cols"); fail = fail + 1; };

    // Head 0 output should be biased toward V[0] head-0 cols (≈ 10).
    let h0a: f64 = tensor_f64_at(&y, 0, 0);
    let h0b: f64 = tensor_f64_at(&y, 0, 1);
    if h0a < 5.0 { print("FAIL h0a bias"); fail = fail + 1; };
    if h0b < 5.0 { print("FAIL h0b bias"); fail = fail + 1; };

    // Head 1 output should be biased toward V[1] head-1 cols (≈ 20).
    let h1a: f64 = tensor_f64_at(&y, 0, 2);
    let h1b: f64 = tensor_f64_at(&y, 0, 3);
    if h1a < 10.0 { print("FAIL h1a bias"); fail = fail + 1; };
    if h1b < 10.0 { print("FAIL h1b bias"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_multi_head_attention_f64"); return 0; };
    print("FAIL ml_recover_multi_head_attention_f64");
    return 1;
}
