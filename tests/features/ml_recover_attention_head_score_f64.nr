import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_attention_head_score_f64 — per-head dot product. Q (1x4)
// = [1, 2, 0, 0] (head 0 = [1,2], head 1 = [0,0]). K (1x4) = [3, 4, 5, 6].
// head 0 score (q_head_0 · k_head_0) * scale = (1*3 + 2*4) * scale = 11 * scale.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.0001;

    let mut qd: Vec<f64> = Vec::new();
    qd.push(1.0); qd.push(2.0); qd.push(0.0); qd.push(0.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 4, qd);

    let mut kd: Vec<f64> = Vec::new();
    kd.push(3.0); kd.push(4.0); kd.push(5.0); kd.push(6.0);
    let k: TensorF64 = tensor_f64_from_vec(1, 4, kd);

    // Head 0: cols 0..2, scale 1.0 → 1*3 + 2*4 = 11.
    let s0: f64 = ai_attention_head_score_f64(&q, &k, 0, 0, 0, 2, 1.0);
    if close_f64(s0, 11.0, eps) != 1 { print("FAIL head0 score"); fail = fail + 1; };

    // Head 1: cols 2..4, q_head_1=[0,0], so score = 0.
    let s1: f64 = ai_attention_head_score_f64(&q, &k, 0, 0, 2, 2, 1.0);
    if close_f64(s1, 0.0, eps) != 1 { print("FAIL head1 score"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_attention_head_score_f64"); return 0; };
    print("FAIL ml_recover_attention_head_score_f64");
    return 1;
}
