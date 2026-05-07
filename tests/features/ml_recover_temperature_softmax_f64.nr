import "stdlib/rods/ml/ai_facade.nr"

// ml_recover_temperature_softmax_f64 — minimal temperature-scaled
// softmax (deferred ML-11). 1×3 logits with one large value; result
// should sum to 1, with the largest probability on the argmax.

fn close_f64(a: f64, b: f64, eps: f64) -> i64 {
    let mut d: f64 = a - b;
    if d < 0.0 { d = 0.0 - d; };
    if d <= eps { return 1; };
    return 0;
}

fn main() -> i32 {
    let mut fail: i64 = 0;
    let eps: f64 = 0.001;

    let mut ld: Vec<f64> = Vec::new();
    ld.push(0.0); ld.push(5.0); ld.push(0.0);
    let logits: TensorF64 = tensor_f64_from_vec(1, 3, ld);

    let p: TensorF64 = ai_temperature_softmax_f64(&logits, 1.0);
    if p.shape.rows != 1 { print("FAIL p rows"); fail = fail + 1; };
    if p.shape.cols != 3 { print("FAIL p cols"); fail = fail + 1; };

    let p0: f64 = tensor_f64_at(&p, 0, 0);
    let p1: f64 = tensor_f64_at(&p, 0, 1);
    let p2: f64 = tensor_f64_at(&p, 0, 2);

    // Probabilities sum to 1.
    if close_f64(p0 + p1 + p2, 1.0, eps) != 1 { print("FAIL p sum"); fail = fail + 1; };
    // p[1] dominates (largest logit).
    if p1 < 0.9 { print("FAIL p1 not dominant"); fail = fail + 1; };
    // Symmetry: equal logits at 0 and 2 should give equal probabilities.
    if close_f64(p0, p2, eps) != 1 { print("FAIL symmetry"); fail = fail + 1; };

    if fail == 0 { print("OK ml_recover_temperature_softmax_f64"); return 0; };
    print("FAIL ml_recover_temperature_softmax_f64");
    return 1;
}
