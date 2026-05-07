import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_top_k_f64 — minimal top-k smoke (deferred ML-11). 1×5
// logits with known ordering; top-3 should return the three largest
// values + their original indices.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.000001;

    // Logits [3, 1, 4, 1, 5] -> top 3 by value: [5, 4, 3] at indices [4, 2, 0].
    let mut ld: Vec<f64> = Vec::new();
    ld.push(3.0); ld.push(1.0); ld.push(4.0); ld.push(1.0); ld.push(5.0);
    let logits: TensorF64 = tensor_f64_from_vec(1, 5, ld);

    let tk: TopKF64 = ai_top_k_f64(&logits, 3);
    if tk.values.shape.cols != 3 { print("FAIL topk vals cols"); fail = fail + 1; };
    if tk.indices.shape.cols != 3 { print("FAIL topk idx cols"); fail = fail + 1; };

    if close_f64(tensor_f64_at(&tk.values, 0, 0), 5.0, eps) != 1 { print("FAIL topk val 0"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&tk.values, 0, 1), 4.0, eps) != 1 { print("FAIL topk val 1"); fail = fail + 1; };
    if close_f64(tensor_f64_at(&tk.values, 0, 2), 3.0, eps) != 1 { print("FAIL topk val 2"); fail = fail + 1; };

    if tensor_i64_at(&tk.indices, 0, 0) != 4 { print("FAIL topk idx 0"); fail = fail + 1; };
    if tensor_i64_at(&tk.indices, 0, 1) != 2 { print("FAIL topk idx 1"); fail = fail + 1; };
    if tensor_i64_at(&tk.indices, 0, 2) != 0 { print("FAIL topk idx 2"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_top_k_f64"); return 0; };
    print("FAIL ml_recover_top_k_f64");
    return 1;
}
