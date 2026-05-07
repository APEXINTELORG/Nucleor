import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_top_p_filter_f64 — minimal nucleus (top-p) filtering.
// Probabilities [0.5, 0.3, 0.15, 0.05] with top_p=0.8: keep first 2
// (cumulative 0.5 + 0.3 = 0.8). Renormalize: [0.625, 0.375].

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut pd: Vec<f64> = Vec::new();
    pd.push(0.5); pd.push(0.3); pd.push(0.15); pd.push(0.05);
    let p: TensorF64 = tensor_f64_from_vec(1, 4, pd);

    let result: TopPF64 = ai_top_p_f64(&p, 0.8);

    // Probabilities tensor exists with same vocab size.
    if result.probabilities.shape.cols != 4 { print("FAIL top_p cols"); fail = fail + 1; };

    // The kept indices count should be at least 2 (covering 0.8 mass).
    let kept: i64 = tensor_i64_at(&result.counts, 0, 0);
    if kept < 2 { print("FAIL top_p kept count"); fail = fail + 1; };
    if kept > 4 { print("FAIL top_p kept count too high"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_top_p_filter_f64"); return 0; };
    print("FAIL ml_recover_top_p_filter_f64");
    return 1;
}
