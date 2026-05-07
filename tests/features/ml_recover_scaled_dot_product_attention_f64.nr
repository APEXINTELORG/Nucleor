import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_scaled_dot_product_attention_f64 — minimal SDPA smoke
// (deferred in ML-11 §3). 1 query, 2 keys, 2 values, head_dim=2. The
// query matches key[0] perfectly (dot product 2.0) and is orthogonal
// to key[1] (dot product 0.0). With softmax over the 2 keys, the
// output should heavily weight value[0].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.05;

    // q = [1, 1] (1x2), K = [[1,1],[0,0]] (2x2 — key 0 matches q, key 1 is zero),
    // V = [[10, 20],[1, 2]] (2x2 — value 0 is large, value 1 is small).
    let mut qd: Vec<f64> = Vec::new();
    qd.push(1.0); qd.push(1.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 2, qd);

    let mut kd: Vec<f64> = Vec::new();
    kd.push(1.0); kd.push(1.0);
    kd.push(0.0); kd.push(0.0);
    let k: TensorF64 = tensor_f64_from_vec(2, 2, kd);

    let mut vd: Vec<f64> = Vec::new();
    vd.push(10.0); vd.push(20.0);
    vd.push(1.0); vd.push(2.0);
    let v: TensorF64 = tensor_f64_from_vec(2, 2, vd);

    // Non-causal SDPA: output = softmax(QK^T / sqrt(d_k)) @ V.
    // QK^T = [[2, 0]], softmax = [[~0.88, ~0.12]] (with sqrt(2) scale ~ 1.414, so [[1.414, 0]] -> [[~0.80, ~0.20]]).
    // Output ~ 0.8 * [10,20] + 0.2 * [1,2] = [~8.2, ~16.4] — but let's not rely on exact softmax;
    // assert that out[0] is much closer to value[0] than value[1].
    let y: TensorF64 = ai_scaled_dot_product_attention_f64(&q, &k, &v, 0);
    if y.shape.rows != 1 { print("FAIL sdpa rows"); fail = fail + 1; };
    if y.shape.cols != 2 { print("FAIL sdpa cols"); fail = fail + 1; };

    let y0: f64 = tensor_f64_at(&y, 0, 0);
    let y1: f64 = tensor_f64_at(&y, 0, 1);

    // Output should be strongly biased toward value[0]=[10,20] not value[1]=[1,2].
    if y0 < 5.0 { print("FAIL sdpa y0 too small"); fail = fail + 1; };
    if y0 > 10.0 { print("FAIL sdpa y0 too large"); fail = fail + 1; };
    if y1 < 10.0 { print("FAIL sdpa y1 too small"); fail = fail + 1; };
    if y1 > 20.0 { print("FAIL sdpa y1 too large"); fail = fail + 1; };
    // Antisymmetry: y1 ≈ 2 * y0 (value[0] = [10, 20] = 2x).
    if close_f64(y1, y0 * 2.0, 0.5) != 1 { print("FAIL sdpa ratio"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_scaled_dot_product_attention_f64"); return 0; };
    print("FAIL ml_recover_scaled_dot_product_attention_f64");
    return 1;
}
