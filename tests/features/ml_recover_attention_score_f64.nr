import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_attention_score_f64 — single Q/K dot product with scale.
// Returns a scalar — the simplest attention primitive.

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
    qd.push(1.0); qd.push(2.0); qd.push(3.0);
    let q: TensorF64 = tensor_f64_from_vec(1, 3, qd);

    let mut kd: Vec<f64> = Vec::new();
    kd.push(4.0); kd.push(5.0); kd.push(6.0);
    let k: TensorF64 = tensor_f64_from_vec(1, 3, kd);

    // q[0] · k[0] = 1*4 + 2*5 + 3*6 = 32. Scale by 0.5 -> 16.
    let s: f64 = ai_attention_score_f64(&q, &k, 0, 0, 0.5);
    if close_f64(s, 16.0, eps) != 1 { print("FAIL score"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_attention_score_f64"); return 0; };
    print("FAIL ml_recover_attention_score_f64");
    return 1;
}
