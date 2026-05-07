import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_lm_head_logits_f64 — single-pass LM head projection
// (deferred ML-11 transformer family). Hidden (1xH) → vocab logits
// (1xV) via y = h @ W^T + b.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.0001;

    // hidden = [[1, 2]] (1x2). lm_head_weight (3x2): each row maps to one vocab id.
    let mut hd: Vec<f64> = Vec::new();
    hd.push(1.0); hd.push(2.0);
    let h: TensorF64 = tensor_f64_from_vec(1, 2, hd);

    // W (3x2): vocab 0 weight = [1, 0], vocab 1 = [0, 1], vocab 2 = [1, 1].
    let mut wd: Vec<f64> = Vec::new();
    wd.push(1.0); wd.push(0.0);
    wd.push(0.0); wd.push(1.0);
    wd.push(1.0); wd.push(1.0);
    let w: TensorF64 = tensor_f64_from_vec(3, 2, wd);

    let mut bd: Vec<f64> = Vec::new();
    bd.push(0.0); bd.push(0.0); bd.push(0.0);
    let b: TensorF64 = tensor_f64_from_vec(1, 3, bd);

    let logits: TensorF64 = ai_lm_head_logits_f64(&h, &w, &b);
    if logits.shape.rows != 1 { print("FAIL logit rows"); fail = fail + 1; };
    if logits.shape.cols != 3 { print("FAIL logit cols"); fail = fail + 1; };

    // Expected: logit[0] = 1*1 + 2*0 = 1; logit[1] = 1*0 + 2*1 = 2; logit[2] = 1*1 + 2*1 = 3.
    if close_f64(tensor_f64_at(&logits, 0, 0), 1.0, eps) != 1 { print("FAIL logit 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&logits, 0, 1), 2.0, eps) != 1 { print("FAIL logit 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&logits, 0, 2), 3.0, eps) != 1 { print("FAIL logit 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_lm_head_logits_f64"); return 0; };
    print("FAIL ml_recover_lm_head_logits_f64");
    return 1;
}
